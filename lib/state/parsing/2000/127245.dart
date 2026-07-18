// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127245 extends PacketParser {
  @override
  final pgn = 127245;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final raw = _readInt16(payload, 4);
    if (raw == null) {
      return [];
    }
    // Scaling value taken from CAN boat documentation.
    final degrees = raw * 0.0001 * radiansToDegrees;
    _validateInRange(degrees, -90, 90);

    return [boundSingleValue(degrees, Property.rudderAngle)];
  }
}
