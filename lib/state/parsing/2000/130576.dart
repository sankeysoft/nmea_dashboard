// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130576 extends PacketParser {
  @override
  final pgn = 130576;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final port = _readInt8(payload, 0)?.toDouble();
    final starboard = _readInt8(payload, 1)?.toDouble();

    if (port != null) _validateInRange(port, 0.0, 100.0);
    if (starboard != null) _validateInRange(starboard, 0.0, 100.0);
    return [
      optionalBoundSingleValue(port, Property.trimPort),
      optionalBoundSingleValue(starboard, Property.trimStarboard),
    ].nonNulls.toList();
  }
}
