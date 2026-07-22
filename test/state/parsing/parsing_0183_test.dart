// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:nmea_dashboard/state/parsing/0183/common.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:test/test.dart';

import '../utils.dart';

ValidatedMessage<String, String> _testMsg(String type, String payload) {
  return ValidatedMessage(type, 'YD', payload);
}

void main() {
  test('should register a parser matching each sentence file', () {
    final fileTypes = Directory('lib/state/parsing/0183')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.dart') && name != 'common.dart')
        .map((name) => name.substring(0, name.length - 5).toUpperCase());
    expect(Nmea0183Parser().supportedTypes, fileTypes.toSet());
  });

  test('should validate message with correct checksum', () {
    final message = Nmea0183Validator(true).validate(r'$YDDPT,18.56,-1.61,140.0,*67')!;
    expect(message.type, 'DPT');
    expect(message.sender, 'YD');
    expect(message.payload, '18.56,-1.61,140.0,');
  });

  test('should fail invalid checksum', () {
    expect(
      () => Nmea0183Validator(true).validate(r'$YDDPT,18.56,-1.61,140.0,*00'),
      throwsFormatException,
    );
  });

  test('should accept missing checksum iff checksum not required', () {
    final message = Nmea0183Validator(false).validate(r'$YDDPT,18.56,-1.61,140.0')!;
    expect(message.type, 'DPT');
    expect(message.sender, 'YD');
    expect(message.payload, '18.56,-1.61,140.0');
    expect(
      () => Nmea0183Validator(true).validate(r'$YDDPT,18.56,-1.61,140.0'),
      throwsFormatException,
    );
  });

  test('should silently discard encapsulated sentence', () {
    expect(
      Nmea0183Validator(true).validate(r'!AIVDM,1,1,,A,13aGt00P00PD;88MD5MTDww@0D7k,0*74'),
      isNull,
    );
  });

  test('should reject message without dollar prefix', () {
    expect(
      () => Nmea0183Validator(true).validate('YDDPT,18.56,-1.61,140.0,*00'),
      throwsFormatException,
    );
  });

  test('should reject truncated message', () {
    expect(() => Nmea0183Validator(false).validate(r'$YDDPT'), throwsFormatException);
  });

  test('ignoredTypes and supportedTypes are disjoint', () {
    final parser = Nmea0183Parser();
    expect(parser.ignoredTypes.intersection(parser.supportedTypes), isEmpty);
    expect(parser.ignoredTypes, contains('GSV'));
  });

  test('should throw for unsupported message type', () {
    expect(() => Nmea0183Parser().parse(_testMsg('XXX', '4,1,17,N')), throwsFormatException);
  });

  test('should parse BWR', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('BWR', '203514.60,3740.2436,N,12222.6994,W,148.0,T,134.9,M,0.11,N,0,A'),
      ),
      BoundValueListMatches([
        boundSingleValue(203.71993, Property.waypointRange),
        boundSingleValue(148.0, Property.waypointBearing),
      ]),
    );
  });

  test('should skip empty RMB ', () {
    expect(
      Nmea0183Parser().parse(_testMsg('BWR', ',,N,,E,,T,,M,,N,')),
      BoundValueListMatches([]),
    );
  });

  test('should support DBT', () {
    expect(
      Nmea0183Parser().parse(_testMsg('DBT', '58.10,f,17.71,M,,F')),
      BoundValueListMatches([boundSingleValue(17.71, Property.depthUncalibrated, tier: 2)]),
    );
  });

  test('should reject DPT with too few fields', () {
    expect(() => Nmea0183Parser().parse(_testMsg('DPT', '18.56')), throwsFormatException);
  });

  test('should parse DPT', () {
    expect(
      Nmea0183Parser().parse(_testMsg('DPT', '18.56,-1.61,140.0,')),
      BoundValueListMatches([
        boundSingleValue(16.95, Property.depthWithOffset),
        boundSingleValue(18.56, Property.depthUncalibrated),
      ]),
    );
  });

  test('should parse DPT without data', () {
    expect(Nmea0183Parser().parse(_testMsg('DPT', ',0.0')), BoundValueListMatches([]));
  });

  test('should parse HDG with variation', () {
    expect(
      Nmea0183Parser().parse(_testMsg('HDG', '7.3,,,13.1,E')),
      BoundValueListMatches([
        boundSingleValue(-13.1, Property.variation),
        boundSingleValue(20.4, Property.heading),
      ]),
    );
  });

  test('should parse HDG without variation', () {
    expect(
      Nmea0183Parser().parse(_testMsg('HDG', '173.8,,,,')),
      BoundValueListMatches([boundSingleValue(173.8, Property.headingMag)]),
    );
  });

  test('should reject HDG with wrong field count', () {
    expect(() => Nmea0183Parser().parse(_testMsg('HDG', '7.3,X,Y')), throwsFormatException);
  });

  test('should reject HDG with invalid variation direction', () {
    expect(() => Nmea0183Parser().parse(_testMsg('HDG', '7.3,,,13.1,X')), throwsFormatException);
  });

  test('should parse HDM', () {
    expect(
      Nmea0183Parser().parse(_testMsg('HDM', '143.3,M')),
      BoundValueListMatches([boundSingleValue(143.3, Property.headingMag, tier: 2)]),
    );
  });

  test('should parse GGA with HDOP', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('GGA', '170202.60,3749.3097,N,12228.9446,W,1,12,0.86,,M,-29.70,M,,'),
      ),
      BoundValueListMatches([
        boundDoubleValue(37.82182833, -122.48241, Property.gpsPosition),
        boundSingleValue(0.86, Property.gpsHdop),
      ]),
    );
  });

  test('should parse GGA without HDOP', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('GGA', '170202.60,3749.3097,N,12228.9446,W,1,12,,,M,-29.70,M,,'),
      ),
      BoundValueListMatches([boundDoubleValue(37.82183, -122.48241, Property.gpsPosition)]),
    );
  });

  test('should parse GLL', () {
    expect(
      Nmea0183Parser().parse(_testMsg('GLL', '3748.8322,N,12230.6429,W,171453.24,A,A')),
      BoundValueListMatches([
        boundDoubleValue(37.81387, -122.51072, Property.gpsPosition, tier: 2),
      ]),
    );
  });

  test('should parse GLL with south latitude', () {
    expect(
      Nmea0183Parser().parse(_testMsg('GLL', '3748.8322,S,12230.6429,W,171453.24,A,A')),
      BoundValueListMatches([
        boundDoubleValue(-37.81387, -122.51072, Property.gpsPosition, tier: 2),
      ]),
    );
  });

  test('should reject GLL with invalid latitude direction', () {
    expect(
      () => Nmea0183Parser().parse(_testMsg('GLL', '3748.8322,X,12230.6429,W,171453.24,A,A')),
      throwsFormatException,
    );
  });

  test('should reject GLL with invalid longitude direction', () {
    expect(
      () => Nmea0183Parser().parse(_testMsg('GLL', '3748.8322,N,12230.6429,X,171453.24,A,A')),
      throwsFormatException,
    );
  });

  test('should parse MDA with temp and RH', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MDA', ',I,,B,23.9,C,,C,55.5,,14.4,C,,T,,M,,N,,M')),
      BoundValueListMatches([
        boundSingleValue(23.9, Property.airTemperature),
        boundSingleValue(55.5, Property.relativeHumidity),
        boundSingleValue(14.4, Property.dewPoint),
      ]),
    );
  });

  test('should parse MDA with pressure', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MDA', '29.8902,I,1.0122,B,,C,,C,,,,C,,T,,M,,N,,M')),
      BoundValueListMatches([boundSingleValue(101220.0, Property.pressure)]),
    );
  });

  test('should parse MDA with pressure, water temp, and TWD', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('MDA', '30.1767,I,1.0219,B,,C,20.4,C,,,,C,315.6,T,302.6,M,9.3,N,4.8,M'),
      ),
      BoundValueListMatches([
        boundSingleValue(102190.0, Property.pressure),
        boundSingleValue(20.4, Property.waterTemperature),
        boundSingleValue(315.6, Property.trueWindDirection, tier: 2),
      ]),
    );
  });

  test('should parse MWD with direction', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWD', '154.7,T,141.8,M,12.1,N,6.2,M')),
      BoundValueListMatches([
        boundSingleValue(154.7, Property.trueWindDirection),
        boundSingleValue(6.2, Property.trueWindSpeed, tier: 2),
      ]),
    );
  });

  test('should parse MWD with missing direction', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWD', ',T,,M,12.1,N,6.2,M')),
      BoundValueListMatches([boundSingleValue(6.2, Property.trueWindSpeed, tier: 2)]),
    );
  });

  test('should reject MWD with invalid field count', () {
    expect(() => Nmea0183Parser().parse(_testMsg('MWD', '154.7,T,141.8')), throwsFormatException);
  });

  test('should reject MWD with wrong field value', () {
    expect(
      () => Nmea0183Parser().parse(_testMsg('MWD', '154.7,X,141.8,M,12.1,N,6.2,M')),
      throwsFormatException,
    );
  });

  test('should parse MWD with direction and only one speed format', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWD', '322.8,T,333.9,M,4.5,M')),
      BoundValueListMatches([
        boundSingleValue(322.8, Property.trueWindDirection),
        boundSingleValue(4.5, Property.trueWindSpeed, tier: 2),
      ]),
    );
  });

  test('should parse MWV with apparent in m/s', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', '354.9,R,0.9,M,A')),
      BoundValueListMatches([
        boundSingleValue(354.9, Property.apparentWindAngle),
        boundSingleValue(0.9, Property.apparentWindSpeed),
      ]),
    );
  });

  test('should parse MWV with apparent in kmph', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', '354.9,R,3.24,K,A')),
      BoundValueListMatches([
        boundSingleValue(354.9, Property.apparentWindAngle),
        boundSingleValue(0.9, Property.apparentWindSpeed),
      ]),
    );
  });

  test('should parse MWV with true in m/s', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', '352.5,T,0.6,M,A')),
      BoundValueListMatches([
        boundSingleValue(352.5, Property.trueWindAngle),
        boundSingleValue(0.6, Property.trueWindSpeed),
      ]),
    );
  });

  test('should parse MWV with true in knots', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', '352.5,T,20.0,N,A')),
      BoundValueListMatches([
        boundSingleValue(352.5, Property.trueWindAngle),
        boundSingleValue(10.28891, Property.trueWindSpeed),
      ]),
    );
  });

  test('should parse MWV without angle', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', ',R,0.9,M,A')),
      BoundValueListMatches([boundSingleValue(0.9, Property.apparentWindSpeed)]),
    );
  });

  test('should parse MWV with true in knots', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MWV', '352.5,T,20.0,N,A')),
      BoundValueListMatches([
        boundSingleValue(352.5, Property.trueWindAngle),
        boundSingleValue(10.28891, Property.trueWindSpeed),
      ]),
    );
  });

  test('should parse MTW', () {
    expect(
      Nmea0183Parser().parse(_testMsg('MTW', '20.4,C')),
      BoundValueListMatches([boundSingleValue(20.4, Property.waterTemperature, tier: 3)]),
    );
  });

  test('should parse RMB', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('RMB', 'A,0.100,L,0,0,3740.2436,N,12222.6994,W,0.11,148.0,0.0,V,A'),
      ),
      BoundValueListMatches([
        boundSingleValue(203.71993, Property.waypointRange, tier: 2),
        boundSingleValue(148.0, Property.waypointBearing, tier: 2),
        boundSingleValue(-185.1999, Property.crossTrackError, tier: 2),
      ]),
    );
  });

  test('should skip empty RMB ', () {
    expect(
      Nmea0183Parser().parse(_testMsg('RMB', 'A,,R,,,,N,,E,,,,,')),
      BoundValueListMatches([]),
    );
  });

  test('should parse RMC', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('RMC', '230830,A,1755.039,N,06443.653,W,5.50,357.0,250803,3.0,W'),
      ),
      BoundValueListMatches([
        boundDoubleValue(17.917317, -64.72755, Property.gpsPosition, tier: 3),
        boundSingleValue(DateTime.utc(2003, 08, 25, 23, 08, 30), Property.utcTime, tier: 2),
        boundSingleValue(2.82945, Property.speedOverGround, tier: 2),
        boundSingleValue(357.0, Property.courseOverGround, tier: 2),
        boundSingleValue(3.0, Property.variation, tier: 2),
      ]),
    );
  });

  test('should parse ROT', () {
    expect(
      Nmea0183Parser().parse(_testMsg('ROT', '-176.7,A')),
      BoundValueListMatches([boundSingleValue(-2.945, Property.rateOfTurn)]),
    );
  });

  test('should parse RSA', () {
    expect(
      Nmea0183Parser().parse(_testMsg('RSA', '2.8,A,,V')),
      BoundValueListMatches([boundSingleValue(2.8, Property.rudderAngle)]),
    );
  });
  test('should parse VDR', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VDR', '88.4,T,75.3,M,1.6,N')),
      BoundValueListMatches([
        boundSingleValue(88.4, Property.currentSet),
        boundSingleValue(0.82311, Property.currentDrift),
      ]),
    );
  });
  test('should parse VHW', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VHW', '339.8,T,326.7,M,1.3,N,2.4,K,')),
      BoundValueListMatches([boundSingleValue(0.6667, Property.speedThroughWater)]),
    );
  });

  test('should parse VHW without data', () {
    expect(Nmea0183Parser().parse(_testMsg('VHW', ',T,,M,,N,,K')), BoundValueListMatches([]));
  });

  test('should parse VHW with missing kmph', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VHW', ',,301,M,4.2,N,,')),
      BoundValueListMatches([boundSingleValue(2.1607, Property.speedThroughWater)]),
    );
    expect(
      Nmea0183Parser().parse(_testMsg('VHW', ',,,,00.0,N,,')),
      BoundValueListMatches([boundSingleValue(0.0, Property.speedThroughWater)]),
    );
  });

  test('should parse VLW', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VLW', '363.135,N,181.393,N')),
      BoundValueListMatches([
        boundSingleValue(672525.7752, Property.distanceTotal),
        boundSingleValue(335939.7137, Property.distanceTrip),
      ]),
    );
  });

  test('should parse VLW without trip', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VLW', '363.135,N,,')),
      BoundValueListMatches([boundSingleValue(672525.7752, Property.distanceTotal)]),
    );
  });

  test('should parse VTG', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VTG', '210.9,T,197.8,M,0.6,N,1.2,K,A')),
      BoundValueListMatches([
        boundSingleValue(210.9, Property.courseOverGround),
        boundSingleValue(0.33333, Property.speedOverGround),
      ]),
    );
  });

  test('should parse VWR', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VWR', '065,L,21.3,N,,,,')),
      BoundValueListMatches([
        boundSingleValue(-65.0, Property.apparentWindAngle, tier: 2),
        boundSingleValue(21.3 / metersPerSecondToKnots, Property.apparentWindSpeed, tier: 2),
      ]),
    );
    expect(
      Nmea0183Parser().parse(_testMsg('VWR', '065,R,,,10.9,M,,')),
      BoundValueListMatches([
        boundSingleValue(65.0, Property.apparentWindAngle, tier: 2),
        boundSingleValue(10.9, Property.apparentWindSpeed, tier: 2),
      ]),
    );
  });

  test('should parse VWT', () {
    expect(
      Nmea0183Parser().parse(_testMsg('VWT', '075,L,24.8,N,,,,')),
      BoundValueListMatches([
        boundSingleValue(-75.0, Property.trueWindAngle, tier: 3),
        boundSingleValue(24.8 / metersPerSecondToKnots, Property.trueWindSpeed, tier: 3),
      ]),
    );
    expect(
      Nmea0183Parser().parse(_testMsg('VWT', '075,R,,,12.8,M,,')),
      BoundValueListMatches([
        boundSingleValue(75.0, Property.trueWindAngle, tier: 3),
        boundSingleValue(12.8, Property.trueWindSpeed, tier: 3),
      ]),
    );
  });

  test('should skip XDR with no known data', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'A,0.0,D,Foo,A,1.00,D,Bar,A,0.25,D,Baz')),
      BoundValueListMatches([]),
    );
  });

  test('should parse XDR with roll pitch yaw in degrees', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'A,-44.75,D,Yaw,A,1.00,D,Pitch,A,0.25,D,Roll')),
      BoundValueListMatches([
        boundSingleValue(-44.75, Property.yaw),
        boundSingleValue(1.0, Property.pitch),
        boundSingleValue(0.25, Property.roll),
      ]),
    );
  });

  test('should parse XDR with roll pitch yaw in radians', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('XDR', 'A,-0.781035,R,Yaw,A,0.017453,R,Pitch,A,0.004363,R,Roll'),
      ),
      BoundValueListMatches([
        boundSingleValue(-44.75, Property.yaw),
        boundSingleValue(1.0, Property.pitch),
        boundSingleValue(0.25, Property.roll),
      ]),
    );
  });

  test('should parse XDR with pressure', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'P,101080,P,Baro')),
      BoundValueListMatches([boundSingleValue(101080.0, Property.pressure, tier: 2)]),
    );
  });

  test('should parse XDR with temperature and RH', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'C,23.6,C,Air,H,57.9,P,Air')),
      BoundValueListMatches([
        boundSingleValue(23.6, Property.airTemperature, tier: 2),
        boundSingleValue(57.9, Property.relativeHumidity, tier: 2),
      ]),
    );
  });

  test('should parse XDR with temperature in Kelvin', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'C,294.750,K,airtemp')),
      BoundValueListMatches([boundSingleValue(21.6, Property.airTemperature, tier: 2)]),
    );
  });

  test('should parse XDR with spelled out air temperature', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'C,15.70,C,TempAir')),
      BoundValueListMatches([boundSingleValue(15.7, Property.airTemperature, tier: 2)]),
    );
  });

  test('should parse XDR with spelled out water and air temperatures', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'C,15.70,C,AirTemp,C,10.1,C,WaterTemp')),
      BoundValueListMatches([
        boundSingleValue(15.7, Property.airTemperature, tier: 2),
        boundSingleValue(10.1, Property.waterTemperature, tier: 2),
      ]),
    );
  });

  test('should parse XDR with spelled out barometer and vague temperature', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'P,1.0282,B,barometer,C,19.7,C,temperature')),
      BoundValueListMatches([boundSingleValue(102820.0, Property.pressure, tier: 2)]),
    );
  });

  test('should parse XDR with engine 1 data', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('XDR', 'P,100300.00,P,ENGINEOIL#0,C,85.0,C,ENGINE#0,U,26.44,V,ALTERNATOR#0'),
      ),
      BoundValueListMatches([
        boundSingleValue(100300.0, Property.engine1OilPressure),
        boundSingleValue(85.0, Property.engine1Temperature),
        boundSingleValue(26.44, Property.alternator1Voltage),
      ]),
    );
  });

  test('should parse XDR with engine 2 data', () {
    expect(
      Nmea0183Parser().parse(
        _testMsg('XDR', 'P,123000.00,P,ENGINEOIL#1,C,95.0,C,ENGINE#1,U,25.00,V,ALTERNATOR#1'),
      ),
      BoundValueListMatches([
        boundSingleValue(123000.0, Property.engine2OilPressure),
        boundSingleValue(95.0, Property.engine2Temperature),
        boundSingleValue(25.0, Property.alternator2Voltage),
      ]),
    );
  });

  test('should parse XDR with engine RPM', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'T,800.0,R,ENGINE#0')),
      BoundValueListMatches([boundSingleValue(800.0, Property.engine1Rpm)]),
    );
  });

  test('should parse XDR with battery voltages', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'U,27.5,V,BATTERY#0,U,26.0,V,BATTERY#1')),
      BoundValueListMatches([
        boundSingleValue(27.5, Property.battery1Voltage),
        boundSingleValue(26.0, Property.battery2Voltage),
      ]),
    );
  });

  test('should parse XDR with fuel level', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'E,50.00,P,FUEL#0')),
      BoundValueListMatches([boundSingleValue(50.0, Property.fuelLevel)]),
    );
  });

  test('should parse XDR with water level', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XDR', 'E,75.00,P,FRESHWATER#0')),
      BoundValueListMatches([boundSingleValue(75.0, Property.water1Level)]),
    );
  });

  test('should parse XTE', () {
    expect(
      Nmea0183Parser().parse(_testMsg('XTE', 'A,A,1.000,R,N,A')),
      BoundValueListMatches([boundSingleValue(1851.9993, Property.crossTrackError)]),
    );
  });

  test('should reject XTE with invalid direction', () {
    expect(() => Nmea0183Parser().parse(_testMsg('XTE', 'A,A,1.000,X,N,A')), throwsFormatException);
  });

  test('should skip empty XTE', () {
    expect(Nmea0183Parser().parse(_testMsg('XTE', 'A,A,,R,N')), BoundValueListMatches([]));
  });

  test('should parse ZDA', () {
    expect(
      Nmea0183Parser().parse(_testMsg('ZDA', '171541.56,15,10,2022,,')),
      BoundValueListMatches([
        boundSingleValue(DateTime.utc(2022, 10, 15, 17, 15, 41), Property.utcTime),
      ]),
    );
  });
}
