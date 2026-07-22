// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:test/test.dart';

Uint8List _pkt(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  group('CrlfMessageSplitter', () {
    late CrlfMessageSplitter splitter;

    setUp(() {
      splitter = CrlfMessageSplitter(startRegex: RegExp(r'[\$!]'));
    });

    test('empty data yields no messages', () {
      expect(splitter.read(Uint8List(0)), isEmpty);
    });

    test('retains data without terminator or start marker', () {
      expect(splitter.read(_pkt('\$GSV,5,1,18,65,75,277,17,10,69')), isEmpty);
    });

    test('splits LF terminated messages', () {
      expect(
        splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\n\$YDMWV,182.8,T,2.4,M,A*20\n\$YDVTG,4.1')),
        ['\$YDMWV,184.6,R,1.4,M,A*2D', '\$YDMWV,182.8,T,2.4,M,A*20'],
      );
    });

    test('splits CRLF terminated messages', () {
      expect(
        splitter.read(
          _pkt('\$YDMWV,184.6,R,1.4,M,A*2D\r\n\$YDMWV,182.8,T,2.4,M,A*20\r\n\$YDVTG,4.1'),
        ),
        ['\$YDMWV,184.6,R,1.4,M,A*2D', '\$YDMWV,182.8,T,2.4,M,A*20'],
      );
    });

    test('splits unterminated messages on the start marker', () {
      expect(
        splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\$YDMWV,182.8,T,2.4,M,A*20\$YDVTG,4.1')),
        ['\$YDMWV,184.6,R,1.4,M,A*2D', '\$YDMWV,182.8,T,2.4,M,A*20'],
      );
    });

    test('retains partial message across reads', () {
      const msg = '\$YDDPT,18.56,-1.61,140.0,*67';
      expect(splitter.read(_pkt(msg.substring(0, 10))), isEmpty);
      expect(splitter.read(_pkt('${msg.substring(10)}\n')), [msg]);
    });

    test('without start regex only splits on line terminators', () {
      final splitter = CrlfMessageSplitter();
      expect(splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\$YDVTG,4.1\n')), [
        '\$YDMWV,184.6,R,1.4,M,A*2D\$YDVTG,4.1',
      ]);
    });
  });

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

  group('NullSplitter', () {
    test('returns each packet as a single message', () {
      final splitter = NullSplitter();
      final messages = splitter.read(Uint8List.fromList([0x01, 0x02, 0xab]));
      expect(messages.length, 1);
      expect(messages[0].lengthInBytes, 3);
      expect(messages[0].getUint8(2), 0xab);
    });
  });
}
