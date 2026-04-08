// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VtgParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 8);
    _validateFieldValue(fields, index: 1, expected: 'T');
    _validateFieldValue(fields, index: 7, expected: 'K');
    return [
      _parseSingleValue(fields[0], Property.courseOverGround),
      // Need to convert from kmph (sigh).
      _parseSingleValue(fields[6], Property.speedOverGround, divisor: 3.6),
    ].nonNulls.toList();
  }
}
