// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';

/// A complex splitter that creates complete NMEA packets from the Yacht Devices
/// "RAW" formatted CAN frames.
class YdRawMessageSplitter extends MessageSplitter<ByteData> {
  /// Subcontract the breaking of ascii into lines to a more generic splitter.
  final _lineSplitter = CrlfMessageSplitter();

  @override
  List<ByteData> read(Uint8List data) {
    List<ByteData> messages = [];

    final lines = _lineSplitter.read(data);
    for (final line in lines) {
      final parts = line.split(' ');
      if (parts.length < 4 || parts.length > 11) {
        // Frame line is not in a valid format. Ignore it.
        continue;
      } else if (parts[1] != 'R') {
        // Frame line is not for received data. Ignore it.
        continue;
      }
      final (pgn, source) = _hexHeaderToPgnSource(parts[2]);
      final payload = parts.skip(3).map((h) => int.parse(h, radix: 16));
      messages.add(_SerializedMessage.fromComponents(pgn, source, payload).data);
    }
    return messages;
  }

  @override
  String loggable(ByteData message) {
    return hexString(message);
  }
}

/// A validator for the messages output by YdRawMessageSplitter, trivial since the splitter
/// already ensured its outputs were valid.
class YdRawMessageValidator extends MessageValidator<ByteData, int> {
  @override
  ValidatedMessage<ByteData, int>? validate(ByteData serialized) {
    final message = _SerializedMessage.fromByteData(serialized);
    return ValidatedMessage(message.pgn, message.source, message.payload);
  }
}

/// A simple bytes format to transfer assembled messages from the Splitter to the Validator.
class _SerializedMessage {
  final ByteData data;

  factory _SerializedMessage.fromByteData(ByteData data) {
    if (data.lengthInBytes < 7) {
      throw const FormatException('Packet too short');
    }
    return _SerializedMessage._internal(data);
  }

  factory _SerializedMessage.fromComponents(int pgn, int source, Iterable<int> payload) {
    final payloadBytes = payload.toList();
    if (payloadBytes.isEmpty) {
      throw const FormatException('Payload too short');
    }
    final bytes = Uint8List(6 + payloadBytes.length);
    bytes.setRange(6, bytes.length, payloadBytes);
    final byteData = ByteData.sublistView(bytes);
    byteData.setUint32(0, pgn);
    byteData.setUint16(4, source);
    return _SerializedMessage._internal(byteData);
  }

  _SerializedMessage._internal(this.data);

  /// Returns the pgn of this message.
  int get pgn => ByteData.sublistView(data).getUint32(0);

  /// Returns the source of this message.
  int get source => ByteData.sublistView(data).getUint16(4);

  /// Returns the payload of this message.
  ByteData get payload => ByteData.sublistView(data, 6);
}

/// Returns the PGN and source contained in the supplied 29-bit NMEA header,
/// expressed in hex format.
(int, int) _hexHeaderToPgnSource(String header) {
  final id = int.parse(header, radix: 16);

  final dataPage = (id >> 24) & 0x1;
  final pduFormat = (id >> 16) & 0xFF;
  final pduSpecific = (id >> 8) & 0xFF;
  final source = id & 0xFF;

  final pgn = (pduFormat < 240)
      ? (dataPage << 16) | (pduFormat << 8)
      : (dataPage << 16) | (pduFormat << 8) | pduSpecific;

  return (pgn, source);
}
