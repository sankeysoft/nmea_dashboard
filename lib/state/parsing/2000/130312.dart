// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130312 extends PacketParser {
  @override
  final pgn = 130312;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);

    final temperature = _scaleOffsetIfNotNull(_readUint16(payload, 3), 0.01, absoluteZeroInCelcius);
    final temperatureProperty = switch (payload.getUint8(2)) {
      (0) => Property.waterTemperature,
      (1) => Property.airTemperature,
      _ => null,
    };

    if (temperature == null || temperatureProperty == null) {
      return [];
    }
    return [boundSingleValue(temperature, temperatureProperty, tier: 2)];
  }
}
