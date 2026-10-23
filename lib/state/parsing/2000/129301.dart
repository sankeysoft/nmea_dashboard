// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129301 extends PacketParser {
  @override
  final pgn = 129301;

  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 10);
    final time = _scaleIfNotNull(_readInt32(payload, 1), 0.001);

    // Negative values are the time elapsed since passing the mark, only report time to go.
    if (time == null || time < 0) {
      return [];
    }
    return [boundSingleValue(time, Property.waypointTime)];
  }
}
