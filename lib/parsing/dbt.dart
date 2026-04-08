// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class DbtParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 6);
    _validateFieldValue(fields, index: 3, expected: 'M');
    return [_parseSingleValue(fields[2], Property.depthUncalibrated, tier: 2)].nonNulls.toList();
  }
}
