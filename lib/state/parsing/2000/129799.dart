// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129799 extends PacketParser {
  @override
  final pgn = 129799;

  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 19);
    // The radio channel is six ASCII characters. VHF channels start with "90", followed by a
    // transmit frequency indication digit which we ignore, then a three digit channel number.
    final channel = String.fromCharCodes(Uint8List.sublistView(payload, 8, 14));
    if (!channel.startsWith('90')) {
      return [];
    }
    // Private channels (e.g. "9000L1") are not numeric so are not reported.
    final number = int.tryParse(channel.substring(3));
    return number == null ? [] : [boundSingleValue(number, Property.vhfChannel)];
  }
}
