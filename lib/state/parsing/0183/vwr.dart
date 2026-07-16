// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class VwrParser extends SentenceParser {
  @override
  final type = 'VWR';

  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 8);
    final ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[0].isNotEmpty) {
      if (fields[1] == 'L') {
        ret.add(_parseSingleValue("-${fields[0]}", Property.apparentWindAngle, tier: 2));
      } else if (fields[1] == 'R') {
        ret.add(_parseSingleValue(fields[0], Property.apparentWindAngle, tier: 2));
      } else {
        throw FormatException('Invalid wind angle direction $fields[1]');
      }
    }
    if (fields[4].isNotEmpty) {
      _validateFieldValue(fields, index: 5, expected: 'M');
      ret.add(_parseSingleValue(fields[4], Property.apparentWindSpeed, tier: 2));
    } else if (fields[2].isNotEmpty) {
      _validateFieldValue(fields, index: 3, expected: 'N');
      ret.add(
        _parseSingleValue(
          fields[2],
          Property.apparentWindSpeed,
          divisor: metersPerSecondToKnots,
          tier: 2,
        ),
      );
    }
    return ret.nonNulls.toList();
  }
}
