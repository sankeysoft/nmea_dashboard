// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129291 extends PacketParser {
  @override
  final pgn = 129291;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final reference = payload.getUint8(1) & 0x03;
    final set = _scaleIfNotNull(_readUint16(payload, 2), 0.0001 * radiansToDegrees);
    final drift = _scaleIfNotNull(_readUint16(payload, 2), 0.01);

    final values = <BoundValue>[];
    // Only process set when reported as true.
    if (reference == 0 && set != null) {
      values.add(boundSingleValue(set, Property.currentSet));
    }
    if (drift != null) {
      values.add(boundSingleValue(drift, Property.currentDrift));
    }
    return values;
  }
}
