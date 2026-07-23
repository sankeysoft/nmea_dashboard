// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130311 extends PacketParser {
  @override
  final pgn = 130311;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final source = payload.getUint8(1);
    final temperature = _scaleOffsetIfNotNull(_readUint16(payload, 2), 0.01, absoluteZeroInCelcius);
    final humidity = _scaleIfNotNull(_readInt16(payload, 4), 0.004);
    final pressure = _scaleIfNotNull(_readUint16(payload, 6), 100);

    final temperatureProperty = switch (source >> 2) {
      (0) => Property.waterTemperature,
      (1) => Property.airTemperature,
      _ => null,
    };

    final values = <BoundValue>[];
    if (temperature != null && temperatureProperty != null) {
      values.add(boundSingleValue(temperature, temperatureProperty, tier: 3));
    }
    if (humidity != null) {
      values.add(boundSingleValue(humidity, Property.relativeHumidity, tier: 2));
    }
    if (pressure != null) {
      values.add(boundSingleValue(pressure, Property.pressure, tier: 2));
    }
    return values;
  }
}
