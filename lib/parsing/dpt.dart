// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class DptParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateMinFieldCount(fields, 2);
    if (fields[0].isEmpty) {
      return [];
    }
    final depth = double.parse(fields[0]);
    final offset = fields[1].isEmpty ? 0.0 : double.parse(fields[1]);
    return [
      _boundSingleValue(depth + offset, Property.depthWithOffset),
      _boundSingleValue(depth, Property.depthUncalibrated),
    ];
  }
}
