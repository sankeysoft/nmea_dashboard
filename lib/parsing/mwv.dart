// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class MwvParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 5);
    _validateValidityIndicator(fields, index: 4);
    final relative = (fields[1] == 'R');
    final angle = double.parse(fields[0]);
    final divisor = switch (fields[3]) {
      'N' => metersPerSecondToKnots,
      'K' => metersPerSecondToKmph,
      _ => 1.0,
    };
    final speed = double.parse(fields[2]) / divisor;
    return [
      _boundSingleValue(angle, relative ? Property.apparentWindAngle : Property.trueWindAngle),
      _boundSingleValue(speed, relative ? Property.apparentWindSpeed : Property.trueWindSpeed),
    ];
  }
}
