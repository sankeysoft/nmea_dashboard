// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MwdParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 8);
    var ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[0].isNotEmpty) {
      _validateFieldValue(fields, index: 1, expected: 'T');
      ret.add(_parseSingleValue(fields[0], Property.trueWindDirection));
    }
    if (fields[6].isNotEmpty) {
      _validateFieldValue(fields, index: 7, expected: 'M');
      ret.add(_parseSingleValue(fields[6], Property.trueWindSpeed, tier: 2));
    }
    return ret.nonNulls.toList();
  }
}
