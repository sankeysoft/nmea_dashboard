// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129284 extends PacketParser {
  @override
  final pgn = 129284;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 34);
    final reference = payload.getUint8(5) & 0x03;
    final wptRange = _scaleIfNotNull(_readUint32(payload, 1), 0.01);
    final wptBearing = _scaleIfNotNull(_readUint16(payload, 14), 0.0001 * radiansToDegrees);

    final values = <BoundValue>[];
    if (wptRange != null) {
      values.add(boundSingleValue(wptRange, Property.waypointRange));
    }
    // Only process bearing when reported as true.
    if (wptBearing != null && reference == 0) {
      values.add(boundSingleValue(wptBearing, Property.waypointBearing));
    }
    return values;
  }
}
