// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class GllParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 6);
    // Note we do not support messages where the position is missing.
    _validateValidityIndicator(fields, index: 5);
    final lat = _parseLatitude(fields[0], fields[1]);
    final long = _parseLongitude(fields[2], fields[3]);
    return [_boundDoubleValue(lat, long, Property.gpsPosition, tier: 2)];
  }
}
