// Copyright Jody M Sankey 2026.
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

/// Validates NMEA messages of type M to produce ValidatedMessages with type and sender of type S.
abstract class MessageValidator<M, S> {
  /// Verifies the supplied message, returning either a ValidatedMessage, null if the message
  /// was valid but should not be processed, or throws a FormatException if the message was
  /// invalid.
  ValidatedMessage<M, S>? validate(M message);
}

/// The results of successfully validating a message.
class ValidatedMessage<M, S> {
  /// The message type (i.e. sentence type or PGN).
  final S type;

  /// The message sender.
  final S sender;

  /// The message payload.
  final M payload;

  ValidatedMessage(this.type, this.sender, this.payload);

  /// Returns a convenient string representation of the payload.
  String payloadToString() {
    if (payload is ByteData) {
      final data = payload as ByteData;
      final buffer = StringBuffer("0x");
      for (int i = 0; i < data.lengthInBytes; i++) {
        buffer.write(data.getUint8(i).toRadixString(16).padLeft(2, '0'));
        if (i % 4 == 3 && i != data.lengthInBytes - 1) {
          buffer.write('_');
        }
      }
      return buffer.toString();
    }
    return payload.toString();
  }
}
