// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class RsaParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 4);
    _validateValidityIndicator(fields, index: 1);
    return [_parseSingleValue(fields[0], Property.rudderAngle)].nonNulls.toList();
  }
}
