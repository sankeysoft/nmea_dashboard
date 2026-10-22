// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127508 extends PacketParser {
  @override
  final pgn = 127508;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final voltage = _scaleIfNotNull(_readInt16(payload, 1), 0.01);
    final current = _scaleIfNotNull(_readInt16(payload, 3), 0.1);

    final properties = switch (payload.getUint8(0)) {
      (0) => (Property.battery1Voltage, Property.battery1Current),
      (1) => (Property.battery2Voltage, Property.battery2Current),
      _ => null,
    };
    if (properties == null) {
      return [];
    }

    return [
      optionalBoundSingleValue(voltage, properties.$1),
      optionalBoundSingleValue(current, properties.$2),
    ].nonNulls.toList();
  }
}
