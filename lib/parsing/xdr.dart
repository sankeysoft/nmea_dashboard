// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

// The supported units for a transducer, with conversion back to standard units for its type.
enum Units {
  degrees('D', null, null),
  radians('R', null, 180 / math.pi),
  celcius('C', null, null),
  kelvin('K', -273.15, null),
  percentage('P', null, null),
  pascals('P', null, null),
  bar('B', null, barToPascals),
  rpm('R', null, null),
  voltage('V', null, null);

  final String abbreviation;
  final double? _offset;
  final double? _scale;

  const Units(this.abbreviation, this._offset, this._scale);

  double convert(double value) {
    if (_offset != null) {
      value += _offset;
    }
    if (_scale != null) {
      value *= _scale;
    }
    return value;
  }
}

class XdrParser extends SentenceParser {
  @override
  List<BoundValue<Value>> parse(List<String> fields) {
    _validateMinFieldCount(fields, 4);
    final List<BoundValue> values = [];
    for (int i = 0; i < fields.length - 3; i += 4) {
      values.addAll(XdrParser._parseMeasurement(fields, i));
    }
    return values;
  }

  /// Parses a single transducer measurement, ignoring unknown properties.
  static List<BoundValue> _parseMeasurement(List<String> fields, int startIndex) {
    final type = fields[startIndex];
    final value = double.parse(fields[startIndex + 1]);
    String units = fields[startIndex + 2];
    String name = fields[startIndex + 3].toLowerCase();
    String? number;
    if (name.length > 2 && name[name.length - 2] == "#") {
      number = name[name.length - 1];
      name = name.substring(0, name.length - 2);
    }

    double convertValue(List<Units> allowedUnits) {
      for (final allowedUnit in allowedUnits) {
        if (units == allowedUnit.abbreviation) {
          return allowedUnit.convert(value);
        }
      }
      throw FormatException('Invalid units $units for $name, expected one of $allowedUnits');
    }

    Property propByNumber(List<Property> options) {
      for (final (index, value) in options.indexed) {
        if (number == index.toString()) return value;
      }
      throw FormatException('Unknown sensor number: $number');
    }

    switch ('$type-$name') {
      case 'A-pitch':
        final value = convertValue([Units.degrees, Units.radians]);
        return [_boundSingleValue(value, Property.pitch)];
      case 'A-roll':
        final value = convertValue([Units.degrees, Units.radians]);
        return [_boundSingleValue(value, Property.roll)];
      case 'A-yaw':
        final value = convertValue([Units.degrees, Units.radians]);
        return [_boundSingleValue(value, Property.yaw)];
      case 'C-air':
      case 'C-tempair':
      case 'C-airtemp':
        final value = convertValue([Units.celcius, Units.kelvin]);
        return [_boundSingleValue(value, Property.airTemperature, tier: 2)];
      case 'C-water':
      case 'C-tempwater':
      case 'C-watertemp':
        final value = convertValue([Units.celcius, Units.kelvin]);
        return [_boundSingleValue(value, Property.waterTemperature, tier: 2)];
      case 'C-engine':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'C');
        final value = convertValue([Units.celcius, Units.kelvin]);
        final prop = propByNumber([Property.engine1Temperature, Property.engine2Temperature]);
        return [_boundSingleValue(value, prop)];
      case 'E-fuel':
      case 'V-fuel':
        final value = convertValue([Units.percentage]);
        return [_boundSingleValue(value, Property.fuelLevel)];
      case 'E-freshwater':
      case 'V-freshwater':
        final value = convertValue([Units.percentage]);
        final prop = propByNumber([Property.water1Level, Property.water2Level]);
        return [_boundSingleValue(value, prop)];
      case 'H-air':
        final value = convertValue([Units.percentage]);
        return [_boundSingleValue(value, Property.relativeHumidity, tier: 2)];
      case 'P-baro':
      case 'P-barometer':
        final value = convertValue([Units.pascals, Units.bar]);
        return [_boundSingleValue(value, Property.pressure, tier: 2)];
      case 'P-engineoil':
        final value = convertValue([Units.pascals, Units.bar]);
        final prop = propByNumber([Property.engine1OilPressure, Property.engine2OilPressure]);
        return [_boundSingleValue(value, prop)];
      case 'T-engine':
        final value = convertValue([Units.rpm]);
        final prop = propByNumber([Property.engine1Rpm, Property.engine2Rpm]);
        return [_boundSingleValue(value, prop)];
      case 'U-alternator':
        final value = convertValue([Units.voltage]);
        final prop = propByNumber([Property.alternator1Voltage, Property.alternator2Voltage]);
        return [_boundSingleValue(value, prop)];
      case 'U-battery':
        final value = convertValue([Units.voltage]);
        final prop = propByNumber([Property.battery1Voltage, Property.battery2Voltage]);
        return [_boundSingleValue(value, prop)];
      default:
        return [];
    }
  }
}
