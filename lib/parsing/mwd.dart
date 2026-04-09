// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MwdParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCounts(fields, [6, 8]);
    var ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[0].isNotEmpty) {
      _validateFieldValue(fields, index: 1, expected: 'T');
      ret.add(_parseSingleValue(fields[0], Property.trueWindDirection));
    }
    // Expect speed in m/s to be at index 6 if that exists, but also accept malformed PW DataHub
    // messages that don't send the full sentence and put m/s in index 4.
    if (fields.length >= 8 && fields[6].isNotEmpty) {
      _validateFieldValue(fields, index: 7, expected: 'M');
      ret.add(_parseSingleValue(fields[6], Property.trueWindSpeed, tier: 2));
    } else if (fields[4].isNotEmpty) {
      _validateFieldValue(fields, index: 5, expected: 'M');
      ret.add(_parseSingleValue(fields[4], Property.trueWindSpeed, tier: 2));
    }
    return ret.nonNulls.toList();
  }
}
