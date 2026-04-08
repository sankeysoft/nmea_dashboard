// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VlwParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 4);
    _validateFieldValue(fields, index: 1, expected: 'N');
    _validateFieldValue(fields, index: 3, expected: 'N');
    return [
      _parseSingleValue(fields[0], Property.distanceTotal, divisor: metersToNauticalMiles),
      _parseSingleValue(fields[2], Property.distanceTrip, divisor: metersToNauticalMiles),
    ].nonNulls.toList();
  }
}
