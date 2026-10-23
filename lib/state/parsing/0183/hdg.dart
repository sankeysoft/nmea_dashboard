// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class HdgParser extends SentenceParser {
  @override
  final type = 'HDG';

  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 5);
    var ret = <BoundValue<SingleValue<double>>>[];
    double? variation;
    if (fields[3].isNotEmpty) {
      variation = _parseEastWest(fields[3], fields[4], 'Variation');
      ret.add(boundSingleValue(variation, Property.variation));
    }
    if (fields[0].isNotEmpty) {
      // Subtract any deviation from sensor heading to get magnetic heading.
      final deviation = fields[1].isEmpty ? 0.0 : _parseEastWest(fields[1], fields[2], 'Deviation');
      final magHdg = (double.parse(fields[0]) + deviation) % 360.0;
      if (variation == null) {
        ret.add(boundSingleValue(magHdg, Property.headingMag));
      } else {
        final trueHdg = (magHdg + variation) % 360.0;
        ret.add(boundSingleValue(trueHdg, Property.heading));
      }
    }
    return ret;
  }
}
