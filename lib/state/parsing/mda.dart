// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MdaParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 20);
    var ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[2].isNotEmpty) {
      _validateFieldValue(fields, index: 3, expected: 'B');
      ret.add(_parseSingleValue(fields[2], Property.pressure, divisor: 1 / barToPascals));
    }
    if (fields[4].isNotEmpty) {
      _validateFieldValue(fields, index: 5, expected: 'C');
      ret.add(_parseSingleValue(fields[4], Property.airTemperature));
    }
    if (fields[6].isNotEmpty) {
      _validateFieldValue(fields, index: 7, expected: 'C');
      ret.add(_parseSingleValue(fields[6], Property.waterTemperature));
    }
    if (fields[8].isNotEmpty) {
      ret.add(_parseSingleValue(fields[8], Property.relativeHumidity));
    }
    if (fields[10].isNotEmpty) {
      _validateFieldValue(fields, index: 11, expected: 'C');
      ret.add(_parseSingleValue(fields[10], Property.dewPoint));
    }
    if (fields[12].isNotEmpty) {
      _validateFieldValue(fields, index: 13, expected: 'T');
      ret.add(_parseSingleValue(fields[12], Property.trueWindDirection, tier: 2));
    }
    return ret.nonNulls.toList();
  }
}
