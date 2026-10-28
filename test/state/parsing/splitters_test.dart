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

    test('returns the last terminated message in a packet', () {
      expect(splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\r\n\$YDMWV,182.8,T,2.4,M,A*20\r\n')), [
        '\$YDMWV,184.6,R,1.4,M,A*2D',
        '\$YDMWV,182.8,T,2.4,M,A*20',
      ]);
    });

    test('does not merge the last message of a packet into the next packet', () {
      final splitter = CrlfMessageSplitter();
      expect(splitter.read(_pkt('first line\r\nsecond line\r\n')), ['first line', 'second line']);
      expect(splitter.read(_pkt('third line\r\nfourth line\r\n')), ['third line', 'fourth line']);
      expect(splitter.discardCount, 0);
    });

    test('salvages messages from a packet containing invalid UTF-8', () {
      // 0xC3 0x28 is an invalid two byte UTF-8 sequence.
      final data = Uint8List.fromList([
        ...'\$YDMWV,184.6,R,1.4,M,A*2D\n'.codeUnits,
        0xC3,
        0x28,
        ...'\n\$YDMWV,182.8,T,2.4,M,A*20\n'.codeUnits,
      ]);
      expect(
        splitter.read(data),
        containsAll(['\$YDMWV,184.6,R,1.4,M,A*2D', '\$YDMWV,182.8,T,2.4,M,A*20']),
      );
    });

    test('does not throw on a packet of entirely invalid UTF-8', () {
      expect(splitter.read(Uint8List.fromList([0xFF, 0xFE, 0xFD, 0x80])), isEmpty);
    });

    test('does not count discards for valid messages', () {
      splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\n\$YDVTG,4.1'));
      expect(splitter.discardCount, 0);
    });

    test('discards and counts excessively long unterminated data', () {
      expect(splitter.read(_pkt('x' * 1030)), isEmpty);
      expect(splitter.discardCount, 1);
      // The discarded data is not prepended to subsequent messages.
      expect(splitter.read(_pkt('\$YDVTG,4.1\n\$')), ['\$YDVTG,4.1']);
    });

    test('without start regex only splits on line terminators', () {
      final splitter = CrlfMessageSplitter();
      expect(splitter.read(_pkt('\$YDMWV,184.6,R,1.4,M,A*2D\$YDVTG,4.1\n')), [
        '\$YDMWV,184.6,R,1.4,M,A*2D\$YDVTG,4.1',
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
