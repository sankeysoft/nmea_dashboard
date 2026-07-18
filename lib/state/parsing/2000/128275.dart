// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser128275 extends PacketParser {
  @override
  final pgn = 128275;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 14);
    final log = _readUint32(payload, 6)?.toDouble();
    final trip = _readUint32(payload, 10)?.toDouble();
    return [
      optionalBoundSingleValue(log, Property.distanceTotal),
      optionalBoundSingleValue(trip, Property.distanceTrip),
    ].nonNulls.toList();
  }
}
