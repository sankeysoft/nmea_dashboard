// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130577 extends PacketParser {
  @override
  final pgn = 130577;

  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 14);
    final reference = payload.getUint8(1);

    final cog = _scaleIfNotNull(_readUint16(payload, 2), 0.0001 * radiansToDegrees);
    final sog = _scaleIfNotNull(_readUint16(payload, 4), 0.01);
    final heading = _scaleIfNotNull(_readUint16(payload, 6), 0.0001 * radiansToDegrees);
    final stw = _scaleIfNotNull(_readUint16(payload, 8), 0.01);
    final set = _scaleIfNotNull(_readUint16(payload, 10), 0.0001 * radiansToDegrees);
    final drift = _scaleIfNotNull(_readUint16(payload, 12), 0.01);

    final values = [
      optionalBoundSingleValue(sog, Property.speedOverGround, tier: 3),
      optionalBoundSingleValue(stw, Property.speedThroughWater, tier: 2),
      optionalBoundSingleValue(drift, Property.currentDrift, tier: 2),
    ];
    // Assume cog, heading and set are all tied to the same reference; this isn't very clear on
    // the CANBoat documentation. Only use directional data if reference==true.
    if (reference & 0x0C == 0) {
      values.add(optionalBoundSingleValue(cog, Property.courseOverGround, tier: 2));
      values.add(optionalBoundSingleValue(heading, Property.heading, tier: 2));
      values.add(optionalBoundSingleValue(set, Property.currentSet, tier: 2));
    }
    return values.nonNulls.toList();
  }
}
