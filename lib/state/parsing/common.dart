// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:nmea_dashboard/state/values.dart';

/// The time between count events.
const Duration _logInterval = Duration(minutes: 5);

/// Tracks the count for some set of message types.
@visibleForTesting
class MessageCounts<T> {
  int _total = 0;
  final _map = SplayTreeMap<T, int>();

  /// Increments the count of the supplied type, returning the new count.
  int increment(T type) {
    _total += 1;
    final count = (_map[type] ?? 0) + 1;
    _map[type] = count;
    return count;
  }

  /// Resets all message counts to zero.
  void clear() {
    _total = 0;
    _map.clear();
  }

  /// Returns true iff no messages have been received.
  bool get isEmpty {
    return _total == 0;
  }

  /// Returns the total count across all types.
  int get total {
    return _total;
  }

  /// Returns a string description of the counts for each type.
  String get summary {
    return _map.entries.map((e) => '${e.key}:${e.value}').join(', ');
  }
}

/// Parses nmea messages into values, count for each message type.
abstract class MessageParser<M, S> {
  static final _log = Logger('MessageParser');

  final ignoredCounts = MessageCounts<S>();
  final unsupportedCounts = MessageCounts<S>();
  final successCounts = MessageCounts<S>();
  final errorCounts = MessageCounts<S>();
  final emptyCounts = MessageCounts<S>();
  DateTime _lastLog;

  /// Constructs a new parser for NMEA messages
  MessageParser() : _lastLog = DateTime.now();

  /// Returns the set of message types that should be ignored silently.
  Set<S> get ignoredTypes;

  /// Returns the set of message types that this parser supports.
  Set<S> get supportedTypes;

  /// Attempts to parse the supplied message, returning one or more bound values if parsing
  /// the message contents was successful or zero values if parsing was unsuccessful. Throws a
  /// FormatException if parsing errors were encountered. Clients should use parseWithCounting
  /// rather than this inrternal method.
  List<BoundValue> parse(ValidatedMessage<M, S> message);

  /// Attempts to parse the supplied message, returning one or more bound values if parsing
  /// the message contents was successful or zero values if no data was found, tracks the number
  /// of successful, empty, unsupported, and ignored messages. Throws a FormatException if parsing
  /// errors were encountered.
  List<BoundValue> parseWithCounting(ValidatedMessage<M, S> message) {
    // Silently skip ignored messages.
    if (ignoredTypes.contains(message.type)) {
      ignoredCounts.increment(message.type);
      return [];
    }

    // Don't attempt to process messages unless the type is supported. Log one example of each.
    if (!supportedTypes.contains(message.type)) {
      if (unsupportedCounts.increment(message.type) <= 1) {
        _log.info('Example of unsupported ${message.type}: ${message.payloadToString()}');
      }
      return [];
    }

    try {
      final values = parse(message);
      if (values.isEmpty) {
        if (emptyCounts.increment(message.type) <= 1) {
          _log.info('Example of empty ${message.type}: ${message.payloadToString()}');
        }
      } else {
        successCounts.increment(message.type);
      }
      return values;
    } on FormatException {
      // Cap the number of exceptions we raise for each message type.
      if (errorCounts.increment(message.type) <= 5) {
        rethrow;
      }
      return [];
    }
  }

  /// If sufficient time has passed since the last count log, logs the current message counts then
  /// resets them.
  void logAndClearIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastLog) > _logInterval) {
      logAndClearCounts();
      _lastLog = now;
    }
  }

  /// Logs the current message counts then resets them.
  void logAndClearCounts() {
    final lastLogString = DateFormat('Hms').format(_lastLog);
    if (successCounts.isEmpty) {
      _log.info('No messages successfully received since $lastLogString');
    } else {
      _log.info('Sucessfully parsed ${successCounts.total} messages: ${successCounts.summary}');
      successCounts.clear();
    }
    if (!errorCounts.isEmpty) {
      _log.info('Received ${errorCounts.total} malformed messages: ${errorCounts.summary}');
      errorCounts.clear();
    }
    if (!emptyCounts.isEmpty) {
      _log.info('Received ${emptyCounts.total} messages without data: ${emptyCounts.summary}');
      emptyCounts.clear();
    }
    if (!unsupportedCounts.isEmpty) {
      _log.info(
        'Received ${unsupportedCounts.total} unsupported messages: ${unsupportedCounts.summary}',
      );
      unsupportedCounts.clear();
    }
    if (!ignoredCounts.isEmpty) {
      _log.fine('Received ${ignoredCounts.total} ignored messages: ${ignoredCounts.summary}');
      ignoredCounts.clear();
    }
  }
}

// Creates a BoundValue<SingleValue<double>> from the supplied input.
BoundValue<SingleValue<T>> boundSingleValue<T>(T number, Property property, {int tier = 1}) {
  return BoundValue(Source.network, property, SingleValue(number), tier: tier);
}

// Creates a BoundValue<SingleValue<double>> from the supplied input, or null if the input is null.
BoundValue<SingleValue<T>>? optionalBoundSingleValue<T>(
  T? number,
  Property property, {
  int tier = 1,
}) {
  return number == null ? null : boundSingleValue(number, property, tier: tier);
}

// Creates a BoundValue<DoubleValue<double>> from the supplied input.
BoundValue<DoubleValue<double>> boundDoubleValue(
  double first,
  double second,
  Property property, {
  int tier = 1,
}) {
  return BoundValue(Source.network, property, DoubleValue(first, second), tier: tier);
}
