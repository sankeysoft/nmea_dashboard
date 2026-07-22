// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/2000/ngt.dart';
import 'package:test/test.dart';

List<int> _i32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setInt32(0, value, Endian.little);
  return bytes;
}

ByteData _makeNgtPacket(
  int pgn,
  int source,
  List<int> payload, {
  int id = 147,
  bool corruptChecksum = false,
}) {
  final pgnBytes = Uint8List(4);
  ByteData.sublistView(pgnBytes).setUint32(0, pgn << 8, Endian.little);
  final data = <int>[
    ...pgnBytes,
    0xFF, // destination, unused by the validator
    source,
    0, 0, 0, 0, // remaining reserved bytes of the 11 byte payload header, unused by the validator
    payload.length,
    ...payload,
  ];
  final bodyBytes = <int>[id, data.length, ...data];
  final sum = bodyBytes.fold<int>(0x02, (acc, b) => acc + b);
  var checksum = (0x100 - (sum & 0xFF)) & 0xFF;
  if (corruptChecksum) {
    checksum = (checksum + 1) & 0xFF;
  }
  return ByteData.sublistView(Uint8List.fromList([...bodyBytes, checksum]));
}

void main() {
  group('DleMessageSplitter', () {
    const dle = 0x10;
    const stx = 0x02;
    const etx = 0x03;

    late DleMessageSplitter splitter;

    setUp(() {
      splitter = DleMessageSplitter();
    });

    /// Reads a packet of the supplied bytes, returning the messages as byte lists.
    List<Uint8List> read(List<int> bytes) =>
        splitter.read(Uint8List.fromList(bytes)).map(Uint8List.sublistView).toList();

    test('empty data yields no messages', () {
      expect(read([]), isEmpty);
    });

    test('extracts a single message', () {
      expect(read([dle, stx, 0xa1, 0xb2, 0xc3, dle, etx]), [
        [0xa1, 0xb2, 0xc3],
      ]);
    });

    test('extracts multiple messages from one packet', () {
      expect(read([dle, stx, 0xa1, dle, etx, dle, stx, 0xb2, 0xb3, dle, etx]), [
        [0xa1],
        [0xb2, 0xb3],
      ]);
    });

    test('extracts an empty message', () {
      expect(read([dle, stx, dle, etx]), [<int>[]]);
    });

    test('ignores data before the first start marker', () {
      expect(read([0x41, 0x42, etx, dle, stx, 0xa1, dle, etx]), [
        [0xa1],
      ]);
    });

    test('ignores data between messages', () {
      expect(read([dle, stx, 0xa1, dle, etx, 0x41, 0x42, dle, stx, 0xb2, dle, etx]), [
        [0xa1],
        [0xb2],
      ]);
    });

    test('unescapes DLE bytes in the message', () {
      expect(read([dle, stx, 0xa1, dle, dle, 0xb2, dle, etx]), [
        [0xa1, dle, 0xb2],
      ]);
    });

    test('unescapes consecutive DLE bytes in the message', () {
      expect(read([dle, stx, dle, dle, dle, dle, dle, etx]), [
        [dle, dle],
      ]);
    });

    test('does not treat the byte after an escaped DLE as a marker', () {
      // The 0x03 is message data following an escaped DLE, not part of a terminator.
      expect(read([dle, stx, dle, dle, 0x03, dle, etx]), [
        [dle, 0x03],
      ]);
    });

    test('passes unescaped STX and ETX values through as data', () {
      expect(read([dle, stx, stx, 0xa1, etx, dle, etx]), [
        [stx, 0xa1, etx],
      ]);
    });

    test('reassembles a message split across packets', () {
      expect(read([dle, stx, 0xa1, 0xb2]), isEmpty);
      expect(read([0xc3, 0xd4, dle, etx]), [
        [0xa1, 0xb2, 0xc3, 0xd4],
      ]);
    });

    test('reassembles a message received one byte at a time', () {
      final bytes = [dle, stx, 0xa1, dle, dle, 0xb2, dle, etx];
      for (final byte in bytes.sublist(0, bytes.length - 1)) {
        expect(read([byte]), isEmpty);
      }
      expect(read([bytes.last]), [
        [0xa1, dle, 0xb2],
      ]);
    });

    test('handles a start marker split across packets', () {
      expect(read([0x41, dle]), isEmpty);
      expect(read([stx, 0xa1, dle, etx]), [
        [0xa1],
      ]);
    });

    test('handles a terminator split across packets', () {
      expect(read([dle, stx, 0xa1, dle]), isEmpty);
      expect(read([etx]), [
        [0xa1],
      ]);
    });

    test('handles an escaped DLE split across packets', () {
      expect(read([dle, stx, 0xa1, dle]), isEmpty);
      expect(read([dle, 0xb2, dle, etx]), [
        [0xa1, dle, 0xb2],
      ]);
    });

    test('returns complete messages and retains a partial from the same packet', () {
      expect(read([dle, stx, 0xa1, dle, etx, dle, stx, 0xb2]), [
        [0xa1],
      ]);
      expect(read([dle, etx]), [
        [0xb2],
      ]);
    });

    test('discards an unterminated message when a new one starts', () {
      expect(read([dle, stx, 0xa1, dle, stx, 0xb2, dle, etx]), [
        [0xb2],
      ]);
    });
  });

  group('NgtValidator', () {
    test('should validate NGT packet with correct checksum', () {
      final packet = _makeNgtPacket(127251, 0x23, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
      final message = NgtValidator().validate(packet)!;
      expect(message.type, 127251);
      expect(message.sender, 0x23);
      expect(Uint8List.sublistView(message.payload), [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
    });

    test('should ignore outgoing NGT packet', () {
      final packet = _makeNgtPacket(127251, 0x23, [
        0x04,
        ..._i32(-5585054),
        0xFF,
        0xFF,
        0xFF,
      ], id: 0);
      expect(NgtValidator().validate(packet), isNull);
    });

    test('should reject NGT packet with incorrect checksum', () {
      final packet = _makeNgtPacket(127251, 0x23, [
        0x04,
        ..._i32(-5585054),
        0xFF,
        0xFF,
        0xFF,
      ], corruptChecksum: true);
      expect(() => NgtValidator().validate(packet), throwsFormatException);
    });

    test('should reject NGT packet with a single corrupted data byte', () {
      final packet = _makeNgtPacket(127251, 0x23, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
      // Flip a bit part way through the payload without touching the trailing checksum byte.
      packet.setUint8(13, packet.getUint8(13) ^ 0x01);
      expect(() => NgtValidator().validate(packet), throwsFormatException);
    });
  });
}
