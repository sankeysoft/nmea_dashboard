// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';

/// A optionally present history of the average value of some property over a
/// sequence of time segments. Only present when one or more change notifiers
/// are connected.
class OptionalHistory with ChangeNotifier {
  /// The interval that we store over.
  final HistoryInterval interval;

  /// The history.
  History? _history;

  OptionalHistory(this.interval) {
    //TODO: Don't initialize until a listener connects
    _history = History(interval);
    _history!.addListener(() => notifyListeners());
  }

  /// Adds a new value into the history.
  void addValue(final SingleValue<double> newValue) {
    _history?.addValue(newValue);
  }

  // TODO: Delete the history on last listener removal.

  List<double?> get values => _history?.values ?? [];
}

/// A class to accumulate values within some time window.
class _Accumulator {
  int count;
  double? total;

  _Accumulator() : count = 0;

  // Adds a new value into this accumulator.
  add(double value) {
    count += 1;
    total = (total ?? 0.0) + value;
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

  /// A timer until the current history accumulation segment ends.
  Timer? _segmentTimer;

  /// The array of recent values.
  final List<double?> _values;

  /// The time at the end of the last segment in values.
  DateTime _endValueTime;

  /// A class to accumulate data over an interval.
  _Accumulator _accumulator;

  /// The minimum and maximum values, only populated if some data is present.
  double? _min;
  double? _max;

  History(this.interval)
      : _values = List.filled(interval.count, null, growable: true),
        _accumulator = _Accumulator(),
        // TODO: align the segments on a minute/second to allow restoration from
        // a previous lifecycle.
        _endValueTime = DateTime.now().toUtc() {
    // TODO: attempt to read from disk
    _segmentTimer = Timer(interval.segment, () => _endSegment());
  }

  /// Handles the end of the current accumulation segment, and the start of
  /// the next.
  void _endSegment() {
    final now = DateTime.now().toUtc();
    _segmentTimer?.cancel();

    // Read the current accumlator and start a new one
    final average = _accumulator.average();
    _accumulator = _Accumulator();

    // Potentially we are being called way later than the end of the segment we
    // were accumulating, figure out how many we should slide the array down.
    final segmentCount =
        (now.difference(_endValueTime).inSeconds / interval.segment.inSeconds)
            .floor();
    if (segmentCount <= 0) {
      _log.warning('Ignoring segment count $segmentCount updating history. '
          'Time may have stepped back or timer misfired');
    } else {
      _values.removeRange(0, segmentCount);
      _values.add(average);
      for (int i = 1; i < segmentCount; i++) {
        _values.add(null);
      }
      // TODO: Write to disk
      _updateMinMax();
      _endValueTime = _endValueTime.add(interval.segment * segmentCount);
      notifyListeners();
    }

    // Start the next timer.
    _segmentTimer = Timer(_endValueTime.add(interval.segment).difference(now),
        () => _endSegment());
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
    // If a value is present an accumulator will also be present. Trust it is
    // for the correct window
    _accumulator.add(newValue.value);
  }

  /// The historical values of the element.
  List<double?>? get values => _values;
}
