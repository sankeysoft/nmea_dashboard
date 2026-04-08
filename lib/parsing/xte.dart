// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class XteParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 5);
    _validateValidityIndicator(fields, index: 0);
    _validateValidityIndicator(fields, index: 1);
    _validateFieldValue(fields, index: 4, expected: 'N');
    final xte = _parseCrossTrackError(fields[2], fields[3]);
    return [_boundSingleValue(xte, Property.crossTrackError)];
  }
}
