// Copyright Jody M Sankey and Grigory Morozov 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';
import 'dart:typed_data';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/2000/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:test/test.dart';

import '../utils.dart';

ValidatedMessage<ByteData, int> _testMsg(int pgn, List<int> payload) {
  return ValidatedMessage(pgn, 0x23, ByteData.sublistView(Uint8List.fromList(payload)));
}

ValidatedMessage<ByteData, int> _testHexMsg(int pgn, String hexPayload) {
  hexPayload = hexPayload.replaceAll('_', '');
  return _testMsg(pgn, [
    for (var i = 0; i < hexPayload.length; i += 2)
      int.parse(hexPayload.substring(i, i + 2), radix: 16),
  ]);
}

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

List<int> _i64(int value) {
  final bytes = Uint8List(8);
  ByteData.sublistView(bytes).setInt64(0, value, Endian.little);
  return bytes;
}

void main() {
  test('should register a parser matching each sentence file', () {
    final pgnFileName = RegExp(r'^\d+\.dart$');
    final fileTypes = Directory('lib/state/parsing/2000')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => pgnFileName.hasMatch(name))
        .map((name) => int.parse(name.substring(0, name.length - 5)));
    expect(Nmea2000Parser().supportedTypes, fileTypes.toSet());
  });

  test('should validate packet with correct header', () {
    final packet = _makePacket(127251, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
    final message = ForkValidator().validate(packet)!;
    expect(message.type, 127251);
    expect(message.sender, 0x23);
    expect(Uint8List.sublistView(message.payload), [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
  });

  test('should reject packet shorter than header', () {
    expect(() => ForkValidator().validate(ByteData(15)), throwsFormatException);
  });

  test('should reject packet with zero payload length', () {
    final packet = _makePacket(127251, []);
    expect(() => ForkValidator().validate(packet), throwsFormatException);
  });

  test('should reject packet whose declared payload length does not match its size', () {
    final packet = _makePacket(127251, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
    packet.setUint8(15, 12);
    expect(() => ForkValidator().validate(packet), throwsFormatException);
  });

  test('ignoredTypes and supportedTypes are disjoint', () {
    final parser = Nmea2000Parser();
    expect(parser.ignoredTypes.intersection(parser.supportedTypes), isEmpty);
    expect(parser.ignoredTypes, contains(60928));
  });

  test('should throw for unsupported PGN', () {
    final message = _testMsg(65000, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(() => Nmea2000Parser().parse(message), throwsFormatException);
  });

  test('should parse valid rate of turn packet', () {
    final message = _testMsg(127251, [0x04, ..._i32(-5585054), 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-10.0, Property.rateOfTurn)]),
    );
  });

  test('should parse valid vessel heading packet', () {
    final message = _testMsg(127250, [0x01, ..._u16(15708), ..._i16(0x7FFF), ..._i16(-349), 0x00]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(-1.9996, Property.variation),
        boundSingleValue(90.0002, Property.heading),
      ]),
    );
  });

  test('should convert magnetic vessel heading to true when variation is known', () {
    final message = _testMsg(127250, [0x01, ..._u16(15708), ..._i16(0x7FFF), ..._i16(-349), 0x01]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(-1.9996, Property.variation),
        boundSingleValue(91.9998, Property.heading),
      ]),
    );
  });

  test('should parse magnetic vessel heading packet without variation', () {
    final message = _testMsg(127250, [
      0x01,
      ..._u16(15708),
      ..._i16(0x7FFF),
      ..._i16(0x7FFF),
      0x01,
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(90.0002, Property.headingMag)]),
    );
  });

  test('should not parse heading from vessel heading packet with unknown reference', () {
    final message = _testMsg(127250, [0x01, ..._u16(15708), ..._i16(0x7FFF), ..._i16(-349), 0x02]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-1.9996, Property.variation)]),
    );
  });

  test('should parse vessel heading packet with unavailable heading', () {
    final message = _testMsg(127250, [0x01, 0xFF, 0xFF, ..._i16(0x7FFF), ..._i16(-349), 0x00]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-1.9996, Property.variation)]),
    );
  });

  test('should parse valid rudder packet within valid range', () {
    final message = _testMsg(127245, [0x01, 0x00, ..._i16(0), ..._i16(-5236), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-30.0001, Property.rudderAngle)]),
    );
  });

  test('should reject valid rudder packet outside valid range', () {
    final message = _testMsg(127245, [0x01, 0x00, ..._i16(0), ..._i16(17453), 0xFF, 0xFF]);
    expect(() => Nmea2000Parser().parse(message), throwsFormatException);
  });

  test('should parse valid rudder position rather than angle order', () {
    final message = _testMsg(127245, [0x01, 0x00, ..._i16(5236), ..._i16(-2618), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-15.0001, Property.rudderAngle)]),
    );
  });

  test('should parse valid magnetic variation packet', () {
    final message = _testMsg(127258, [0xFF, 0xFF, 0xFF, 0xFF, ..._i16(-349), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-1.9996, Property.variation, tier: 2)]),
    );
  });

  test('should parse valid fuel level packet', () {
    final message = _testMsg(127505, [0x00, ..._i16(12500), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(50.0, Property.fuelLevel)]),
    );
  });

  test('should parse valid water level packets for both instances', () {
    final message1 = _testMsg(127505, [0x10, ..._i16(25000), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message1),
      BoundValueListMatches([boundSingleValue(100.0, Property.water1Level)]),
    );
    final message2 = _testMsg(127505, [0x11, ..._i16(2500), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message2),
      BoundValueListMatches([boundSingleValue(10.0, Property.water2Level)]),
    );
  });

  test('should not parse fluid level packet for unsupported tank', () {
    final message = _testMsg(127505, [0x50, ..._i16(12500), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should reject fluid level packet outside valid range', () {
    final message = _testMsg(127505, [0x00, ..._i16(30000), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(() => Nmea2000Parser().parse(message), throwsFormatException);
  });

  test('should parse valid speed packet', () {
    final message = _testMsg(128259, [0xFF, ..._u16(320), ..._u16(510), 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(3.2, Property.speedThroughWater),
        boundSingleValue(5.1, Property.speedOverGround, tier: 2),
      ]),
    );
  });

  test('should parse speed packet with unavailable ground speed', () {
    final message = _testMsg(128259, [0xFF, ..._u16(320), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(3.2, Property.speedThroughWater)]),
    );
  });

  test('should parse speed packet with unavailable water speed', () {
    final message = _testMsg(128259, [0xFF, 0xFF, 0xFF, ..._u16(510), 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(5.1, Property.speedOverGround, tier: 2)]),
    );
  });

  test('should parse valid COG/SOG packet', () {
    final message = _testMsg(129026, [0x02, 0x00, ..._u16(47124), ..._u16(520), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(270.0006, Property.courseOverGround),
        boundSingleValue(5.2, Property.speedOverGround),
      ]),
    );
  });

  test('should parse real Raymarine COG/SOG payload', () {
    final message = _testHexMsg(129026, "FFFC76DE_0100FFFF");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(326.2995, Property.courseOverGround),
        boundSingleValue(0.01, Property.speedOverGround),
      ]),
    );
  });

  test('should not parse COG from magnetic referenced COG/SOG packet', () {
    final message = _testMsg(129026, [0x02, 0x01, ..._u16(47124), ..._u16(520), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(5.2, Property.speedOverGround)]),
    );
  });

  test('should parse valid water depth packet', () {
    final message = _testMsg(128267, [0x03, ..._u32(1234), ..._i16(-500), 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(12.34, Property.depthUncalibrated),
        boundSingleValue(11.84, Property.depthWithOffset),
      ]),
    );
  });

  test('should parse water depth packet with unavailable offset', () {
    final message = _testMsg(128267, [0x03, ..._u32(1234), 0xFF, 0x7F, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(12.34, Property.depthUncalibrated)]),
    );
  });

  test('should not parse water depth packet with unavailable depth', () {
    final message = _testMsg(128267, [0x03, 0xFF, 0xFF, 0xFF, 0xFF, ..._i16(-500), 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse valid distance log packet', () {
    final message = _testMsg(128275, [
      0xFF, 0xFF, // date
      0xFF, 0xFF, 0xFF, 0xFF, // time
      ..._u32(123456), // log
      ..._u32(6543), // trip
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(123456.0, Property.distanceTotal),
        boundSingleValue(6543.0, Property.distanceTrip),
      ]),
    );
  });

  test('should parse distance log packet with unavailable trip', () {
    final message = _testMsg(128275, [
      0xFF, 0xFF, // date
      0xFF, 0xFF, 0xFF, 0xFF, // time
      ..._u32(123456), // log
      0xFF, 0xFF, 0xFF, 0xFF, // trip
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(123456.0, Property.distanceTotal)]),
    );
  });

  test('should parse valid environmental parameters', () {
    final message = _testMsg(130310, [0x01, ..._u16(29355), ..._u16(29815), ..._u16(1013), 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(20.4, Property.waterTemperature, tier: 4),
        boundSingleValue(25.0, Property.airTemperature, tier: 4),
        boundSingleValue(101300.0, Property.pressure, tier: 3),
      ]),
    );
  });

  test('should reject environmental parameters packet with wrong length', () {
    final message = _testMsg(130310, [0x01, ..._u16(29355), ..._u16(29815), ..._u16(1013)]);
    expect(() => Nmea2000Parser().parse(message), throwsFormatException);
  });

  test('should parse valid rapid position packet', () {
    final message = _testMsg(129025, [..._i32(375000000), ..._i32(-1225000000)]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundDoubleValue(37.5, -122.5, Property.gpsPosition)]),
    );
  });

  test('should parse real Raymarine rapid position payload', () {
    final message = _testHexMsg(129025, "606E9E08_0072B7DB");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundDoubleValue(14.4600672, -60.873472, Property.gpsPosition)]),
    );
  });

  test('should not parse rapid position packet with unavailable latitude', () {
    final message = _testMsg(129025, [..._i32(0x7FFFFFFF), ..._i32(-1225000000)]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse valid GNSS position packet', () {
    final message = _testMsg(129029, [
      0xFF, // SID
      ..._u16(20000), // date
      ..._u32(452960000), // time
      ..._i64(375000000000000000), // latitude
      ..._i64(-1225000000000000000), // longitude
      ...List.filled(8, 0xFF), // altitude
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundDoubleValue(37.5, -122.5, Property.gpsPosition, tier: 2),
        boundSingleValue(DateTime.utc(2024, 10, 4, 12, 34, 56), Property.utcTime, tier: 3),
      ]),
    );
  });

  test('should parse GNSS position packet including HDOP', () {
    final message = _testMsg(129029, [
      0xFF, // SID
      ..._u16(20000), // date
      ..._u32(452960000), // time
      ..._i64(375000000000000000), // latitude
      ..._i64(-1225000000000000000), // longitude
      ...List.filled(8, 0xFF), // altitude
      0x12, // GNSS type and method
      0xFC, // integrity and reserved
      0x0A, // number of SVs
      ..._i16(123), // HDOP
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundDoubleValue(37.5, -122.5, Property.gpsPosition, tier: 2),
        boundSingleValue(DateTime.utc(2024, 10, 4, 12, 34, 56), Property.utcTime, tier: 3),
        boundSingleValue(1.23, Property.gpsHdop, tier: 2),
      ]),
    );
  });

  test('should parse valid cross track error packet', () {
    final message = _testMsg(129283, [0xFF, 0x00, ..._i32(-12345), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(-123.45, Property.crossTrackError)]),
    );
  });

  test('should parse valid navigation data packet', () {
    final message = _testMsg(129284, [
      0xFF, // SID
      ..._u32(123456), // distance to waypoint
      0x00, // reference and flags
      0xFF, 0xFF, 0xFF, 0xFF, // ETA time
      0xFF, 0xFF, // ETA date
      0xFF, 0xFF, // bearing, origin to destination
      ..._u16(7854), // bearing, position to destination
      ...List.filled(8, 0xFF), // waypoint numbers
      ...List.filled(8, 0xFF), // destination latitude and longitude
      0xFF, 0xFF, // waypoint closing velocity
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(1234.56, Property.waypointRange),
        boundSingleValue(45.0001, Property.waypointBearing),
      ]),
    );
  });

  test('should not parse bearing from magnetic referenced navigation data packet', () {
    final message = _testMsg(129284, [
      0xFF, // SID
      ..._u32(123456), // distance to waypoint
      0x01, // reference and flags
      0xFF, 0xFF, 0xFF, 0xFF, // ETA time
      0xFF, 0xFF, // ETA date
      0xFF, 0xFF, // bearing, origin to destination
      ..._u16(7854), // bearing, position to destination
      ...List.filled(8, 0xFF), // waypoint numbers
      ...List.filled(8, 0xFF), // destination latitude and longitude
      0xFF, 0xFF, // waypoint closing velocity
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(1234.56, Property.waypointRange)]),
    );
  });

  test('should parse valid set and drift packet', () {
    final message = _testMsg(129291, [0xFF, 0x00, ..._u16(7854), ..._u16(250), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(45.0001, Property.currentSet),
        boundSingleValue(2.5, Property.currentDrift),
      ]),
    );
  });

  test('should not parse set from magnetic referenced set and drift packet', () {
    final message = _testMsg(129291, [0xFF, 0x01, ..._u16(7854), ..._u16(250), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(2.5, Property.currentDrift)]),
    );
  });

  test('should parse valid date/time packet', () {
    final message = _testMsg(129033, [..._u16(20000), ..._u32(452960000), 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(DateTime.utc(2024, 10, 4, 12, 34, 56), Property.utcTime, tier: 2),
      ]),
    );
  });

  test('should not parse date/time packet with unavailable date', () {
    final message = _testMsg(129033, [0xFF, 0xFF, ..._u32(452960000), 0xFF, 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
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
    final message = _testMsg(130306, [0x04, ..._u16(1020), ..._u16(7854), 0x02, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(10.2, Property.apparentWindSpeed),
        boundSingleValue(45.0001, Property.apparentWindAngle),
      ]),
    );
  });

  test('should parse valid true ground referenced wind packet', () {
    final message = _testMsg(130306, [0x04, ..._u16(1020), ..._u16(7854), 0x00, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(10.2, Property.trueWindSpeed),
        boundSingleValue(45.0001, Property.trueWindDirection),
      ]),
    );
  });

  test('should parse boat referenced true wind packet wrapping angle from bow', () {
    final message = _testMsg(130306, [0x04, ..._u16(1020), ..._u16(47124), 0x03, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(10.2, Property.trueWindSpeed),
        boundSingleValue(-89.9994, Property.trueWindAngle),
      ]),
    );
  });

  test('should not parse angle from magnetic ground referenced wind packet', () {
    final message = _testMsg(130306, [0x04, ..._u16(1020), ..._u16(7854), 0x01, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(10.2, Property.trueWindSpeed)]),
    );
  });

  test('should reject wind packet with angle outside valid range', () {
    final message = _testMsg(130306, [0x04, ..._u16(1020), ..._u16(65000), 0x02, 0xFF, 0xFF]);
    expect(() => Nmea2000Parser().parse(message), throwsFormatException);
  });

  test('should parse valid humidity packet', () {
    final message = _testMsg(130313, [0xFF, 0x00, 0x00, ..._i16(12500), 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(50.0, Property.relativeHumidity)]),
    );
  });

  test('should parse valid atmospheric pressure packet', () {
    final message = _testMsg(130314, [0xFF, 0x00, 0x00, ..._i32(1013250), 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(101325.0, Property.pressure)]),
    );
  });

  test('should parse valid oil pressure packet', () {
    final message = _testMsg(130314, [0xFF, 0x00, 0x07, ..._i32(3000000), 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(300000.0, Property.engine1OilPressure)]),
    );
  });

  test('should not parse pressure packet for unsupported source', () {
    final message = _testMsg(130314, [0xFF, 0x00, 0x02, ..._i32(1013250), 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse valid extended temperature packets for each supported source', () {
    final parser = Nmea2000Parser();
    final waterMessage = _testMsg(130316, [0xFF, 0x00, 0x00, 0x1E, 0x79, 0x04, 0xFF, 0xFF]);
    expect(
      parser.parse(waterMessage),
      BoundValueListMatches([boundSingleValue(20.0, Property.waterTemperature)]),
    );
    final airMessage = _testMsg(130316, [0xFF, 0x00, 0x01, 0xA6, 0x8C, 0x04, 0xFF, 0xFF]);
    expect(
      parser.parse(airMessage),
      BoundValueListMatches([boundSingleValue(25.0, Property.airTemperature)]),
    );
    final dewMessage = _testMsg(130316, [0xFF, 0x00, 0x02, 0x96, 0x65, 0x04, 0xFF, 0xFF]);
    expect(
      parser.parse(dewMessage),
      BoundValueListMatches([boundSingleValue(15.0, Property.dewPoint)]),
    );
  });

  test('should parse valid system time packet', () {
    final message = _testMsg(126992, [0xFF, 0xFF, ..._u16(20000), ..._u32(452960000)]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(DateTime.utc(2024, 10, 4, 12, 34, 56), Property.utcTime),
      ]),
    );
  });

  test('should not parse system time packet with unavailable date', () {
    final message = _testMsg(126992, [0xFF, 0xFF, 0xFF, 0xFF, ..._u32(452960000)]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse real recorded system time payload', () {
    final message = _testHexMsg(126992, "FFFF_AF50_5221F604");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(DateTime.utc(2026, 7, 21, 2, 18, 43, 925), Property.utcTime),
      ]),
    );
  });

  test('should parse valid attitude packet', () {
    final message = _testMsg(127257, [0xFF, ..._i16(5236), ..._i16(-2618), ..._i16(7854), 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(30.0001, Property.yaw),
        boundSingleValue(-15.0001, Property.pitch),
        boundSingleValue(45.0001, Property.roll),
      ]),
    );
  });

  test('should parse real recorded attitude payload with unavailable yaw', () {
    final message = _testHexMsg(127257, "FFFF7F_1D00_6A00_FF");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(0.1662, Property.pitch),
        boundSingleValue(0.6073, Property.roll),
      ]),
    );
  });

  test('should parse valid GNSS DOPs packet', () {
    final message = _testMsg(129539, [0xFF, 0xFF, ..._i16(123), 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(1.23, Property.gpsHdop)]),
    );
  });

  test('should not parse GNSS DOPs packet with unavailable HDOP', () {
    final message = _testMsg(129539, [0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse real recorded GNSS DOPs payload', () {
    final message = _testHexMsg(129539, "00_DB_3400_4700_2C00");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(0.52, Property.gpsHdop)]),
    );
  });

  test('should parse valid environmental parameters packet', () {
    final message = _testMsg(130311, [0xFF, 0x00, ..._u16(29355), ..._u16(12500), ..._u16(1013)]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(20.4, Property.waterTemperature, tier: 3),
        boundSingleValue(50.0, Property.relativeHumidity, tier: 2),
        boundSingleValue(101300.0, Property.pressure, tier: 2),
      ]),
    );
  });

  test('should not parse temperature from environmental parameters packet with unsupported '
      'source', () {
    final message = _testMsg(130311, [0xFF, 0x08, ..._u16(29355), ..._u16(12500), ..._u16(1013)]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(50.0, Property.relativeHumidity, tier: 2),
        boundSingleValue(101300.0, Property.pressure, tier: 2),
      ]),
    );
  });

  test('should parse real recorded environmental parameters payload', () {
    final message = _testHexMsg(130311, "FFFF_FFFF_FF7F_F703");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(101500.0, Property.pressure, tier: 2)]),
    );
  });

  test('should parse valid single-source temperature packet for each supported source', () {
    final parser = Nmea2000Parser();
    final waterMessage = _testMsg(130312, [0xFF, 0xFF, 0x00, ..._u16(29355), 0xFF, 0xFF, 0xFF]);
    expect(
      parser.parse(waterMessage),
      BoundValueListMatches([boundSingleValue(20.4, Property.waterTemperature, tier: 2)]),
    );
    final airMessage = _testMsg(130312, [0xFF, 0xFF, 0x01, ..._u16(29815), 0xFF, 0xFF, 0xFF]);
    expect(
      parser.parse(airMessage),
      BoundValueListMatches([boundSingleValue(25.0, Property.airTemperature, tier: 2)]),
    );
  });

  test('should not parse single-source temperature packet for unsupported source', () {
    final message = _testMsg(130312, [0xFF, 0xFF, 0x02, ..._u16(29355), 0xFF, 0xFF, 0xFF]);
    expect(Nmea2000Parser().parse(message), isEmpty);
  });

  test('should parse real recorded single-source temperature payload', () {
    final message = _testHexMsg(130312, "0000_00DD_72FF_FFFF");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([boundSingleValue(20.9, Property.waterTemperature, tier: 2)]),
    );
  });

  test('should parse valid direction data packet with true directional reference', () {
    final message = _testMsg(130577, [
      0xFF,
      0x00,
      ..._u16(7854), // cog
      ..._u16(520), // sog
      ..._u16(15708), // heading
      ..._u16(320), // stw
      ..._u16(7854), // set
      ..._u16(250), // drift
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(5.2, Property.speedOverGround, tier: 3),
        boundSingleValue(3.2, Property.speedThroughWater, tier: 2),
        boundSingleValue(2.5, Property.currentDrift, tier: 2),
        boundSingleValue(45.0001, Property.courseOverGround, tier: 2),
        boundSingleValue(90.0002, Property.heading, tier: 2),
        boundSingleValue(45.0001, Property.currentSet, tier: 2),
      ]),
    );
  });

  test('should not parse directional fields from direction data packet with other reference', () {
    final message = _testMsg(130577, [
      0xFF,
      0x04,
      ..._u16(7854), // cog
      ..._u16(520), // sog
      ..._u16(15708), // heading
      ..._u16(320), // stw
      ..._u16(7854), // set
      ..._u16(250), // drift
    ]);
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(5.2, Property.speedOverGround, tier: 3),
        boundSingleValue(3.2, Property.speedThroughWater, tier: 2),
        boundSingleValue(2.5, Property.currentDrift, tier: 2),
      ]),
    );
  });

  test('should parse real recorded direction data payload', () {
    final message = _testHexMsg(130577, "C0_52_8467_0100_FFFF_FFFF_1F46_0100");
    expect(
      Nmea2000Parser().parse(message),
      BoundValueListMatches([
        boundSingleValue(0.01, Property.speedOverGround, tier: 3),
        boundSingleValue(0.01, Property.currentDrift, tier: 2),
        boundSingleValue(151.8338, Property.courseOverGround, tier: 2),
        boundSingleValue(102.8517, Property.currentSet, tier: 2),
      ]),
    );
  });
}
