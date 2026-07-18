// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser128267 extends PacketParser {
  @override
  final pgn = 128267;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);

    final depth = _scaleIfNotNull(_readUint32(payload, 1), 0.01);
    final offset = _scaleIfNotNull(_readInt16(payload, 5), 0.001);
    if (depth == null) {
      return [];
    }
    final values = <BoundValue>[boundSingleValue(depth, Property.depthUncalibrated)];
    if (offset != null) {
      values.add(boundSingleValue(depth + offset, Property.depthWithOffset));
    }
    return values;
  }
}
