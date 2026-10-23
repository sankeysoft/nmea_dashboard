// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser128777 extends PacketParser {
  @override
  final pgn = 128777;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final rode = _scaleIfNotNull(_readUint16(payload, 3), 0.1);
    return rode == null ? [] : [boundSingleValue(rode, Property.anchorRode)];
  }
}
