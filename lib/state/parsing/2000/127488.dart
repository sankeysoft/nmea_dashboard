// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127488 extends PacketParser {
  @override
  final pgn = 127488;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);

    final instance = payload.getUint8(0);
    final rpm = _scaleIfNotNull(_readUint16(payload, 1), 0.25);
    final boostPressure = _scaleIfNotNull(_readUint16(payload, 3), 100.0);
    final trimRaw = payload.getInt8(5);
    final trim = (trimRaw >= 0 && trimRaw <= 100) ? trimRaw.toDouble() : null;

    final property = switch (instance) {
      0 => Property.engine1Rpm,
      1 => Property.engine2Rpm,
      _ => null,
    };

    final boostProperty = switch (instance) {
      0 => Property.engine1BoostPressure,
      1 => Property.engine2BoostPressure,
      _ => null,
    };

    final trimProperty = switch (instance) {
      0 => Property.engine1Trim,
      1 => Property.engine2Trim,
      _ => null,
    };

    final values = <BoundValue>[];

    if (rpm != null && property != null) {
      values.add(boundSingleValue(rpm, property, tier: 1));
    }

    if (boostPressure != null && boostProperty != null) {
      values.add(boundSingleValue(boostPressure, boostProperty, tier: 1));
    }

    if (trim != null && trimProperty != null) {
      values.add(boundSingleValue(trim, trimProperty, tier: 1));
    }

    return values;
  }
}
