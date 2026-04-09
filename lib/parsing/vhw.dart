// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VhwParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    BoundValue<SingleValue<double>>? ret;
    _validateMinFieldCount(fields, 8);
    // Prefer kmph speed from index 6 if populated, fall back to knots from 4 if not.
    if (fields[6].isNotEmpty) {
      _validateFieldValue(fields, index: 7, expected: 'K');
      ret = _parseSingleValue(
        fields[6],
        Property.speedThroughWater,
        divisor: metersPerSecondToKmph,
      );
    } else {
      _validateFieldValue(fields, index: 5, expected: 'N');
      ret = _parseSingleValue(
        fields[4],
        Property.speedThroughWater,
        divisor: metersPerSecondToKnots,
      );
    }
    return [ret].nonNulls.toList();
  }
}
