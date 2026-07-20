// Copyright Jody M Sankey 2026.
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';
import 'dart:typed_data';

/// Splits network input packets into zero or more messages of data type M, potentially retaining
/// partial packets across calls.
abstract class MessageSplitter<M> {
  /// Split the supplied data (and potentially remaining data from previous calls) into zero or
  /// data packets of type T.
  List<M> read(Uint8List data);

  /// Returns a string representation of the message suitable for including in a log.
  String loggable(M message);
}

/// A splitter that interprets input data as a string and splits input data on terminating CRLF
/// sequences and optionally a supplied packet start regex.
class CrlfMessageSplitter extends MessageSplitter<String> {
  final endRegex = RegExp(r'[\n\r]');
  final RegExp? startRegex;
  String remaining = "";

  CrlfMessageSplitter({this.startRegex});

  @override
  List<String> read(Uint8List data) {
    List<String> messages = [];

    remaining += utf8.decode(data);

    // Keep going while the string contains a break into another packet.
    var nextSplit = _findSplit(remaining);
    while (nextSplit >= 0) {
      final potentialMessage = remaining.substring(0, nextSplit).trim();
      remaining = remaining.substring(nextSplit).trim();
      nextSplit = _findSplit(remaining);
      if (potentialMessage.isNotEmpty) {
        messages.add(potentialMessage);
      }
    }
    return messages;
  }

  /// Returns the best location to split remaing data based on the first CRLF, or message
  /// start indicator, or -1 if there is none. Searching for a start is needed because
  /// annoyingly some networks don't CRLF terminate all messages correctly.
  int _findSplit(String remainingData) {
    if (remainingData.length < 2) {
      return -1;
    }
    final nextEnd = remainingData.indexOf(endRegex);
    final nextStart = (startRegex == null) ? -1 : remainingData.indexOf(startRegex!, 1);
    if (nextEnd >= 0 && (nextStart <= 0 || nextEnd < nextStart)) {
      return nextEnd;
    } else if (nextStart > 0) {
      return nextStart;
    }
    return -1;
  }

  @override
  String loggable(String message) {
    return message;
  }
}

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

  @override
  String loggable(ByteData message) {
    return _hexString(message);
  }
}

/// A splitter that assumes every network packet is a single message.
class NullSplitter extends MessageSplitter<ByteData> {
  @override
  List<ByteData> read(Uint8List data) {
    return [ByteData.sublistView(data)];
  }

  @override
  String loggable(ByteData message) {
    return _hexString(message);
  }
}

String _hexString(ByteData data) {
  final hex = data.buffer
      .asUint8List(data.offsetInBytes, data.lengthInBytes)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return "0x$hex";
}
