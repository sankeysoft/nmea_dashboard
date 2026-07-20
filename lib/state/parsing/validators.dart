// Copyright Jody M Sankey 2026.
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

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
}
