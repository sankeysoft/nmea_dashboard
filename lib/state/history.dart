// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
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
class _HistoryEvent implements Comparable<_HistoryEvent> {
  final DateTime time;
  final History history;

  _HistoryEvent(this.time, this.history);

  @override
  int compareTo(_HistoryEvent other) {
    // Swap sign in comparison so min time is pulled from the HeapPriorityQueue
    // first.
    return time.compareTo(other.time);
    //return time.millisecondsSinceEpoch
    //    .compareTo(-other.time.millisecondsSinceEpoch);
  }
}

/// A helper to manage persistance and timing for history data.
class HistoryManager {
  /// This class's logger.
  static final _log = Logger('HistoryManager');

  /// A SharedPrefs reference used to interact with persistent storage.
  final SharedPreferences prefs;

  final HeapPriorityQueue<_HistoryEvent> _events;

  HistoryManager(this.prefs) : _events = HeapPriorityQueue() {
    Timer.periodic(_timerInterval, (_) => _checkTimedEvents());
  }

  static Future<HistoryManager> create() async {
    return HistoryManager(await SharedPreferences.getInstance());
  }

  /// Fires timed events in response to timer completion.
  void _checkTimedEvents() {
    final now = DateTime.now().toUtc();
    while (_events.isNotEmpty && now.isAfter(_events.first.time)) {
      final event = _events.removeFirst();
      event.history._endSegment(now);
    }
  }

  /// Registers a new timed event.
  void registerEvent(DateTime time, History history) {
    _events.add(_HistoryEvent(time, history));
  }

  /// Writes the supplied history information into a shared preference.
  void save(String dataId, HistoryInterval interval, List<double?> values,
      DateTime endValueTime) {
    // Shared prefs does not have well matched datatypes, best we can do is
    // a list of strings. Start with the segment duration as a sanity check.
    List<String> output = [
      interval.segment.inSeconds.toString(),
      endValueTime.millisecondsSinceEpoch.toString()
    ];
    output.addAll(values.map((v) => (v == null) ? '' : v.toString()));
    prefs.setStringList(key(dataId, interval), output);
  }

  /// Creates a new history, using data retrieved from shared preferences where
  /// possible.
  History restoreHistory(HistoryInterval interval, String dataId) {
    final data = prefs.getStringList(key(dataId, interval));
    if (data == null) {
      _log.info('No stored history for $dataId, creating a new object');
      return History(interval, dataId, this);
    }
    if (data.length != interval.count + 2) {
      _log.warning(
          'Stored history for $dataId ${interval.name} wrong length (${data.length})');
      return History(interval, dataId, this);
    }

    final segment = int.tryParse(data[0]);
    if (segment == null || segment != interval.segment.inSeconds) {
      _log.warning(
          'Stored history for $dataId ${interval.name} wrong segment size ($segment)');
      return History(interval, dataId, this);
    }

    final endValueTime = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(data[1]) ?? 0,
        isUtc: true);
    final values = data.sublist(2).map((v) => double.tryParse(v)).toList();
    return History(interval, dataId, this,
        previousEndValueTime: endValueTime, previousValues: values);
  }

  /// Returns the shared prefs key used to store a history.
  static String key(String dataId, HistoryInterval interval) {
    return 'history_v1_${dataId}_${interval.name}';
  }
}

/// A optionally present history of the average value of some property over a
/// sequence of time segments. Only present when one or more change notifiers
/// are connected.
class OptionalHistory with ChangeNotifier {
  /// The interval that we store over.
  final HistoryInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// A manager used for persistence.
  HistoryManager? _manager;

  /// The history, populated while this object has a manager and listeners.
  History? _inner;

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
      _inner = _manager!.restoreHistory(interval, dataId);
      _inner!.addListener(() => notifyListeners());
    }
  }

  /// Adds a new value into the history.
  void addValue(final SingleValue<double> newValue) {
    _inner?.addValue(newValue);
  }

  History? get inner => _inner;
}

