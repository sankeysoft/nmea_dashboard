// Copyright Jody M Sankey 2026.
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';

/// A splitter that looks for messages starting with DLE-STX and ending in DLE-ETX, removing
/// DLE-escaping of any other DLE bytes in the message.
class DleMessageSplitter extends MessageSplitter<ByteData> {
  static const dle = 16;
  static const stx = 02;
  static const etx = 03;

  /// The unescaped content of the message currently being received, or null if not in a message.
  BytesBuilder? _message;

  /// Whether the last byte read was a DLE awaiting the second byte of its pair.
  bool _pendingDle = false;

  @override
  List<ByteData> read(Uint8List data) {
    List<ByteData> messages = [];
    for (final byte in data) {
      if (_pendingDle) {
        if (byte == stx) {
          // Start of a new message, discarding any unterminated message in progress.
          _message = BytesBuilder();
          _pendingDle = false;
        } else if (byte == etx && _message != null) {
          // End of the current message.
          messages.add(ByteData.sublistView(_message!.takeBytes()));
          _message = null;
          _pendingDle = false;
        } else if (byte == dle && _message != null) {
          // An escaped DLE inside a message, keep the DLE.
          _message!.addByte(dle);
          _pendingDle = false;
        } else if (byte == dle) {
          // A DLE outside a message could be the first byte of a start pair.
          _pendingDle = true;
        } else {
          // An invalid DLE pair, discard any message in progress.
          _message = null;
          _pendingDle = false;
        }
      } else if (byte == dle) {
        // Record any fresh DLE but don't copy into the message.
        _pendingDle = true;
      } else {
        // Write normal bytes into the message if one is in progress.
        _message?.addByte(byte);
      }
    }
    return messages;
  }
}

/// A validator for ActiSense NGT format packets (after DLE start/stop/escape has been removed).
class NgtValidator extends MessageValidator<ByteData, int> {
  static const int _packetHeaderLen = 2;
  static const int _payloadHeaderLen = 11;
  static const int _packetTrailerLen = 1;
  static const int _incomingID = 147;

  @override
  ValidatedMessage<ByteData, int>? validate(ByteData raw) {
    if (raw.lengthInBytes < _packetHeaderLen + _payloadHeaderLen + _packetTrailerLen) {
      throw const FormatException('Packet too short');
    }

    final packetSize = raw.getUint8(1);
    if (raw.lengthInBytes != _packetHeaderLen + _packetTrailerLen + packetSize) {
      throw FormatException('Packet data does not match size=$packetSize');
    }
    final id = raw.getUint8(0);
    if (id != _incomingID) {
      // Ignore outgoing packets.
      return null;
    }

    final pgn = raw.getUint32(_packetHeaderLen + 0, Endian.little) >> 8;
    final source = raw.getUint8(_packetHeaderLen + 5);
    final payloadSize = raw.getUint8(_packetHeaderLen + 10);
    if (raw.lengthInBytes - _packetHeaderLen - _payloadHeaderLen - _packetTrailerLen !=
        payloadSize) {
      throw FormatException('Payload data does not match size=$payloadSize');
    }

    _validateChecksum(raw);
    final payloadStart = _packetHeaderLen + _payloadHeaderLen;
    final payloadEnd = raw.lengthInBytes - _packetTrailerLen;

    return ValidatedMessage(pgn, source, ByteData.sublistView(raw, payloadStart, payloadEnd));
  }

  /// Validates that the supplied packet's trailing checksum byte matches its content, throwing
  /// a FormatException if not.
  static void _validateChecksum(ByteData raw) {
    // Checksum is defined as 2's complement of the sum of all bytes from byte 1 to n-4 of the
    // original DLE-STX...DLE-ETX frame. Reinstate the leading STX byte before summing.
    const stx = 0x02;
    int sum = stx;
    for (int i = 0; i < raw.lengthInBytes - _packetTrailerLen; i++) {
      sum += raw.getUint8(i);
    }
    final expected = (0x100 - (sum & 0xFF)) & 0xFF;
    final actual = raw.getUint8(raw.lengthInBytes - 1);
    if (expected != actual) {
      throw FormatException(
        'Invalid checksum: expected 0x${expected.toRadixString(16)}, '
        'got 0x${actual.toRadixString(16)}',
      );
    }
  }
}
