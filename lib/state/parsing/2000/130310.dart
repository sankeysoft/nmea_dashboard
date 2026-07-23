// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130310 extends PacketParser {
  @override
  final pgn = 130310;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final waterTemp = _scaleOffsetIfNotNull(_readUint16(payload, 1), 0.01, absoluteZeroInCelcius);
    final airTemp = _scaleOffsetIfNotNull(_readUint16(payload, 3), 0.01, absoluteZeroInCelcius);
    final pressure = _scaleIfNotNull(_readUint16(payload, 5), 100);
    return [
      optionalBoundSingleValue(waterTemp, Property.waterTemperature, tier: 4),
      optionalBoundSingleValue(airTemp, Property.airTemperature, tier: 4),
      optionalBoundSingleValue(pressure, Property.pressure, tier: 3),
    ].nonNulls.toList();
  }
}
