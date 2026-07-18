// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130313 extends PacketParser {
  @override
  final pgn = 130313;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final humidity = _scaleIfNotNull(_readInt16(payload, 3), 0.004);
    return humidity == null ? [] : [boundSingleValue(humidity, Property.relativeHumidity)];
  }
}
