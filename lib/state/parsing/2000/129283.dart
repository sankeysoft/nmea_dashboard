// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129283 extends PacketParser {
  @override
  final pgn = 129283;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final xte = _scaleIfNotNull(_readInt32(payload, 2), 0.01);
    return xte == null ? [] : [boundSingleValue(xte, Property.crossTrackError)];
  }
}
