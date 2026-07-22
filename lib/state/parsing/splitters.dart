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
}

/// A splitter that assumes every network packet is a single message.
class NullSplitter extends MessageSplitter<ByteData> {
  @override
  List<ByteData> read(Uint8List data) {
    return [ByteData.sublistView(data)];
  }
}
