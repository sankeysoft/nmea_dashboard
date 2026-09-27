// Copyright Jody M Sankey 2026
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127506 extends PacketParser {
  @override
  final pgn = 127506;
  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 11);

    final instance = payload.getUint8(1);

    final stateOfChargeRaw = payload.getUint8(3);
    final stateOfCharge = stateOfChargeRaw == 0xFF ? null : stateOfChargeRaw.toDouble();

    final timeRemainingRaw = payload.getUint16(5, Endian.little);
    final timeRemainingHours = timeRemainingRaw == 0xFFFF ? null : timeRemainingRaw / 60.0;

    final socProperty = switch (instance) {
      0 => Property.battery1StateOfCharge,
      1 => Property.battery2StateOfCharge,
      _ => null,
    };

    final timeProperty = switch (instance) {
      0 => Property.battery1TimeRemaining,
      1 => Property.battery2TimeRemaining,
      _ => null,
    };

    final values = <BoundValue>[];

    if (stateOfCharge != null && socProperty != null) {
      values.add(boundSingleValue(stateOfCharge, socProperty, tier: 1));
    }

    if (timeRemainingHours != null && timeProperty != null) {
      values.add(boundSingleValue(timeRemainingHours, timeProperty, tier: 1));
    }

    return values;
  }
}
