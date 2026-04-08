// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class BwrParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 12);
    _validateFieldValue(fields, index: 6, expected: 'T');
    _validateFieldValue(fields, index: 10, expected: 'N');
    return [
      _parseSingleValue(fields[9], Property.waypointRange, divisor: metersToNauticalMiles),
      _parseSingleValue(fields[5], Property.waypointBearing),
    ].nonNulls.toList();
  }
}
