// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';
import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/2000/common.dart';
import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';

/// A complex splitter that creates complete NMEA packets from the Yacht Devices
/// "RAW" formatted CAN frames.
class YdRawMessageSplitter extends MessageSplitter<ByteData> {
  /// Subcontract the breaking of ascii into lines to a more generic splitter.
  final _lineSplitter = CrlfMessageSplitter();

  /// A map of partially complete fast frame messages, indexed by PGN and source.
  final _partialFfMessages = <(int, int), _FastFrameMessage>{};

  @override
  List<ByteData> read(Uint8List data) {
    List<ByteData> messages = [];

    final lines = _lineSplitter.read(data);
    for (final line in lines) {
      final parts = line.split(' ');
      if (parts.length < 4 || parts.length > 11 || parts[1] != 'R') {
        // Frame line has wrong number of elements or is not received data. Ignore it.
        continue;
      }
      final (pgn, source) = _hexHeaderToPgnSource(parts[2]);
      final payload = Uint8List.fromList(
        parts.skip(3).map((h) => int.parse(h, radix: 16)).toList(),
      );

      if (Nmea2000Parser.fastFramePgns.contains(pgn)) {
        // Delegate frames that need to be assembled (fast frames) to a separate handler.
        final message = _handleFastFrame(pgn, source, payload);
        if (message != null) messages.add(message.data);
      } else {
        // Return the single frame case directly.
        messages.add(_SerializedMessage.fromComponents(pgn, source, payload).data);
      }
    }
    return messages;
  }

  _SerializedMessage? _handleFastFrame(int pgn, int source, Uint8List payload) {
    var msg = _partialFfMessages[(pgn, source)];
    if (msg == null) {
      // Create a new fast frame assembler.
      try {
        msg = _FastFrameMessage(pgn, source, payload);
      } on FormatException {
        // Exceptions are due to out of sequence or dropped frames and aren't worth logging.
        return null;
      }
      // Check if the message is complete. If not store for future frames.
      final completed = msg.complete();
      if (completed != null) {
        return completed;
      }
      _partialFfMessages[(pgn, source)] = msg;
      return null;
    }

    // Try to continue assembling the in-work message.
    try {
      msg.addFrame(payload);
    } on FormatException {
      // Abandon the sequence if we fail to add a frame.
      _partialFfMessages.remove((pgn, source));
      // Potentially the error was this packet should start a new sequence.
      // Recurse now that we've removed the in-work message to acheive that.
      return _handleFastFrame(pgn, source, payload);
    }
    final completed = msg.complete();
    if (completed != null) {
      _partialFfMessages.remove((pgn, source));
      return completed;
    }
    return null;
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

  factory _SerializedMessage.fromComponents(int pgn, int source, Uint8List payload) {
    if (payload.isEmpty) {
      throw const FormatException('Payload too short');
    }
    final bytes = Uint8List(6 + payload.length);
    bytes.setRange(6, bytes.length, payload);
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

/// A class to assemble messages from fast frames.
class _FastFrameMessage {
  final int pgn;
  final int source;
  late int _lastCounter;
  late int _remainingBytes;
  late Uint8List _payload;

  /// Constructs a new _fastFrameMessage from the supplied frame, throwing an exception if the
  /// sequence counter is not zero.
  _FastFrameMessage(this.pgn, this.source, Uint8List firstFrame) {
    _lastCounter = firstFrame[0];
    if (_lastCounter & 0x1F != 0) {
      throw FormatException("Sequence count ${_lastCounter & 0x1F} not 0.");
    }
    _remainingBytes = firstFrame[1];
    if (_remainingBytes == 0) {
      throw FormatException("Payload is empty.");
    }
    _payload = Uint8List(_remainingBytes);
    final frameDataLen = min(6, _remainingBytes);
    _payload.setRange(0, frameDataLen, firstFrame, 2);
    _remainingBytes -= frameDataLen;
  }

  /// Attempts the append the supplied frame to the message content, throwing a FormatException on
  /// consistency issues.
  void addFrame(Uint8List frame) {
    final counter = frame[0];
    if (counter >> 5 != _lastCounter >> 5) {
      throw FormatException(
        "Change in sequence. Got ${counter >> 5}, expected ${_lastCounter >> 5}",
      );
    }
    if (counter & 0x1F != (_lastCounter & 0x1F) + 1) {
      throw FormatException(
        "Out of order counter. Got ${counter & 0x1F}, expected ${(_lastCounter & 0x1F) + 1}",
      );
    }
    final frameDataLen = min(7, _remainingBytes);
    if (frame.length < frameDataLen + 1) {
      throw FormatException("Frame too short. Got ${frame.length}, expected ${frameDataLen + 1}");
    }
    final start = _payload.length - _remainingBytes;
    _payload.setRange(start, start + frameDataLen, frame, 1);
    _lastCounter = counter;
    _remainingBytes -= frameDataLen;
  }

  /// If the message has been fully assembled, return a _SerializedMessage, else null.
  _SerializedMessage? complete() {
    return (_remainingBytes == 0) ? _SerializedMessage.fromComponents(pgn, source, _payload) : null;
  }
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
