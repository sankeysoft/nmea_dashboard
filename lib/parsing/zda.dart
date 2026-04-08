// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class ZdaParser extends SentenceParser {
  @override
  List<BoundValue> parse(List<String> fields) {
    _validateFieldCount(fields, 6);
    if (fields[0].length < 6) {
      throw FormatException('Time field too short: ${fields[0]}');
    }
    final hour = int.parse(fields[0].substring(0, 2));
    final minute = int.parse(fields[0].substring(2, 4));
    final second = int.parse(fields[0].substring(4, 6));
    final day = int.parse(fields[1]);
    final month = int.parse(fields[2]);
    final year = int.parse(fields[3]);
    final dt = DateTime.utc(year, month, day, hour, minute, second);
    return [_boundSingleValue(dt, Property.utcTime)];
  }
}
