// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/network.dart';
import 'package:test/test.dart';

// A valid DPT sentence that yields depthWithOffset and depthUncalibrated.
const _dpt = r'$YDDPT,18.56,-1.61,140.0,*67';

Uint8List _pkt(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  group('findSplit', () {
    test('empty string', () {
      expect(findSplit(''), -1);
    });

    test('single character', () {
      expect(findSplit('x'), -1);
    });

    test('no terminator or start marker', () {
      expect(findSplit('\$GSV,5,1,18,65,75,277,17,10,69'), -1);
    });

    test('LF terminated', () {
      expect(findSplit('\$YDMWV,184.6,R,1.4,M,A*2D\n\$YDMWV,182.8,T,2.4,M,A*20\n\$YDVTG,4.1'), 25);
    });

    test('CRLF terminated', () {
      expect(
        findSplit('\$YDMWV,184.6,R,1.4,M,A*2D\r\n\$YDMWV,182.8,T,2.4,M,A*20\r\n\$YDVTG,4.1'),
        25,
      );
    });

    test('unterminated', () {
      expect(findSplit('\$YDMWV,184.6,R,1.4,M,A*2D\$YDMWV,182.8,T,2.4,M,A*20\$YDVTG,4.1'), 25);
    });
  });

  group('valuesFromPackets', () {
    late NmeaParser parser;

    setUp(() {
      parser = NmeaParser(true);
    });

    test('empty packet yields null', () async {
      final stream = valuesFromPackets(Stream.fromIterable([Uint8List(0)]), parser);
      expect(await stream.take(1).toList(), [null]);
    });

    test('LF-terminated sentence yields parsed BoundValues', () async {
      final stream = valuesFromPackets(Stream.fromIterable([_pkt('$_dpt\n')]), parser);
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('CRLF-terminated sentence yields parsed BoundValues', () async {
      final stream = valuesFromPackets(Stream.fromIterable([_pkt('$_dpt\r\n')]), parser);
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('sentences from multiple packets yield all values', () async {
      // Each packet supplies one complete sentence.
      final stream = valuesFromPackets(
        Stream.fromIterable([_pkt('$_dpt\n'), _pkt('$_dpt\n')]),
        parser,
      );
      final values = await stream.where((v) => v != null).map((v) => v!).take(4).toList();
      expect(values.map((v) => v.property), [
        Property.depthWithOffset,
        Property.depthUncalibrated,
        Property.depthWithOffset,
        Property.depthUncalibrated,
      ]);
    });

    test('sentence split across two packets yields values', () async {
      final mid = _dpt.length ~/ 2;
      final stream = valuesFromPackets(
        Stream.fromIterable([_pkt(_dpt.substring(0, mid)), _pkt('${_dpt.substring(mid)}\n')]),
        parser,
      );
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('adjacent sentences without line terminators yield all values', () async {
      // The $ starting the third sentence flushes the second out of remaining.
      final stream = valuesFromPackets(Stream.fromIterable([_pkt('$_dpt$_dpt\n\$')]), parser);
      final values = await stream.where((v) => v != null).map((v) => v!).take(4).toList();
      expect(values.map((v) => v.property), [
        Property.depthWithOffset,
        Property.depthUncalibrated,
        Property.depthWithOffset,
        Property.depthUncalibrated,
      ]);
    });

    test('invalid checksum logs warning and yields no value', () async {
      final stream = valuesFromPackets(
        Stream.fromIterable([
          _pkt(
            r'$YDDPT,18.56,-1.61,140.0,*00'
            '\n',
          ),
          Uint8List(0),
        ]),
        parser,
      );
      // The FormatException is caught; the subsequent empty packet emits null.
      expect(await stream.take(1).toList(), [null]);
    });
  });
}
