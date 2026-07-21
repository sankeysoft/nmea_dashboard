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
