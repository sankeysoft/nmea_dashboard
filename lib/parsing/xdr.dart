// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

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
    final transducer = fields[startIndex];
    String name = fields[startIndex + 3].toLowerCase();
    String? number;
    if (name.length > 2 && name[name.length - 2] == "#") {
      number = name[name.length - 1];
      name = name.substring(0, name.length - 2);
    }

    Property propByNumber(List<Property> options) {
      for (final (index, value) in options.indexed) {
        if (number == index.toString()) return value;
      }
      throw FormatException('Unknown sensor number: $number');
    }

    switch ('$transducer-$name') {
      case 'A-pitch':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'D');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.pitch)];
      case 'A-roll':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'D');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.roll)];
      case 'A-yaw':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'D');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.yaw)];
      case 'C-air':
      case 'C-tempair':
      case 'C-airtemp':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'C');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.airTemperature, tier: 2)];
      case 'C-water':
      case 'C-tempwater':
      case 'C-watertemp':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'C');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.waterTemperature, tier: 2)];
      case 'C-engine':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'C');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.engine1Temperature, Property.engine2Temperature]);
        return [_boundSingleValue(value, prop)];
      case 'E-fuel':
      case 'V-fuel':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'P');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.fuelLevel)];
      case 'E-freshwater':
      case 'V-freshwater':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'P');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.water1Level, Property.water2Level]);
        return [_boundSingleValue(value, prop)];
      case 'H-air':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'P');
        final value = double.parse(fields[startIndex + 1]);
        return [_boundSingleValue(value, Property.relativeHumidity, tier: 2)];
      case 'P-baro':
      case 'P-barometer':
        final dataType = fields[startIndex + 2];
        var value = double.parse(fields[startIndex + 1]);
        if (dataType == 'P') {
          // Already in pascals
        } else if (dataType == 'B') {
          value *= barToPascals;
        } else {
          throw FormatException('Invalid pressure datatype: $dataType');
        }
        return [_boundSingleValue(value, Property.pressure, tier: 2)];
      case 'P-engineoil':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'P');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.engine1OilPressure, Property.engine2OilPressure]);
        return [_boundSingleValue(value, prop)];
      case 'T-engine':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'R');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.engine1Rpm, Property.engine2Rpm]);
        return [_boundSingleValue(value, prop)];
      case 'U-alternator':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'V');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.alternator1Voltage, Property.alternator2Voltage]);
        return [_boundSingleValue(value, prop)];
      case 'U-battery':
        _validateFieldValue(fields, index: startIndex + 2, expected: 'V');
        final value = double.parse(fields[startIndex + 1]);
        final prop = propByNumber([Property.battery1Voltage, Property.battery2Voltage]);
        return [_boundSingleValue(value, prop)];
      default:
        return [];
    }
  }
}