/// A class to accumulate values within some time window.
class _Accumulator {
  int count;
  double? total;

  _Accumulator() : count = 0;

  // Adds a new value into this accumulator.
  add(double value) {
    count += 1;
    total = (total == null) ? value : total! + value;
  }

  /// Returns the average of the values added into this accumulator.
  double? average() {
    return (total == null) ? null : total! / count;
  }
}

/// A history of the average value of some property over a sequence of time
/// segments. Values are null where no data was received.
class History with ChangeNotifier {
  /// This class's logger.
  static final _log = Logger('History');

  /// The interval that we store over.
  final HistoryInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// The array of recent values.
  final List<double?> _values;

  /// A manager for persistence.
  final HistoryManager _manager;

  /// The time at the end of the last segment in values.
  DateTime _endValueTime;

  /// The end value time of the last save.
  DateTime _lastSaveEvt;

  /// A class to accumulate data over an interval.
  _Accumulator _accumulator;

  /// The minimum and maximum values, only populated if some data is present.
  double? _min;
  double? _max;

  History(this.interval, this.dataId, this._manager,
      {DateTime? previousEndValueTime, List<double?>? previousValues})
      : _values = List.filled(interval.count, null, growable: true),
        _accumulator = _Accumulator(),
        _endValueTime =
            truncateUtcToDuration(DateTime.now().toUtc(), interval.segment),
        _lastSaveEvt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) {
    if (previousEndValueTime != null && previousValues != null) {
      // Try to populate segment values from the old history if any are still
      // applicable.
      final previousSegmentOffset =
          (endValueTime.difference(previousEndValueTime).inSeconds /
                  interval.segment.inSeconds)
              .round();
      for (int i = previousSegmentOffset; i < previousValues.length; i++) {
        values[i - previousSegmentOffset] = previousValues[i];
      }
      _updateMinMax();
    }
    _manager.registerEvent(_endValueTime.add(interval.segment), this);
  }

  /// Handles the end of the current accumulation segment, and the start of
  /// the next.
  void _endSegment(DateTime now) {
    // Read the current accumlator and start a new one.
    final average = _accumulator.average();
    _accumulator = _Accumulator();

    // Potentially we are being called way later than the end of the segment we
    // were accumulating, figure out how many we should slide the array down.
    final segmentCount =
        (now.difference(_endValueTime).inSeconds / interval.segment.inSeconds)
            .round();
    if (segmentCount <= 0) {
      _log.warning('Ignoring segment count $segmentCount updating history. '
          'Time may have stepped backwards');
    } else {
      _values.removeRange(0, math.min(segmentCount, _values.length));
      _values.add(average);
      for (int i = 1; i < segmentCount; i++) {
        _values.add(null);
      }
      _endValueTime = _endValueTime.add(interval.segment * segmentCount);
      _updateMinMax();
      notifyListeners();
      if (_endValueTime.isAfter(_lastSaveEvt.add(_saveInterval))) {
        _manager.save(dataId, interval, values, endValueTime);
        _lastSaveEvt = _endValueTime;
      }
    }

    // Register completion of the next segment.
    _manager.registerEvent(_endValueTime.add(interval.segment), this);
  }

  /// Recalculates the minimums and maximums from _value.
  void _updateMinMax() {
    _min = null;
    _max = null;
    for (final v in _values) {
      if (v != null) {
        if (_min == null || v <= _min!) {
          _min = v;
        }
        if (_max == null || v >= _max!) {
          _max = v;
        }
      }
    }
  }

  /// Adds a new value into the history.
  void addValue(final SingleValue<double> newValue) {
    _accumulator.add(newValue.value);
  }

  /// The historical values of the element.
  List<double?> get values => _values;

  /// The minimum and maximum values of the element.
  double? get min => _min;
  double? get max => _max;

  /// The end time of the last segment tracked.
  DateTime get endValueTime => _endValueTime;
}
