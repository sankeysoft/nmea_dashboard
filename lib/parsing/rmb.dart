// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class RmbParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 13);
    _validateValidityIndicator(fields, index: 0);
    // Note we don't support messages that are marked valid but missing data.
    final range = double.parse(fields[9]) / metersToNauticalMiles;
    final bearing = double.parse(fields[10]);
    final xte = _parseCrossTrackError(fields[1], fields[2]);
    return [
      _boundSingleValue(range, Property.waypointRange, tier: 2),
      _boundSingleValue(bearing, Property.waypointBearing, tier: 2),
      _boundSingleValue(xte, Property.crossTrackError, tier: 2),
    ];
  }
}
