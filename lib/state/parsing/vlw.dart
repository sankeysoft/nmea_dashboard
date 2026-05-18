// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VlwParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 4);
    final ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[0].isNotEmpty) {
      _validateFieldValue(fields, index: 1, expected: 'N');
      ret.add(_parseSingleValue(fields[0], Property.distanceTotal, divisor: metersToNauticalMiles));
    }
    if (fields[2].isNotEmpty) {
      _validateFieldValue(fields, index: 3, expected: 'N');
      ret.add(_parseSingleValue(fields[2], Property.distanceTrip, divisor: metersToNauticalMiles));
    }
    return ret.nonNulls.toList();
  }
}
