// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MtwParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 2);
    _validateFieldValue(fields, index: 1, expected: 'C');
    return [_parseSingleValue(fields[0], Property.waterTemperature, tier: 2)].nonNulls.toList();
  }
}
