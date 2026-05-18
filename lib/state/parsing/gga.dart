// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class GgaParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 14);
    // Note we do not support messages where the position is missing.
    final lat = _parseLatitude(fields[1], fields[2]);
    final long = _parseLongitude(fields[3], fields[4]);
    final position = _boundDoubleValue(lat, long, Property.gpsPosition);
    final hdop = _parseSingleValue(fields[7], Property.gpsHdop);
    if (hdop == null) {
      return [position];
    } else {
      return [position, hdop];
    }
  }
}
