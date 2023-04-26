// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/nmea.dart';
import 'package:test/test.dart';

const double _floatTolerance = 0.0001;

class ValueListMatches extends Matcher {
  ValueListMatches(List<Value> expected) : _expected = expected;

  final List<Value> _expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    // TODO: Once I have more time to spend on matcher best practices I'm sure
    // there is a cleaner way to do this. Delegating to matcher for a single
    // value would be a way of breaking it up at least.
    final actual = item as List<Value>;
    if (actual.length != _expected.length) {
      return false;
    }
    for (int i = 0; i < _expected.length; i++) {
      final e = _expected[i];
      final a = actual[i];
      if (a.source != e.source ||
          a.property != e.property ||
          a.tier != e.tier) {
        return false;
      }
      if (e is SingleValue<double>) {
        final a_ = a as SingleValue<double>;
        if ((a_.value - e.value).abs() > _floatTolerance) {
          return false;
        }
      } else if (e is SingleValue<DateTime>) {
        final a_ = a as SingleValue<DateTime>;
        if (a_.value != e.value) {
          return false;
        }
      } else if (e is DoubleValue<double>) {
        final a_ = a as DoubleValue<double>;
        if ((a_.first - e.first).abs() > _floatTolerance ||
            (a.second - e.second).abs() > _floatTolerance) {
          return false;
        }
      } else {
        throw UnimplementedError('No matcher for value type: $e');
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    final formatted = _expected.map((e) => '  ${e.runtimeType}:$e');
    return description.add('Value list matches [\n${formatted.join("\n")}\n]');
  }
}

void main() {
  test('should fail invalid checksum', () {
    expect(() => NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0,*00'),
        throwsFormatException);
  });

  test('should accept missing checksum iff checksum not required', () {
    expect(
        NmeaParser(false).parseString(r'$YDDPT,18.56,-1.61,140.0'),
        ValueListMatches([
          SingleValue<double>(16.95, Source.network, Property.depthWithOffset),
          SingleValue<double>(
              18.56, Source.network, Property.depthUncalibrated),
        ]));
    expect(() => NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0'),
        throwsFormatException);
  });

  test('should skip ignored message', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGSV,5,1,18,65,75,281,19,10,69,352,25,88,65,332,27,87,61,137,15*7C'),
        ValueListMatches([]));
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
        ValueListMatches([
          SingleValue<double>(
              203.71993, Source.network, Property.waypointRange),
          SingleValue<double>(148, Source.network, Property.waypointBearing),
        ]));
  });

  test('should support DBT', () {
    expect(
        NmeaParser(true).parseString(r'$SDDBT,58.10,f,17.71,M,,F*24'),
        ValueListMatches([
          SingleValue<double>(17.71, Source.network, Property.depthUncalibrated,
              tier: 2),
        ]));
  });

  test('should parse DPT', () {
    expect(
        NmeaParser(true).parseString(r'$YDDPT,18.56,-1.61,140.0,*67'),
        ValueListMatches([
          SingleValue<double>(16.95, Source.network, Property.depthWithOffset),
          SingleValue<double>(
              18.56, Source.network, Property.depthUncalibrated),
        ]));
  });

  test('should parse HDG with variation', () {
    expect(
        NmeaParser(true).parseString(r'$YDHDG,7.3,,,13.1,E*08'),
        ValueListMatches([
          SingleValue<double>(-13.1, Source.network, Property.variation),
          SingleValue<double>(20.4, Source.network, Property.heading),
        ]));
  });

  test('should parse HDG without variation', () {
    expect(
        NmeaParser(true).parseString(r'$YDHDG,173.8,,,,*59'),
        ValueListMatches([
          SingleValue<double>(173.8, Source.network, Property.headingMag),
        ]));
  });

  test('should parse HDM', () {
    expect(
        NmeaParser(true).parseString(r'$IIHDM,143.3,M*27'),
        ValueListMatches([
          SingleValue<double>(143.3, Source.network, Property.headingMag,
              tier: 2),
        ]));
  });

  test('should parse GGA with HDOP', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGGA,170202.60,3749.3097,N,12228.9446,W,1,12,0.86,,M,-29.70,M,,*76'),
        ValueListMatches([
          DoubleValue<double>(
              37.82182833, -122.48241, Source.network, Property.gpsPosition),
          SingleValue<double>(0.86, Source.network, Property.gpsHdop),
        ]));
  });

  test('should parse GGA without HDOP', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDGGA,170202.60,3749.3097,N,12228.9446,W,1,12,,,M,-29.70,M,,*66'),
        ValueListMatches([
          DoubleValue<double>(
              37.82183, -122.48241, Source.network, Property.gpsPosition),
        ]));
  });

  test('should parse GLL', () {
    expect(
        NmeaParser(true)
            .parseString(r'$YDGLL,3748.8322,N,12230.6429,W,171453.24,A,A*7A'),
        ValueListMatches([
          DoubleValue<double>(
              37.81387, -122.51072, Source.network, Property.gpsPosition,
              tier: 2),
        ]));
  });

  test('should parse MWV with apparent', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,354.9,R,0.9,M,A*21'),
        ValueListMatches([
          SingleValue<double>(
              354.9, Source.network, Property.apparentWindAngle),
          SingleValue<double>(0.9, Source.network, Property.apparentWindSpeed),
        ]));
  });

  test('should parse MWV with true', () {
    expect(
        NmeaParser(true).parseString(r'$YDMWV,352.5,T,0.6,M,A*22'),
        ValueListMatches([
          SingleValue<double>(
              352.5, Source.network, Property.trueWindDirection),
          SingleValue<double>(0.6, Source.network, Property.trueWindSpeed),
        ]));
  });

  test('should parse RMB', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDRMB,A,0.100,L,0,0,3740.2436,N,12222.6994,W,0.11,148.0,0.0,V,A*4F'),
        ValueListMatches([
          SingleValue<double>(203.71993, Source.network, Property.waypointRange,
              tier: 2),
          SingleValue<double>(148, Source.network, Property.waypointBearing,
              tier: 2),
          SingleValue<double>(
              -185.1999, Source.network, Property.crossTrackError,
              tier: 2),
        ]));
  });

  test('should parse RMC', () {
    expect(
        NmeaParser(true).parseString(
            r'$GPRMC,230830,A,1755.039,N,06443.653,W,5.50,357.0,250803,3.0,W*4B'),
        ValueListMatches([
          DoubleValue<double>(
              17.917317, -64.72755, Source.network, Property.gpsPosition,
              tier: 3),
          SingleValue<DateTime>(DateTime.utc(2003, 08, 25, 23, 08, 30),
              Source.network, Property.utcTime,
              tier: 2),
          SingleValue<double>(2.82945, Source.network, Property.speedOverGround,
              tier: 2),
          SingleValue<double>(357.0, Source.network, Property.courseOverGround,
              tier: 2),
          SingleValue<double>(3.0, Source.network, Property.variation, tier: 2),
        ]));
  });

  test('should parse RSA', () {
    expect(
        NmeaParser(true).parseString(r'$YDRSA,2.8,A,,V*6E'),
        ValueListMatches([
          SingleValue<double>(2.8, Source.network, Property.rudderAngle),
        ]));
  });
  test('should parse VDR', () {
    expect(
        NmeaParser(true).parseString(r'$YDVDR,88.4,T,75.3,M,1.6,N*26'),
        ValueListMatches([
          SingleValue<double>(88.4, Source.network, Property.currentSet),
          SingleValue<double>(0.82311, Source.network, Property.currentDrift),
        ]));
  });
  test('should parse VHW', () {
    expect(
        NmeaParser(true).parseString(r'$YDVHW,339.8,T,326.7,M,1.3,N,2.4,K,*61'),
        ValueListMatches([
          SingleValue<double>(
              0.6667, Source.network, Property.speedThroughWater),
        ]));
  });

  test('should parse VLW', () {
    expect(
        NmeaParser(true).parseString(r'$YDVLW,363.135,N,181.393,N*50'),
        ValueListMatches([
          SingleValue<double>(
              672525.7752, Source.network, Property.distanceTotal),
          SingleValue<double>(
              335939.7137, Source.network, Property.distanceTrip),
        ]));
  });

  test('should parse VTG', () {
    expect(
        NmeaParser(true)
            .parseString(r'$YDVTG,210.9,T,197.8,M,0.6,N,1.2,K,A*21'),
        ValueListMatches([
          SingleValue<double>(210.9, Source.network, Property.courseOverGround),
          SingleValue<double>(
              0.33333, Source.network, Property.speedOverGround),
        ]));
  });

  test('should parse XDR', () {
    expect(
        NmeaParser(true).parseString(
            r'$YDXDR,A,-44.75,D,Yaw,A,1.00,D,Pitch,A,0.25,D,Roll*65'),
        ValueListMatches([
          SingleValue<double>(1.0, Source.network, Property.pitch),
          SingleValue<double>(0.25, Source.network, Property.roll),
        ]));
  });

  test('should parse XTE', () {
    expect(
        NmeaParser(true).parseString(r'$YDXTE,A,A,1.000,R,N,A*26'),
        ValueListMatches([
          SingleValue<double>(
              1851.9993, Source.network, Property.crossTrackError),
        ]));
  });

  test('should parse ZDA', () {
    expect(
        NmeaParser(true).parseString(r'$YDZDA,171541.56,15,10,2022,,*6F'),
        ValueListMatches([
          SingleValue<DateTime>(DateTime.utc(2022, 10, 15, 17, 15, 41),
              Source.network, Property.utcTime),
        ]));
  });
}
