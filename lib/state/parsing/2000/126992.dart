// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser126992 extends PacketParser {
  @override
  final pgn = 126992;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final days = _readUint16(payload, 2);
    final microseconds = _multiplyIfNotNull(_readUint32(payload, 4), 100);

    if (days == null || microseconds == null) {
      return [];
    }
    final dt = DateTime.utc(1970).add(Duration(days: days, microseconds: microseconds));
    return [boundSingleValue(dt, Property.utcTime)];
  }
}
