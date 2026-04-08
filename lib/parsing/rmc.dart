// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class RmcParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 11);
    _validateValidityIndicator(fields, index: 1);
    final lat = _parseLatitude(fields[2], fields[3]);
    final long = _parseLongitude(fields[4], fields[5]);
    if (fields[0].length < 6) {
      throw FormatException('Time field too short: ${fields[0]}');
    }
    final hour = int.parse(fields[0].substring(0, 2));
    final minute = int.parse(fields[0].substring(2, 4));
    final second = int.parse(fields[0].substring(4, 6));
    if (fields[8].length != 6) {
      throw FormatException('Date field not 6 characters: ${fields[0]}');
    }
    final day = int.parse(fields[8].substring(0, 2));
    final month = int.parse(fields[8].substring(2, 4));
    final year = 2000 + int.parse(fields[8].substring(4, 6));
    final dt = DateTime.utc(year, month, day, hour, minute, second);
    var ret = <BoundValue?>[
      _boundDoubleValue(lat, long, Property.gpsPosition, tier: 3),
      _boundSingleValue(dt, Property.utcTime, tier: 2),
    ];
    ret.add(
      _parseSingleValue(
        fields[6],
        Property.speedOverGround,
        divisor: metersPerSecondToKnots,
        tier: 2,
      ),
    );
    ret.add(_parseSingleValue(fields[7], Property.courseOverGround, tier: 2));
    if (fields[9].isNotEmpty) {
      final variation = _parseVariation(fields[9], fields[10]);
      ret.add(_boundSingleValue(variation, Property.variation, tier: 2));
    }
    return ret.nonNulls.toList();
  }
}
