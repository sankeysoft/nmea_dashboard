// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127488 extends PacketParser {
  @override
  final pgn = 127488;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final speed = _scaleIfNotNull(_readUint16(payload, 1), 0.25);

    final property = switch (payload.getUint8(0)) {
      (0) => Property.engine1Rpm,
      (1) => Property.engine2Rpm,
      _ => null,
    };

    if (speed == null || property == null) {
      return [];
    }
    return [boundSingleValue(speed, property)];
  }
}
