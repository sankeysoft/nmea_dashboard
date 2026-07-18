// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130314 extends PacketParser {
  @override
  final pgn = 130314;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final pressure = _scaleIfNotNull(_readInt32(payload, 3), 0.1);

    final property = switch (payload.getUint8(2)) {
      (0) => Property.pressure,
      (7) => Property.engine1OilPressure,
      _ => null,
    };

    if (pressure == null || property == null) {
      return [];
    }
    return [boundSingleValue(pressure, property)];
  }
}
