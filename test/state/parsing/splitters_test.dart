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

    test('loggable returns the message', () {
      expect(splitter.loggable('\$YDVTG,4.1'), '\$YDVTG,4.1');
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

    test('loggable returns hex representation', () {
      final splitter = NullSplitter();
      final message = splitter.read(Uint8List.fromList([0x01, 0x02, 0xab])).single;
      expect(splitter.loggable(message), '0x0102ab');
    });
  });
}
