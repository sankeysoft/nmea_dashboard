// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:developer';

import 'package:logging/logging.dart';

/// The maximum number of log entries we store.
const int _maxEntries = 100;

/// A single entry tracked by the logger.
class LogEntry {
  final Level level;
  final DateTime time;
  final String message;

  LogEntry(this.level, this.message): time = DateTime.now();
}

/// A class to receive and store log records.
class LogSet {
  /// The actual entries in the log.
  final List<LogEntry> _entries = [];

  /// Returns the stored entry.
  List<LogEntry> get entries => _entries;

  /// Adds a new `logger` record to the set.
  void add(LogRecord record) {
    final entry = LogEntry(record.level, record.message);
    // Make space in the array
    while (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    // Add the new entry
    _entries.add(entry);
    // And write to the developer log.
    log(record.message, level: record.level.value);
  }
}