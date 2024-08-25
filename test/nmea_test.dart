// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/nmea.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

BoundValue<SingleValue<T>> _boundSingleValue<T>(T data, Property property,
    {int tier = 1}) {
  return BoundValue(Source.network, property, SingleValue(data), tier: tier);
}

BoundValue<DoubleValue<T>> _boundDoubleValue<T>(
    T first, T second, Property property,
    {int tier = 1}) {
  return BoundValue(Source.network, property, DoubleValue(first, second),
      tier: tier);
}

void main() {
  test('should fail invalid checksum', () {
    expect(() => NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0,*00'),
        throwsFormatException);
  });

  test('should accept missing checksum iff checksum not required', () {
    expect(
        NmeaParser(false).parseString(r'$YDDPT,18.56,-1.61,140.0'),
        BoundValueListMatches([
          _boundSingleValue(16.95, Property.depthWithOffset),
          _boundSingleValue(18.56, Property.depthUncalibrated),
        ]));
    expect(() => NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0'),
        throwsFormatException);
  });

  test('should skip ignored message', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGSV,5,1,18,65,75,281,19,10,69,352,25,88,65,332,27,87,61,137,15*7C'),
        BoundValueListMatches([]));
  });

  test('should increment message counts', () {
    final parser = NmeaParser(true);
    expect(parser.ignoredCounts.total, 0);
    expect(parser.unsupportedCounts.total, 0);
    expect(parser.successCounts.total, 0);
    parser.parseString(r'$YDDPT,18.56,-1.61,140.0,*67');
    expect(parser.successCounts.total, 1);
    parser.parseString(
        r'$YDGSV,5,1,18,65,75,281,19,10,69,352,25,88,65,332,27,87,61,137,15*7C');
    expect(parser.ignoredCounts.total, 1);
    parser.logAndClearCounts();
    expect(parser.ignoredCounts.total, 0);
    expect(parser.successCounts.total, 0);
  });

  test('should parse BWR', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDBWR,203514.60,3740.2436,N,12222.6994,W,148.0,T,134.9,M,0.11,N,0,A*4C'),
        BoundValueListMatches([
          _boundSingleValue(203.71993, Property.waypointRange),
          _boundSingleValue(148.0, Property.waypointBearing),
        ]));
  });

  test('should support DBT', () {
    expect(
        NmeaParser(true).parseString(r'$SDDBT,58.10,f,17.71,M,,F*24'),
        BoundValueListMatches([
          _boundSingleValue(17.71, Property.depthUncalibrated, tier: 2),
        ]));
  });

  test('should parse DPT', () {
    expect(
        NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0,*67'),
        BoundValueListMatches([
          _boundSingleValue(16.95, Property.depthWithOffset),
          _boundSingleValue(18.56, Property.depthUncalibrated),
        ]));
  });

  test('should parse DPT without data', () {
    final parser = NmeaParser(true);
    expect(() => parser.parseString(r'$IIDPT,,0.0*6E'), throwsFormatException);
    expect(parser.emptyCounts.total, 1);
    expect(parser.parseString(r'$IIDPT,,0.0*6E'), BoundValueListMatches([]));
    expect(parser.emptyCounts.total, 2);
  });

  test('should parse HDG with variation', () {
    expect(
        NmeaParser(true).parseString(r'$YDHDG,7.3,,,13.1,E*08'),
        BoundValueListMatches([
          _boundSingleValue(-13.1, Property.variation),
          _boundSingleValue(20.4, Property.heading),
        ]));
  });

  test('should parse HDG without variation', () {
    expect(
        NmeaParser(true).parseString(r'$YDHDG,173.8,,,,*59'),
        BoundValueListMatches([
          _boundSingleValue(173.8, Property.headingMag),
        ]));
  });

  test('should parse HDM', () {
    expect(
        NmeaParser(true).parseString(r'$IIHDM,143.3,M*27'),
        BoundValueListMatches([
          _boundSingleValue(143.3, Property.headingMag, tier: 2),
        ]));
  });

  test('should parse GGA with HDOP', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGGA,170202.60,3749.3097,N,12228.9446,W,1,12,0.86,,M,-29.70,M,,*76'),
        BoundValueListMatches([
          _boundDoubleValue(37.82182833, -122.48241, Property.gpsPosition),
          _boundSingleValue(0.86, Property.gpsHdop),
        ]));
  });

  test('should parse GGA without HDOP', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGGA,170202.60,3749.3097,N,12228.9446,W,1,12,,,M,-29.70,M,,*66'),
        BoundValueListMatches([
          _boundDoubleValue(37.82183, -122.48241, Property.gpsPosition),
        ]));
  });

  test('should parse GLL', () {
    expect(
        NmeaParser(true)
            .parseString(r'$YDGLL,3748.8322,N,12230.6429,W,171453.24,A,A*7A'),
        BoundValueListMatches([
          _boundDoubleValue(37.81387, -122.51072, Property.gpsPosition,
              tier: 2),
        ]));
  });

  test('should parse MDA with temp and RH', () {
    expect(
        NmeaParser(true)
            .parseString(r'$YDMDA,,I,,B,23.9,C,,C,55.5,,14.4,C,,T,,M,,N,,M*15'),
        BoundValueListMatches([
          _boundSingleValue(23.9, Property.airTemperature),
          _boundSingleValue(55.5, Property.relativeHumidity),
          _boundSingleValue(14.4, Property.dewPoint)
        ]));
  });

  test('should parse MDA with pressure', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDMDA,29.8902,I,1.0122,B,,C,,C,,,,C,,T,,M,,N,,M*3F'),
        BoundValueListMatches([
          _boundSingleValue(101220.0, Property.pressure),
        ]));
  });

  test('should parse MDA with pressure, water temp, and TWD', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDMDA,30.1767,I,1.0219,B,,C,20.4,C,,,,C,315.6,T,302.6,M,9.3,N,4.8,M*20'),
        BoundValueListMatches([
          _boundSingleValue(102190.0, Property.pressure),
          _boundSingleValue(20.4, Property.waterTemperature),
          _boundSingleValue(315.6, Property.trueWindDirection, tier: 2)
        ]));
  });

  test('should parse MWD with direction', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWD,154.7,T,141.8,M,12.1,N,6.2,M*64'),
        BoundValueListMatches([
          _boundSingleValue(154.7, Property.trueWindDirection),
          _boundSingleValue(6.2, Property.trueWindSpeed, tier: 2),
        ]));
  });

  test('should parse MWD with missing direction', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWD,,T,,M,12.1,N,6.2,M*6F'),
        BoundValueListMatches([
          _boundSingleValue(6.2, Property.trueWindSpeed, tier: 2),
        ]));
  });

  test('should parse MWV with apparent in m/s', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,354.9,R,0.9,M,A*21'),
        BoundValueListMatches([
          _boundSingleValue(354.9, Property.apparentWindAngle),
          _boundSingleValue(0.9, Property.apparentWindSpeed),
        ]));
  });

  test('should parse MWV with apparent in kmph', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,354.9,R,3.24,K,A*1B'),
        BoundValueListMatches([
          _boundSingleValue(354.9, Property.apparentWindAngle),
          _boundSingleValue(0.9, Property.apparentWindSpeed),
        ]));
  });

  test('should parse MWV with true in m/s', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,352.5,T,0.6,M,A*22'),
        BoundValueListMatches([
          _boundSingleValue(352.5, Property.trueWindAngle),
          _boundSingleValue(0.6, Property.trueWindSpeed),
        ]));
  });

  test('should parse MWV with true in knots', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,352.5,T,20.0,N,A*15'),
        BoundValueListMatches([
          _boundSingleValue(352.5, Property.trueWindAngle),
          _boundSingleValue(10.28891, Property.trueWindSpeed),
        ]));
  });

  test('should parse MTW', () {
    expect(
        NmeaParser(true).parseString(r'$YDMTW,20.4,C*08'),
        BoundValueListMatches([
          _boundSingleValue(20.4, Property.waterTemperature, tier: 2),
        ]));
  });

  test('should parse RMB', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDRMB,A,0.100,L,0,0,3740.2436,N,12222.6994,W,0.11,148.0,0.0,V,A*4F'),
        BoundValueListMatches([
          _boundSingleValue(203.71993, Property.waypointRange, tier: 2),
          _boundSingleValue(148.0, Property.waypointBearing, tier: 2),
          _boundSingleValue(-185.1999, Property.crossTrackError, tier: 2),
        ]));
  });

  test('should parse RMC', () {
    expect(
        NmeaParser(true).parseString(
            r'$GPRMC,230830,A,1755.039,N,06443.653,W,5.50,357.0,250803,3.0,W*4B'),
        BoundValueListMatches([
          _boundDoubleValue(17.917317, -64.72755, Property.gpsPosition,
              tier: 3),
          _boundSingleValue(
              DateTime.utc(2003, 08, 25, 23, 08, 30), Property.utcTime,
              tier: 2),
          _boundSingleValue(2.82945, Property.speedOverGround, tier: 2),
          _boundSingleValue(357.0, Property.courseOverGround, tier: 2),
          _boundSingleValue(3.0, Property.variation, tier: 2),
        ]));
  });

  test('should parse RSA', () {
    expect(
        NmeaParser(true).parseString(r'$YDRSA,2.8,A,,V*6E'),
        BoundValueListMatches([
          _boundSingleValue(2.8, Property.rudderAngle),
        ]));
  });
  test('should parse VDR', () {
    expect(
        NmeaParser(true).parseString(r'$YDVDR,88.4,T,75.3,M,1.6,N*26'),
        BoundValueListMatches([
          _boundSingleValue(88.4, Property.currentSet),
          _boundSingleValue(0.82311, Property.currentDrift),
        ]));
  });
  test('should parse VHW', () {
    expect(
        NmeaParser(true).parseString(r'$YDVHW,339.8,T,326.7,M,1.3,N,2.4,K,*61'),
        BoundValueListMatches([
          _boundSingleValue(0.6667, Property.speedThroughWater),
        ]));
  });

  test('should parse VHW without data', () {
    final parser = NmeaParser(true);
    expect(() => parser.parseString(r'$VWVHW,,T,,M,,N,,K*54'),
        throwsFormatException);
    expect(parser.emptyCounts.total, 1);
    expect(parser.parseString(r'$VWVHW,,T,,M,,N,,K*54'),
        BoundValueListMatches([]));
    expect(parser.emptyCounts.total, 2);
  });

  test('should parse VLW', () {
    expect(
        NmeaParser(true).parseString(r'$YDVLW,363.135,N,181.393,N*50'),
        BoundValueListMatches([
          _boundSingleValue(672525.7752, Property.distanceTotal),
          _boundSingleValue(335939.7137, Property.distanceTrip),
        ]));
  });

  test('should parse VTG', () {
    expect(
        NmeaParser(true)
            .parseString(r'$YDVTG,210.9,T,197.8,M,0.6,N,1.2,K,A*21'),
        BoundValueListMatches([
          _boundSingleValue(210.9, Property.courseOverGround),
          _boundSingleValue(0.33333, Property.speedOverGround),
        ]));
  });

  test('should parse XDR with roll pitch yaw', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDXDR,A,-44.75,D,Yaw,A,1.00,D,Pitch,A,0.25,D,Roll*65'),
        BoundValueListMatches([
          _boundSingleValue(1.0, Property.pitch),
          _boundSingleValue(0.25, Property.roll),
        ]));
  });

  test('should parse XDR with pressure', () {
    expect(
        NmeaParser(true).parseString(r'$YDXDR,P,101080,P,Baro*65'),
        BoundValueListMatches([
          _boundSingleValue(101080.0, Property.pressure, tier: 2),
        ]));
  });

  test('should parse XDR with temperature and RH', () {
    expect(
        NmeaParser(true).parseString(r'$YDXDR,C,23.6,C,Air,H,57.9,P,Air*47'),
        BoundValueListMatches([
          _boundSingleValue(23.6, Property.airTemperature, tier: 2),
          _boundSingleValue(57.9, Property.relativeHumidity, tier: 2),
        ]));
  });

  test('should parse XDR with spelled out air temperature', () {
    expect(
        NmeaParser(true).parseString(r'$IIXDR,C,15.70,C,TempAir*15'),
        BoundValueListMatches([
          _boundSingleValue(15.7, Property.airTemperature, tier: 2),
        ]));
  });

  test('should parse XDR with spelled out water and air temperatures', () {
    expect(
        NmeaParser(true)
            .parseString(r'$IIXDR,C,15.70,C,AirTemp,C,10.1,C,WaterTemp*72'),
        BoundValueListMatches([
          _boundSingleValue(15.7, Property.airTemperature, tier: 2),
          _boundSingleValue(10.1, Property.waterTemperature, tier: 2),
        ]));
  });

  test('should parse XDR with spelled out barometer and vague temperature', () {
    expect(
        NmeaParser(true).parseString(
            r'$WIXDR,P,1.0282,B,barometer,C,19.7,C,temperature*5D'),
        BoundValueListMatches([
          _boundSingleValue(102820.0, Property.pressure, tier: 2),
        ]));
  });

  test('should parse XTE', () {
    expect(
        NmeaParser(true).parseString(r'$YDXTE,A,A,1.000,R,N,A*26'),
        BoundValueListMatches([
          _boundSingleValue(1851.9993, Property.crossTrackError),
        ]));
  });

  test('should parse ZDA', () {
    expect(
        NmeaParser(true).parseString(r'$YDZDA,171541.56,15,10,2022,,*6F'),
        BoundValueListMatches([
          _boundSingleValue(
              DateTime.utc(2022, 10, 15, 17, 15, 41), Property.utcTime),
        ]));
  });
}
