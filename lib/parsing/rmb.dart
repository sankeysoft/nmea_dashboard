// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class RmbParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 13);
    _validateValidityIndicator(fields, index: 0);

    final ret = <BoundValue<SingleValue<double>>?>[];
    if (fields[9].isNotEmpty) {
      final range = double.parse(fields[9]) / metersToNauticalMiles;
      ret.add(_boundSingleValue(range, Property.waypointRange, tier: 2));
    }
    if (fields[10].isNotEmpty) {
      ret.add(_parseSingleValue(fields[10], Property.waypointBearing, tier: 2));
    }
    if (fields[1].isNotEmpty) {
      final xte = _parseCrossTrackError(fields[1], fields[2]);
      ret.add(_boundSingleValue(xte, Property.crossTrackError, tier: 2));
    }
    return ret.nonNulls.toList();
  }
}
