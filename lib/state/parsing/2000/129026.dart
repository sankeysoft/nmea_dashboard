// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129026 extends PacketParser {
  @override
  final pgn = 129026;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final reference = payload.getUint8(1) & 0x03;
    final cog = _scaleIfNotNull(_readUint16(payload, 2), 0.0001 * radiansToDegrees);
    final sog = _scaleIfNotNull(_readUint16(payload, 4), 0.01);

    final values = <BoundValue>[];
    // Only process COG when reported as true.
    if (cog != null && reference == 0) {
      values.add(boundSingleValue(cog, Property.courseOverGround));
    }
    if (sog != null) {
      values.add(boundSingleValue(sog, Property.speedOverGround));
    }
    return values;
  }
}
