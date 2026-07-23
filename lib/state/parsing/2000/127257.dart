// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127257 extends PacketParser {
  @override
  final pgn = 127257;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final roll = _scaleIfNotNull(_readInt16(payload, 1), 0.0001 * radiansToDegrees);
    final pitch = _scaleIfNotNull(_readInt16(payload, 3), 0.0001 * radiansToDegrees);
    final yaw = _scaleIfNotNull(_readInt16(payload, 5), 0.0001 * radiansToDegrees);

    return [
      optionalBoundSingleValue(roll, Property.roll, tier: 1),
      optionalBoundSingleValue(pitch, Property.pitch, tier: 1),
      optionalBoundSingleValue(yaw, Property.yaw, tier: 1),
    ].nonNulls.toList();
  }
}
