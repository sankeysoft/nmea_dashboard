// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127508 extends PacketParser {
  @override
  final pgn = 127508;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);

    final instance = payload.getUint8(0);
    final voltage = _scaleIfNotNull(_readInt16(payload, 1), 0.01);

    final current = _scaleIfNotNull(_readInt16(payload, 3), 0.1);

    final temperature = _scaleOffsetIfNotNull(_readUint16(payload, 5), 0.01, absoluteZeroInCelcius);

    final voltageProperty = switch (instance) {
      0 => Property.battery1Voltage,
      1 => Property.battery2Voltage,
      _ => null,
    };

    final currentProperty = switch (instance) {
      0 => Property.battery1Current,
      1 => Property.battery2Current,
      _ => null,
    };

    final temperatureProperty = switch (instance) {
      0 => Property.battery1Temperature,
      1 => Property.battery2Temperature,
      _ => null,
    };

    final values = <BoundValue>[];

    if (voltage != null && voltageProperty != null) {
      values.add(boundSingleValue(voltage, voltageProperty, tier: 1));
    }

    if (current != null && currentProperty != null) {
      values.add(boundSingleValue(current, currentProperty, tier: 1));
    }

    if (temperature != null && temperatureProperty != null) {
      values.add(boundSingleValue(temperature, temperatureProperty, tier: 1));
    }

    return values;
  }
}
