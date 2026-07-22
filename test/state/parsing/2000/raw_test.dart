// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/2000/raw.dart';
import 'package:test/test.dart';

Uint8List _pkt(String s) => Uint8List.fromList(s.codeUnits);

/// Builds an 8 character hex CAN header from its constituent fields.
String _header({
  int priority = 3,
  int dataPage = 0,
  required int pduFormat,
  int pduSpecific = 0,
  required int source,
}) {
  final id =
      (priority << 26) | (dataPage << 24) | (pduFormat << 16) | (pduSpecific << 8) | source;
  return id.toRadixString(16).padLeft(8, '0').toUpperCase();
}

/// Builds a single Yacht Devices RAW format line from its constituent fields.
String _line(String header, {String direction = 'R', List<int> data = const [0x01]}) {
  final hexData = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  return '16:23:23.404 $direction $header $hexData';
}

void main() {
  group('YdRawMessageSplitter', () {
    late YdRawMessageSplitter splitter;

    setUp(() {
      splitter = YdRawMessageSplitter();
    });

    /// Reads a single line, returning the pgn, sender and payload of the resulting message.
    (int, int, Uint8List) readOne(String line) {
      final messages = splitter.read(_pkt('$line\n'));
      expect(messages, hasLength(1));
      final validated = YdRawMessageValidator().validate(messages.single)!;
      return (validated.type, validated.sender, Uint8List.sublistView(validated.payload));
    }

    test('extracts pgn and source from a PDU1 format frame, ignoring the destination', () {
      final header = _header(pduFormat: 0x01, pduSpecific: 0xAB, dataPage: 1, source: 0x23);
      final (pgn, source, _) = readOne(_line(header));
      expect(pgn, 0x010100);
      expect(source, 0x23);
    });

    test('extracts pgn and source from a PDU2 format frame, including the group extension', () {
      final header = _header(pduFormat: 0xF5, pduSpecific: 0x13, source: 0x2A);
      final (pgn, source, _) = readOne(_line(header));
      expect(pgn, 0xF513);
      expect(source, 0x2A);
    });

    test('treats PDU format 239 as PDU1', () {
      final header = _header(pduFormat: 239, pduSpecific: 0xFF, source: 0x01);
      final (pgn, _, _) = readOne(_line(header));
      expect(pgn, 239 << 8);
    });

    test('treats PDU format 240 as PDU2', () {
      final header = _header(pduFormat: 240, pduSpecific: 0x01, source: 0x01);
      final (pgn, _, _) = readOne(_line(header));
      expect(pgn, (240 << 8) | 0x01);
    });

    test('extracts payload bytes in order', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final (_, _, payload) = readOne(_line(header, data: [0x11, 0x22, 0x33]));
      expect(payload, [0x11, 0x22, 0x33]);
    });

    test('accepts the minimum single data byte', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final (_, _, payload) = readOne(_line(header, data: [0xAB]));
      expect(payload, [0xAB]);
    });

    test('accepts the maximum of eight data bytes', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final data = List<int>.generate(8, (i) => i);
      final (_, _, payload) = readOne(_line(header, data: data));
      expect(payload, data);
    });

    test('extracts multiple frames from one packet', () {
      final header1 = _header(pduFormat: 0x01, source: 0x01);
      final header2 = _header(pduFormat: 0x02, source: 0x02);
      // A trailing unterminated fragment forces the CrlfMessageSplitter to flush both complete
      // lines in this call rather than buffering the last of them awaiting a terminator.
      final messages = splitter.read(
        _pkt('${_line(header1, data: [0x11])}\n${_line(header2, data: [0x22])}\nunterminated'),
      );
      expect(messages, hasLength(2));
    });

    test('ignores a line with no data bytes', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final line = '16:23:23.404 R $header';
      expect(splitter.read(_pkt('$line\n')), isEmpty);
    });

    test('ignores a line with more than eight data bytes', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final data = List<int>.generate(9, (i) => i);
      expect(splitter.read(_pkt('${_line(header, data: data)}\n')), isEmpty);
    });

    test('ignores transmitted frames', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final line = _line(header, direction: 'T');
      expect(splitter.read(_pkt('$line\n')), isEmpty);
    });

    test('ignores malformed lines while still extracting valid ones from the same packet', () {
      final header = _header(pduFormat: 0x01, source: 0x01);
      final goodLine = _line(header, data: [0x11]);
      // A trailing unterminated fragment forces the CrlfMessageSplitter to flush the valid line
      // in this call rather than buffering it awaiting a terminator.
      final messages = splitter.read(_pkt('not a valid frame at all\n$goodLine\nunterminated'));
      expect(messages, hasLength(1));
    });

    test('loggable returns hex representation', () {
      final message = ByteData.sublistView(Uint8List.fromList([0x01, 0x02, 0xab]));
      expect(splitter.loggable(message), '0x0102ab');
    });
  });

  group('YdRawMessageSplitter fast frame assembly', () {
    late YdRawMessageSplitter splitter;

    setUp(() {
      splitter = YdRawMessageSplitter();
    });

    // PGN 128275 (Distance Log) is currently the only PGN registered as requiring fast frame
    // assembly, so it is used to exercise the splitter's fast frame handling below.
    final ffHeader = _header(pduFormat: 0xF5, pduSpecific: 0x13, dataPage: 1, source: 0x10);

    /// Splits a full NMEA2000 payload into the CAN frame byte lists a Yacht Devices fast frame
    /// sequence would carry it in: a counter and total length in the first frame, then a counter
    /// and up to 7 data bytes in each subsequent frame.
    List<List<int>> fastFrames(List<int> payload) {
      final frames = <List<int>>[
        [0, payload.length, ...payload.take(6)],
      ];
      var offset = payload.length < 6 ? payload.length : 6;
      var counter = 1;
      while (offset < payload.length) {
        final chunk = payload.skip(offset).take(7).toList();
        frames.add([counter, ...chunk]);
        offset += chunk.length;
        counter++;
      }
      return frames;
    }

    /// Feeds a set of already built CAN frames through the splitter as a single read call.
    List<ByteData> readFrames(String header, List<List<int>> frames) {
      final lines = frames.map((f) => _line(header, data: f)).join('\n');
      return splitter.read(_pkt('$lines\n'));
    }

    /// Like [fastFrames], but stamps every frame counter with the supplied sequence id (the
    /// upper 3 bits), so the resulting frames can be distinguished from a concurrent sequence
    /// sharing the same PGN and source.
    List<List<int>> fastFramesWithSeqId(int seqId, List<int> payload) {
      return fastFrames(payload).map((frame) {
        final counter = (seqId << 5) | frame[0];
        return [counter, ...frame.skip(1)];
      }).toList();
    }

    test('buffers a fast frame message until all frames have been received', () {
      final payload = List<int>.generate(14, (i) => i + 1);
      final frames = fastFrames(payload);
      expect(frames, hasLength(3)); // 6 + 7 + 1 bytes across 3 CAN frames.

      expect(readFrames(ffHeader, [frames[0]]), isEmpty);
      expect(readFrames(ffHeader, [frames[1]]), isEmpty);
      final messages = readFrames(ffHeader, [frames[2]]);

      expect(messages, hasLength(1));
      final validated = YdRawMessageValidator().validate(messages.single)!;
      expect(validated.type, 128275);
      expect(validated.sender, 0x10);
      expect(Uint8List.sublistView(validated.payload), payload);
    });

    test('assembles a fast frame message delivered within a single read call', () {
      final payload = List<int>.generate(20, (i) => i + 1);
      final frames = fastFrames(payload);
      expect(frames, hasLength(3)); // 6 + 7 + 7 bytes across 3 CAN frames.
      final lines = frames.map((f) => _line(ffHeader, data: f)).join('\n');

      // A trailing unterminated fragment forces the CrlfMessageSplitter to flush the final
      // complete line in this call rather than buffering it awaiting a terminator.
      final messages = splitter.read(_pkt('$lines\nunterminated'));

      expect(messages, hasLength(1));
      final validated = YdRawMessageValidator().validate(messages.single)!;
      expect(Uint8List.sublistView(validated.payload), payload);
    });

    test('completes immediately when the whole payload fits in the first frame', () {
      final payload = [0xAA, 0xBB, 0xCC, 0xDD];

      final messages = readFrames(ffHeader, fastFrames(payload));

      expect(messages, hasLength(1));
      final validated = YdRawMessageValidator().validate(messages.single)!;
      expect(Uint8List.sublistView(validated.payload), payload);
    });

    test('tracks independent in-progress messages for different sources', () {
      final headerA = _header(pduFormat: 0xF5, pduSpecific: 0x13, dataPage: 1, source: 0x10);
      final headerB = _header(pduFormat: 0xF5, pduSpecific: 0x13, dataPage: 1, source: 0x20);
      final payloadA = List<int>.generate(14, (i) => i + 1);
      final payloadB = List<int>.generate(9, (i) => 100 + i);
      final framesA = fastFrames(payloadA);
      final framesB = fastFrames(payloadB);

      expect(readFrames(headerA, [framesA[0]]), isEmpty);
      expect(readFrames(headerB, [framesB[0]]), isEmpty);
      expect(readFrames(headerA, [framesA[1]]), isEmpty);

      // Complete B before A to show their in-progress state doesn't clash.
      final messagesB = readFrames(headerB, framesB.skip(1).toList());
      expect(messagesB, hasLength(1));
      expect(
        Uint8List.sublistView(YdRawMessageValidator().validate(messagesB.single)!.payload),
        payloadB,
      );

      final messagesA = readFrames(headerA, [framesA[2]]);
      expect(messagesA, hasLength(1));
      expect(
        Uint8List.sublistView(YdRawMessageValidator().validate(messagesA.single)!.payload),
        payloadA,
      );
    });

    test('drops a frame and does not crash when its counter is out of sequence', () {
      final payload = List<int>.generate(14, (i) => i + 1);
      final frames = fastFrames(payload);
      expect(readFrames(ffHeader, [frames[0]]), isEmpty);

      // Frame 1 should have counter 1; jump straight to counter 2 instead.
      final badFrame = [2, ...frames[1].skip(1)];
      expect(readFrames(ffHeader, [badFrame]), isEmpty);
    });

    test('drops a continuation frame that is shorter than the remaining byte count', () {
      final payload = List<int>.generate(14, (i) => i + 1);
      final frames = fastFrames(payload);
      expect(readFrames(ffHeader, [frames[0]]), isEmpty);

      // Frame 1 should carry counter 1 plus 7 data bytes; truncate the data.
      final shortFrame = frames[1].sublist(0, 4);
      expect(readFrames(ffHeader, [shortFrame]), isEmpty);
    });

    test(
      'abandons an in-progress message and starts a new one when a frame with a different '
      'sequence id begins a new message',
      () {
        final abandonedPayload = List<int>.generate(14, (i) => i + 1);
        final newPayload = List<int>.generate(9, (i) => 100 + i);
        final abandonedFrames = fastFrames(abandonedPayload);
        final newFrames = fastFramesWithSeqId(1, newPayload);

        // Begin assembling the first message but never finish it.
        expect(readFrames(ffHeader, [abandonedFrames[0]]), isEmpty);

        // A frame with a different sequence id but a starting counter (0) arrives on the same
        // PGN/source before the first message completes. This should abandon the first message
        // and start assembling the new one from this frame instead of being dropped outright.
        expect(readFrames(ffHeader, [newFrames[0]]), isEmpty);

        // The new message should complete normally from here, ignoring the abandoned one.
        final messages = readFrames(ffHeader, newFrames.skip(1).toList());
        expect(messages, hasLength(1));
        final validated = YdRawMessageValidator().validate(messages.single)!;
        expect(Uint8List.sublistView(validated.payload), newPayload);
      },
    );

    test(
      'drops a frame with a different sequence id that is not itself a valid sequence start',
      () {
        final abandonedPayload = List<int>.generate(14, (i) => i + 1);
        final newPayload = List<int>.generate(14, (i) => i + 1);
        final abandonedFrames = fastFrames(abandonedPayload);
        final newFrames = fastFramesWithSeqId(1, newPayload);

        expect(readFrames(ffHeader, [abandonedFrames[0]]), isEmpty);

        // Frame carries a different sequence id (so it can't continue the in-progress message)
        // but a non-zero counter (so it can't start a new one either); it should be dropped.
        expect(readFrames(ffHeader, [newFrames[1]]), isEmpty);

        // A properly started sequence afterwards is still assembled correctly, showing the
        // failed attempt above didn't leave the splitter in a bad state.
        expect(readFrames(ffHeader, [newFrames[0]]), isEmpty);
        expect(readFrames(ffHeader, [newFrames[1]]), isEmpty);
        final messages = readFrames(ffHeader, [newFrames[2]]);
        expect(messages, hasLength(1));
        final validated = YdRawMessageValidator().validate(messages.single)!;
        expect(Uint8List.sublistView(validated.payload), newPayload);
      },
    );
  });

  group('YdRawMessageValidator', () {
    late YdRawMessageValidator validator;

    setUp(() {
      validator = YdRawMessageValidator();
    });

    /// Builds a serialized message in the format produced by YdRawMessageSplitter: a 4 byte
    /// pgn, a 2 byte source, then the payload bytes.
    ByteData serialized(int pgn, int source, List<int> payload) {
      final bytes = Uint8List(6 + payload.length);
      final data = ByteData.sublistView(bytes);
      data.setUint32(0, pgn);
      data.setUint16(4, source);
      bytes.setRange(6, bytes.length, payload);
      return data;
    }

    test('validates a message with the minimum single payload byte', () {
      final message = validator.validate(serialized(0x010100, 0x23, [0xAB]))!;
      expect(message.type, 0x010100);
      expect(message.sender, 0x23);
      expect(Uint8List.sublistView(message.payload), [0xAB]);
    });

    test('validates a message with a multi byte payload', () {
      final message = validator.validate(serialized(0xF513, 0x2A, [0x11, 0x22, 0x33]))!;
      expect(message.type, 0xF513);
      expect(message.sender, 0x2A);
      expect(Uint8List.sublistView(message.payload), [0x11, 0x22, 0x33]);
    });

    test('rejects a message shorter than the 6 byte header plus 1 byte payload', () {
      expect(() => validator.validate(ByteData(6)), throwsFormatException);
    });
  });
}
