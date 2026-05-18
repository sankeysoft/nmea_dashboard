// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VdrParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 6);
    _validateFieldValue(fields, index: 1, expected: 'T');
    _validateFieldValue(fields, index: 5, expected: 'N');
    return [
      _parseSingleValue(fields[0], Property.currentSet),
      _parseSingleValue(fields[4], Property.currentDrift, divisor: metersPerSecondToKnots),
    ].nonNulls.toList();
  }
}
