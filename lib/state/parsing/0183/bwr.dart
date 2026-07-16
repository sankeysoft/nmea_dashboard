// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class BwrParser extends SentenceParser {
  @override
  final type = 'BWR';

  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 12);
    final ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[9].isNotEmpty) {
      _validateFieldValue(fields, index: 10, expected: 'N');
      ret.add(_parseSingleValue(fields[9], Property.waypointRange, divisor: metersToNauticalMiles));
    }
    if (fields[5].isNotEmpty) {
      _validateFieldValue(fields, index: 6, expected: 'T');
      ret.add(_parseSingleValue(fields[5], Property.waypointBearing));
    }
    return ret.nonNulls.toList();
  }
}
