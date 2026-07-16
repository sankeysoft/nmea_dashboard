// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

/// The time between count events.
const Duration _logInterval = Duration(minutes: 5);

/// Tracks the count for some set of message types.
@visibleForTesting
class MessageCounts {
  int _total = 0;
  final _map = SplayTreeMap<String, int>();

  /// Increments the count of the supplied type, returning the new count.
  int increment(String type) {
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

/// Parses strings into nmea messages, keeping track of the count for each
/// message type.
abstract class NmeaParser {
  static final _log = Logger('NmeaParser');

  final ignoredCounts = MessageCounts();
  final unsupportedCounts = MessageCounts();
  final successCounts = MessageCounts();
  final emptyCounts = MessageCounts();
  DateTime _lastLog;

  /// Constructs a new parser for NMEA messages
  NmeaParser() : _lastLog = DateTime.now();

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
      _log.info('No messages received since $lastLogString');
    } else {
      _log.info('Sucessfully parsed ${successCounts.total} messages: ${successCounts.summary}');
      successCounts.clear();
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
      _log.info('Received ${ignoredCounts.total} ignored messages: ${ignoredCounts.summary}');
      ignoredCounts.clear();
    }
  }
}
