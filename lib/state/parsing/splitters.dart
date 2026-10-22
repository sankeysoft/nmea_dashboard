// Copyright Jody M Sankey 2026.
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger('MessageSplitter');

/// The maximum length of unterminated data a CrlfMessageSplitter will retain while waiting for
/// more input. Comfortably longer than any valid message.
const _maxRemainingLength = 1024;

/// Splits network input packets into zero or more messages of data type M, potentially retaining
/// partial packets across calls.
abstract class MessageSplitter<M> {
  /// A count of inputs that this splitter discarded because they did not form part of a valid message.
  int discardCount = 0;

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

    try {
      remaining += utf8.decode(data);
    } on FormatException catch (e) {
      _log.warning('Replacing invalid UTF-8 in ${data.length} byte packet: ${e.message}');
      remaining += utf8.decode(data, allowMalformed: true);
    }

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
    if (remaining.length > _maxRemainingLength) {
      // Data this long without a split cannot be a valid message, don't let it grow forever.
      remaining = "";
      discardCount++;
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
