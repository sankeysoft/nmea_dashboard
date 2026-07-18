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
    // TODO: Consider supporting and reading deviation.

    final values = <BoundValue>[];
    if (variation != null) {
      values.add(boundSingleValue(variation, Property.variation));
    }
    // TODO: check the logic here and ensure we've got enough set in either case.
    if (heading != null) {
      if (reference == 0) {
        values.add(boundSingleValue(heading, Property.heading));
      } else if (reference == 1) {
        values.add(boundSingleValue(heading, Property.headingMag));
      }
    }
    return values;
  }
}
