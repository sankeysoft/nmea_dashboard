// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser128259 extends PacketParser {
  @override
  final pgn = 128259;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final stw = _scaleIfNotNull(_readUint16(payload, 1), 0.01);
    final sog = _scaleIfNotNull(_readUint16(payload, 5), 0.01);
    return [
      optionalBoundSingleValue(stw, Property.speedThroughWater),
      optionalBoundSingleValue(sog, Property.speedOverGround),
    ].nonNulls.toList();
  }
}
