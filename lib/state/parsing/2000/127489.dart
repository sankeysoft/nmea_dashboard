// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127489 extends PacketParser {
  @override
  final pgn = 127489;

  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 26);
    final oilPressure = _scaleIfNotNull(_readUint16(payload, 1), 100);
    final temperature = _scaleOffsetIfNotNull(_readUint16(payload, 5), 0.01, absoluteZeroInCelcius);
    final alternatorVoltage = _scaleIfNotNull(_readInt16(payload, 7), 0.01);

    final properties = switch (payload.getUint8(0)) {
      (0) => (
        Property.engine1OilPressure,
        Property.engine1Temperature,
        Property.alternator1Voltage,
      ),
      (1) => (
        Property.engine2OilPressure,
        Property.engine2Temperature,
        Property.alternator2Voltage,
      ),
      _ => null,
    };
    if (properties == null) {
      return [];
    }

    return [
      optionalBoundSingleValue(oilPressure, properties.$1),
      optionalBoundSingleValue(temperature, properties.$2),
      optionalBoundSingleValue(alternatorVoltage, properties.$3),
    ].nonNulls.toList();
  }
}
