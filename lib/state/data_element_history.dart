// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns the supplied time rounded down to the next multiple of the
/// supplied duration.
DateTime truncateUtcToDuration(DateTime input, Duration duration) {
  final durMs = duration.inMilliseconds;
  final durCount = (input.millisecondsSinceEpoch / durMs).floor();
  return DateTime.fromMillisecondsSinceEpoch(durCount * durMs, isUtc: true);
}

/// The minimum interval between saves of a single history. Prevents thrashing
/// preferences for the faster intervals.
const Duration _saveInterval = Duration(minutes: 1);

/// The interval between checks for segment completion.
const Duration _timerInterval = Duration(seconds: 2);

/// A simple PODO for timer events.
class _HistoryEvent<V extends Value> implements Comparable<_HistoryEvent> {
  final DateTime time;
  final History<V> history;

  _HistoryEvent(this.time, this.history);

  @override
  int compareTo(_HistoryEvent other) {
    return time.compareTo(other.time);
  }
}

/// A interface to manage persistance and timing for history data, fakeable
/// for testability.
abstract class HistoryManager {
  /// Registers a new timed event.
  void registerEvent(DateTime time, History history);

  /// Writes the supplied history information into a shared preference.
  void save<V extends Value>(
    String dataId,
    HistoryInterval interval,
    List<V?> values,
    DateTime endValueTime,
  );

  /// Creates a new history, using data retrieved from shared preferences where
  /// possible.
  History<V> restoreHistory<V extends Value>(HistoryInterval interval, String dataId);

  /// Returns the shared prefs key used to store a history.
  static String key(String dataId, HistoryInterval interval) {
    return 'history_v1_${dataId}_${interval.name}';
  }
}

/// A helper to manage persistance and timing for history data.
class HistoryManagerImpl extends HistoryManager {
  /// This class's logger.
  static final _log = Logger('HistoryManager');

  /// A SharedPrefs reference used to interact with persistent storage.
  final SharedPreferences prefs;

  final HeapPriorityQueue<_HistoryEvent> _events;

  HistoryManagerImpl(this.prefs) : _events = HeapPriorityQueue() {
    Timer.periodic(_timerInterval, (_) => _checkTimedEvents());
  }

  static Future<HistoryManagerImpl> create() async {
    return HistoryManagerImpl(await SharedPreferences.getInstance());
  }

  /// Fires timed events in response to timer completion.
  void _checkTimedEvents() {
    final now = DateTime.now().toUtc();
    while (_events.isNotEmpty && now.isAfter(_events.first.time)) {
      final event = _events.removeFirst();
      event.history.endSegment(now);
    }
  }

  /// Registers a new timed event.
  @override
  void registerEvent(DateTime time, History history) {
    _events.add(_HistoryEvent(time, history));
  }

  /// Writes the supplied history information into a shared preference.
  @override
  void save<V extends Value>(
    String dataId,
    HistoryInterval interval,
    List<V?> values,
    DateTime endValueTime,
  ) {
    // Shared prefs does not have well matched datatypes, best we can do is
    // a list of strings. Start with the segment duration as a sanity check.
    List<String> output = [
      interval.segment.inSeconds.toString(),
      endValueTime.millisecondsSinceEpoch.toString(),
    ];
    output.addAll(values.map((v) => (v == null) ? '' : v.serialize()));
    prefs.setStringList(HistoryManager.key(dataId, interval), output);
  }

  /// Creates a new history, using data retrieved from shared preferences where
  /// possible.
  @override
  History<V> restoreHistory<V extends Value>(HistoryInterval interval, String dataId) {
    final data = prefs.getStringList(HistoryManager.key(dataId, interval));
    if (data == null) {
      _log.info('No stored history for $dataId, creating a new object');
      return History<V>(interval, dataId, this);
    }
    if (data.length != interval.count + 2) {
      _log.warning('Stored history for $dataId ${interval.name} wrong length (${data.length})');
      return History<V>(interval, dataId, this);
    }

    final segment = int.tryParse(data[0]);
    if (segment == null || segment != interval.segment.inSeconds) {
      _log.warning('Stored history for $dataId ${interval.name} wrong segment size ($segment)');
      return History(interval, dataId, this);
    }

    final endValueTime = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(data[1]) ?? 0,
      isUtc: true,
    );
    final values = data.sublist(2).map((str) => Value.deserialize<V>(str)).toList();
    return History(
      interval,
      dataId,
      this,
      previousEndValueTime: endValueTime,
      previousValues: values,
    );
  }
}

