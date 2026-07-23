// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129539 extends PacketParser {
  @override
  final pgn = 129539;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final hdop = _scaleIfNotNull(_readInt16(payload, 2), 0.01);
    return hdop == null ? [] : [boundSingleValue(hdop, Property.gpsHdop)];
  }
}
