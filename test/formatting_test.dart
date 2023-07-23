// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:test/test.dart';

void main() {
  test('should return no formatters for null dimension', () {
    expect(formattersFor(null), {});
  });

  test('should return at least one formatter for all dimensions', () {
    for (Dimension dimension in Dimension.values) {
      expect(formattersFor(dimension).length, greaterThan(0));
    }
  });

  test('simple formatter should format', () {
    final fmt = SimpleFormatter('test', '', 'invalid', 2.0, 3);
    expect(fmt.format(SingleValue<double>(0.0, Source.local, Property.pitch)),
        equals('0.000'));
    expect(fmt.format(SingleValue<double>(12.3, Source.local, Property.pitch)),
        equals('24.600'));
  });

  test('simple formatter should convert', () {
    final fmt = SimpleFormatter('test', '', 'invalid', 2.0, 3);
    expect(fmt.convert(3.0), equals(6.0));
    expect(fmt.unconvert(6.0), equals(3.0));
  });

  test('angles should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.pitch);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(4.321, 'degrees'), equals('4'));
    expect(format(-234.321, 'degrees'), equals('-234'));
  });

  test('angular rates should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.rateOfTurn);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(4.321, 'degreesPerSec'), equals('4.3'));
    expect(format(-234.321, 'degreesPerSec'), equals('-234.3'));
  });

  test('bearings should be formatted appropriately', () {
    String format(double bearing, double variation, String name) {
      final val = AugmentedBearing(
          SingleValue(bearing, Source.network, Property.heading),
          SingleValue(variation, Source.network, Property.variation));
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(0, 10, 'true'), equals('000T'));
    expect(format(123.4, 10, 'true'), equals('123T'));
    expect(format(123.4, 10, 'mag'), equals('133M'));
    expect(format(359.8, 10, 'mag'), equals('010M'));
    expect(format(5, -10, 'mag'), equals('355M'));
  });

  test('XTE should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.crossTrackError);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(0.0, 'meters'), equals('On Track'));
    expect(format(0.0, 'feet'), equals('On Track'));
    expect(format(10.0, 'meters'), equals('10 m\nSteer Right'));
    expect(format(-10.0, 'meters'), equals('10 m\nSteer Left'));
    expect(format(100, 'feet'), equals('328 ft\nSteer Right'));
  });

  test('distance should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.distanceTrip);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(12345.67, 'km'), equals('12.35'));
    expect(format(12345.67, 'nm'), equals('6.67'));
  });

  // Don't have any integer properties yet but should test them here.

  test('position should be formatted appropriately', () {
    String format(double lat, double long, String name) {
      final val = DoubleValue(lat, long, Source.network, Property.gpsPosition);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(0, 0, 'degMin'), equals("0° 0.000' N\n0° 0.000' E"));
    expect(format(37.251, -122.50, 'degMin'),
        equals("37° 15.060' N\n122° 30.000' W"));
    expect(format(37.251, -122.50, 'degMinSec'),
        equals("37° 15' 3.6\" N\n122° 30' 0.0\" W"));
    expect(format(-45, 60.00, 'degMinSec'),
        equals("45° 0' 0.0\" S\n60° 0' 0.0\" E"));
  });

  test('RH should be formatted appropriately', () {
    String format(double number, String name) {
      final val =
          SingleValue(number, Source.network, Property.relativeHumidity);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(87, 'percent'), equals('87.0'));
  });

  test('pressure should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.pressure);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(101326, 'millibars'), equals('1013.3'));
    expect(format(101326, 'inchHg'), equals('29.92'));
  });

  test('speed should be formatted appropriately', () {
    String format(double number, String name) {
      final val = SingleValue(number, Source.network, Property.speedOverGround);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(5.4321, 'metersPerSec'), equals('5.4'));
    expect(format(5.4321, 'knots'), equals('10.6'));
    expect(format(5.4321, 'knots2dp'), equals('10.56'));
  });

  test('temperature should be formatted appropriately', () {
    String format(double number, String name) {
      final val =
          SingleValue(number, Source.network, Property.waterTemperature);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(format(5.4321, 'celcius'), equals('5.4'));
    expect(format(5.4321, 'farenheit'), equals('41.8'));
    expect(format(-5.91, 'celcius'), equals('-5.9'));
    expect(format(-5.91, 'farenheit'), equals('21.4'));
  });

  test('time should be formatted appropriately', () {
    String format(DateTime datetime, String name) {
      final val = SingleValue(datetime, Source.network, Property.utcTime);
      return formattersFor(val.property.dimension)[name]!.format(val);
    }

    expect(
        format(DateTime.utc(2023, 4, 5, 7, 2, 37), 'hms'), equals('07:02:37'));
    expect(format(DateTime.utc(2023, 4, 5, 7, 2, 37), 'ymdhms'),
        equals('2023-04-05\n07:02:37'));
  });
}
