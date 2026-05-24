// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

/// The maximum number of log entries we store.
const int _maxEntries = 250;

/// Minimum levels for the in-app log and developer log
const Level _appLevel = Level.INFO;
const Level _devLevel = Level.FINE;

/// A single entry tracked by the logger.
class LogEntry {
  final Level level;
  final DateTime time;
  final String message;

  LogEntry(this.level, this.message) : time = DateTime.now();

  @override
  String toString() {
    return '${DateFormat('Hms').format(time)} $level $message';
  }
}

/// A class to receive and store log records.
class LogSet with ChangeNotifier {
  /// The actual entries in the log.
  final List<LogEntry> _entries = [];

  /// Returns the stored entry.
  List<LogEntry> get entries => _entries;

  /// Adds a new record to the set of logs.
  void add(LogRecord record) {
    if (record.level >= _appLevel) {
      final entry = LogEntry(record.level, record.message);
      // Make space in the array
      while (_entries.length >= _maxEntries) {
        _entries.removeAt(0);
      }
      // Add the new entry
      _entries.add(entry);
      notifyListeners();
    }
    if (record.level >= _devLevel) {
      // Write to the developer log for nice VS code integration.
      log("${record.level}: ${record.message}", level: record.level.value);
    }
  }

  /// Removes all records.
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  @override
  String toString() {
    return _entries.map((e) => e.toString()).join('\n');
  }
}
