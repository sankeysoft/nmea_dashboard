// Copyright Jody M Sankey 2026
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
    final dcType = payload.getUint8(2);
    final stateOfCharge = _readUint8(payload, 3)?.toDouble();

    // Only batteries (DC type 0) are supported.
    final property = switch ((dcType, payload.getUint8(1))) {
      (0, 0) => Property.battery1Charge,
      (0, 1) => Property.battery2Charge,
      _ => null,
    };

    if (stateOfCharge == null || property == null) {
      return [];
    }
    _validateInRange(stateOfCharge, 0.0, 100.0);
    return [boundSingleValue(stateOfCharge, property)];
  }
}