/// A optionally present history of the average value of some property over a
/// sequence of time segments. Only present when one or more change notifiers
/// are connected.
class OptionalHistory<V extends Value> with ChangeNotifier {
  /// The interval that we store over.
  final HistoryInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// A manager used for persistence.
  HistoryManager? _manager;

  /// The history, populated while this object has a manager and listeners.
  History<V>? _inner;

  OptionalHistory(this.interval, this.dataId);

  void registerManager(HistoryManager manager) {
    _manager = manager;
    _createInnerIfNeeded();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _createInnerIfNeeded();
  }

  // Don't actually remove the inner history when the last listener is
  // removed - often its only a resize/redraw before immediately adding a new
  // listener and we don't want to disrupt the recording of history for this.
  // Not removing means we use a bit more memory than strictly necessary if
  // the user removes a graph, until the next restart.

  /// Create a history if had listeners and a manager and we haven't already.
  /// Pass its events up to our own listeners.
  void _createInnerIfNeeded() {
    if (_manager != null && hasListeners && _inner == null) {
      _inner = _manager!.restoreHistory<V>(interval, dataId);
      _inner!.addListener(() => notifyListeners());
    }
  }

  /// Adds a new value into the history.
  void addValue(V newValue) {
    _inner?.addValue(newValue);
  }

  History? get inner => _inner;
}

/// A history of the average value of some property over a sequence of time
/// segments. Values are null where no data was received.
class History<V extends Value> with ChangeNotifier {
  /// This class's logger.
  static final _log = Logger('History');

  /// The interval that we store over.
  final HistoryInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// The array of recent values.
  final List<V?> _values;

  /// A manager for persistence.
  final HistoryManager _manager;

  /// A class to accumulate data over an interval.
  final ValueAccumulator<V> _accumulator;

  /// The time at the end of the last segment in values.
  DateTime _endValueTime;

  /// The end value time of the last save.
  DateTime _lastSaveEvt;

  History(
    this.interval,
    this.dataId,
    this._manager, {
    DateTime? now,
    DateTime? previousEndValueTime,
    List<V?>? previousValues,
  }) : _values = List.filled(interval.count, null, growable: true),
       _accumulator = ValueAccumulator.forType(V) as ValueAccumulator<V>,
       _endValueTime = truncateUtcToDuration(now ?? DateTime.now().toUtc(), interval.segment),
       _lastSaveEvt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) {
    if (previousEndValueTime != null && previousValues != null) {
      // Try to populate segment values from the old history if any are still
      // applicable.
      final previousSegmentOffset =
          (endValueTime.difference(previousEndValueTime).inSeconds / interval.segment.inSeconds)
              .round();
      // Handle the case where the history had a different number of values
      // just in case.
      final srcStartIndex = previousValues.length + previousSegmentOffset - interval.count;
      for (int i = 0; i + srcStartIndex < previousValues.length; i++) {
        values[i] = previousValues[srcStartIndex + i];
      }
    }
    _manager.registerEvent(_endValueTime.add(interval.segment), this);
  }

  /// Handles the end of the current accumulation segment, and the start of
  /// the next.
  void endSegment(DateTime now) {
    // Read the current accumlator and start a new one.
    final average = _accumulator.get();
    _accumulator.clear();

    // Potentially we are being called way later than the end of the segment we
    // were accumulating, figure out how many we should slide the array down.
    final segmentCount = (now.difference(_endValueTime).inSeconds / interval.segment.inSeconds)
        .round();
    if (segmentCount <= 0) {
      _log.warning(
        'Ignoring segment count $segmentCount updating history. '
        'Time may have stepped backwards',
      );
    } else {
      if (segmentCount < _values.length) {
        // Remove old entries, add the new segment, and pad with nulls for
        // any segments we missed.
        _values.removeRange(0, segmentCount);
        _values.add(average);
        while (_values.length < interval.count) {
          _values.add(null);
        }
      } else {
        // Even the segment we were accumulating is out of range, start over.
        _values.clear();
        _values.addAll(List.filled(interval.count, null));
      }
      _endValueTime = _endValueTime.add(interval.segment * segmentCount);
      notifyListeners();
      if (_endValueTime.isAfter(_lastSaveEvt.add(_saveInterval))) {
        _manager.save(dataId, interval, values, endValueTime);
        _lastSaveEvt = _endValueTime;
      }
    }

    // Register completion of the next segment.
    _manager.registerEvent(_endValueTime.add(interval.segment), this);
  }

  /// Adds a new value into the history.
  void addValue(final V newValue) {
    _accumulator.add(newValue);
  }

  /// The historical values of the element.
  List<V?> get values => _values;

  /// The end time of the last segment tracked.
  DateTime get endValueTime => _endValueTime;
}
