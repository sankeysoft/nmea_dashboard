// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129025 extends PacketParser {
  @override
  final pgn = 129025;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final lat = _scaleIfNotNull(_readInt32(payload, 0), 1e-7);
    final long = _scaleIfNotNull(_readInt32(payload, 4), 1e-7);
    if (lat == null || long == null) {
      return [];
    }
    return [boundDoubleValue(lat, long, Property.gpsPosition, tier: 2)];
  }
}
