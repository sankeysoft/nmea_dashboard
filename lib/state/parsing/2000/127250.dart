// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127250 extends PacketParser {
  @override
  final pgn = 127250;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final heading = _scaleIfNotNull(_readUint16(payload, 1), 0.0001 * radiansToDegrees);
    final variation = _scaleIfNotNull(_readInt16(payload, 5), 0.0001 * radiansToDegrees);
    final reference = payload.getUint8(7) & 0x03;

    final values = <BoundValue>[];
    if (variation != null) {
      values.add(boundSingleValue(variation, Property.variation));
    }
    if (heading != null) {
      if (reference == 0) {
        values.add(boundSingleValue(heading, Property.heading));
      } else if (reference == 1) {
        // Prefer to output in true when we have variation. Only use mag if we can't use true.
        if (variation != null) {
          final trueHdg = (heading - variation) % 360.0;
          values.add(boundSingleValue(trueHdg, Property.heading));
        } else {
          values.add(boundSingleValue(heading, Property.headingMag));
        }
      }
    }
    return values;
  }
}
