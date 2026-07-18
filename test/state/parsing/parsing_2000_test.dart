// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';
import 'dart:typed_data';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/2000/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:test/test.dart';

import '../utils.dart';

ByteData _makePacket(
  int pgn,
  List<int> payload, {
  int source = 0x23,
  int destination = 0xFF,
  int priority = 3,
  int timestampMs = 0,
}) {
  final bytes = Uint8List(payload.length + 16);
  final data = ByteData.sublistView(bytes);
  data.setUint64(0, timestampMs, Endian.little);
  bytes[8] = source;
  bytes[9] = destination;
  bytes[10] = priority;
  data.setUint32(11, pgn, Endian.little);
  bytes[15] = payload.length;
  bytes.setRange(16, bytes.length, payload);
  return data;
}

ByteData _makeHexPacket(
  int pgn,
  String hexPayload, {
  int source = 0x23,
  int destination = 0xFF,
  int priority = 3,
  int timestampMs = 0,
}) {
  hexPayload = hexPayload.replaceAll('_', '');
  final payload = Uint8List.fromList([
    for (var i = 0; i < hexPayload.length; i += 2)
      int.parse(hexPayload.substring(i, i + 2), radix: 16),
  ]);
  return _makePacket(
    pgn,
    payload,
    source: source,
    destination: destination,
    priority: priority,
    timestampMs: timestampMs,
  );
}

List<int> _u16(int value) {
  final bytes = Uint8List(2);
  ByteData.sublistView(bytes).setUint16(0, value, Endian.little);
  return bytes;
}

List<int> _i16(int value) {
  final bytes = Uint8List(2);
  ByteData.sublistView(bytes).setInt16(0, value, Endian.little);
  return bytes;
}

List<int> _u32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
  return bytes;
}

List<int> _i32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setInt32(0, value, Endian.little);
  return bytes;
}

void main() {
  test('should register a parser matching each sentence file', () {
    final fileTypes = Directory('lib/state/parsing/2000')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.dart') && name != 'common.dart')
        .map((name) => int.parse(name.substring(0, name.length - 5)));
    expect(Nmea2000Parser.supportedPgns.toSet(), fileTypes.toSet());
  });

  test('should parse valid rate of turn packet', () {
    final packet = _makePacket(127251, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([boundSingleValue(-10.0, Property.rateOfTurn)]),
    );
  });

  test('should parse valid vessel heading packet', () {
    final packet = _makePacket(127250, [
      0x01,
      ..._u16(15708),
      ..._i16(0x7FFF),
      ..._i16(-349),
      0x00,
    ]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(-1.9996, Property.variation),
        boundSingleValue(90.0002, Property.heading),
      ]),
    );
  });

  test('should parse valid rudder packet within valid range', () {
    final parser = Nmea2000Parser();
    final packet = _makePacket(127245, [0x01, 0x00, ..._i16(0), ..._i16(-5236), 0xFF, 0xFF]);
    expect(
      parser.parsePacket(packet),
      BoundValueListMatches([boundSingleValue(-30.0001, Property.rudderAngle)]),
    );
    expect(parser.successCounts.total, 1);
  });

  test('should reject valid rudder packet outside valid range', () {
    final parser = Nmea2000Parser();
    final packet = _makePacket(127245, [0x01, 0x00, ..._i16(0), ..._i16(17453), 0xFF, 0xFF]);
    expect(() => parser.parsePacket(packet), throwsFormatException);
    expect(parser.successCounts.total, 0);
    expect(parser.emptyCounts.total, 0);
  });

  test('should parse valid rudder position rather than angle order', () {
    final packet = _makePacket(127245, [0x01, 0x00, ..._i16(5236), ..._i16(-2618), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([boundSingleValue(-15.0001, Property.rudderAngle)]),
    );
  });

  test('should parse valid COG/SOG packet', () {
    final packet = _makePacket(129026, [0x02, 0x00, ..._u16(47124), ..._u16(520), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(270.0006, Property.courseOverGround),
        boundSingleValue(5.2, Property.speedOverGround),
      ]),
    );
  });

  test('should parse real Raymarine COG/SOG payload', () {
    final packet = _makeHexPacket(129026, "FFFC76DE_0100FFFF");
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(326.2995, Property.courseOverGround),
        boundSingleValue(0.01, Property.speedOverGround),
      ]),
    );
  });

  test('should parse valid water depth packet', () {
    final packet = _makePacket(128267, [0x03, ..._u32(1234), ..._i16(-500), 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(12.34, Property.depthUncalibrated),
        boundSingleValue(11.84, Property.depthWithOffset),
      ]),
    );
  });

  test('should parse valid environmental parameters', () {
    final packet = _makePacket(130310, [0x01, ..._u16(29355), ..._u16(29815), ..._u16(1013), 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(20.4, Property.waterTemperature, tier: 2),
        boundSingleValue(25.0, Property.airTemperature, tier: 2),
        boundSingleValue(101300.0, Property.pressure, tier: 2),
      ]),
    );
  });

  test('should parse valid rapid position packet', () {
    final packet = _makePacket(129025, [..._i32(375000000), ..._i32(-1225000000)]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([boundDoubleValue(37.5, -122.5, Property.gpsPosition, tier: 2)]),
    );
  });

  test('should parse real Raymarine rapid position payload', () {
    final packet = _makeHexPacket(129025, "606E9E08_0072B7DB");
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundDoubleValue(14.4600672, -60.873472, Property.gpsPosition, tier: 2),
      ]),
    );
  });

  test('should parse valid date/time packet', () {
    final packet = _makePacket(129033, [..._u16(20000), ..._u32(452960000), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(DateTime.utc(2024, 10, 4, 12, 34, 56), Property.utcTime, tier: 2),
      ]),
    );
  });

  // TODO: Add support and tests for waypoint name (PGN 129285).
  // Adding properties that only apply to one protocol probably requires notifying in the data
  // cell when the selected property will never be available on the selected protocol, which is
  // a significant change.

  // TODO: Add support and tests for VHF channel (PGN 129799).
  // Adding properties that only apply to one protocol probably requires notifying in the data
  // cell when the selected property will never be available on the selected protocol, which is
  // a significant change.

  test('should parse valid apparent wind packet', () {
    final packet = _makePacket(130306, [0x04, ..._u16(1020), ..._u16(7854), 0x02]);
    expect(
      Nmea2000Parser().parsePacket(packet),
      BoundValueListMatches([
        boundSingleValue(10.2, Property.apparentWindSpeed),
        boundSingleValue(45.0001, Property.apparentWindAngle),
      ]),
    );
  });
}
