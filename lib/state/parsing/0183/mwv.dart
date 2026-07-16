// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MwvParser extends SentenceParser {
  @override
  final type = 'MWV';

  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 5);
    _validateValidityIndicator(fields, index: 4);
    final ret = <BoundValue<SingleValue<double>>?>[];
    final relative = (fields[1] == 'R');
    if (fields[0].isNotEmpty) {
      final prop = relative ? Property.apparentWindAngle : Property.trueWindAngle;
      ret.add(_parseSingleValue(fields[0], prop));
    }
    if (fields[2].isNotEmpty) {
      final divisor = switch (fields[3]) {
        'N' => metersPerSecondToKnots,
        'K' => metersPerSecondToKmph,
        _ => 1.0,
      };
      final prop = relative ? Property.apparentWindSpeed : Property.trueWindSpeed;
      ret.add(_parseSingleValue(fields[2], prop, divisor: divisor));
    }
    return ret.nonNulls.toList();
  }
}
