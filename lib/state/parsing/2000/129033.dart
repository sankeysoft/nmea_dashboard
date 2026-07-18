// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129033 extends PacketParser {
  @override
  final pgn = 129033;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final days = _readUint16(payload, 0);
    final microseconds = _multiplyIfNotNull(_readUint32(payload, 2), 100);
    if (days == null || microseconds == null) {
      return [];
    }
    return [
      boundSingleValue(
        DateTime.utc(1970).add(Duration(days: days, microseconds: microseconds)),
        Property.utcTime,
        tier: 2,
      ),
    ];
  }
}
