// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127258 extends PacketParser {
  @override
  final pgn = 127258;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final value = _scaleIfNotNull(_readInt16(payload, 5), 0.0001 * radiansToDegrees);
    return value == null ? [] : [boundSingleValue(value, Property.variation, tier: 2)];
  }
}
