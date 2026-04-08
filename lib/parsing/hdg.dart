// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class HdgParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 5);
    // TODO: Currently we support mag-only but not true-only. Consider
    //       supporting mag heading being missing if this ever arises.
    final magHdg = double.parse(fields[0]);
    if (fields[3].isEmpty) {
      // Support equipment which does not know variation.
      return [_boundSingleValue(magHdg, Property.headingMag)];
    }
    final variation = _parseVariation(fields[3], fields[4]);
    final trueHdg = (magHdg - variation) % 360.0;
    return [
      _boundSingleValue(variation, Property.variation),
      _boundSingleValue(trueHdg, Property.heading),
    ];
  }
}
