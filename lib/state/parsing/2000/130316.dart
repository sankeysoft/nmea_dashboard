// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130316 extends PacketParser {
  @override
  final pgn = 130316;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final temperature = _scaleOffsetIfNotNull(
      _readUint24(payload, 3),
      0.001,
      absoluteZeroInCelcius,
    );

    final property = switch (payload.getUint8(2)) {
      (0) => Property.waterTemperature,
      (1) => Property.airTemperature,
      (2) => Property.dewPoint,
      _ => null,
    };

    if (temperature == null || property == null) {
      return [];
    }
    return [boundSingleValue(temperature, property)];
  }
}
