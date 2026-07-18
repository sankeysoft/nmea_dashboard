// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127505 extends PacketParser {
  @override
  final pgn = 127505;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final tankType = (payload.getUint8(0) >> 4) & 0x0F;
    final instance = payload.getUint8(0) & 0x0F;
    final level = _scaleIfNotNull(_readInt16(payload, 1), 0.004);

    final property = switch ((tankType, instance)) {
      (0, 0) => Property.fuelLevel,
      (1, 0) => Property.water1Level,
      (1, 1) => Property.water2Level,
      _ => null,
    };

    if (level == null || property == null) {
      return [];
    }
    _validateInRange(level, 0.0, 100.0);
    return [boundSingleValue(level, property)];
  }
}
