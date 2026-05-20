// Copyright Jody M Sankey 2025
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/values.dart';

/// The max allowed error in the time old values are removed.
/// This also sets the maximum rate at which timers will be scheduled.
const Duration _removalTolerance = Duration(milliseconds: 500);

/// A optionally present statistic tracking average of some property over a
/// time window. Only present when one or more change notifiers are connected.
class OptionalStats<V extends Value> with ChangeNotifier {
  /// The interval that we store over.
  final StatsInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// The history, populated while this object has a manager and listeners.
  Stats<V>? _inner;

  OptionalStats(this.interval, this.dataId);

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (hasListeners && _inner == null) {
      _inner = Stats(interval, dataId);
      _inner!.addListener(() => notifyListeners());
    }
  }

  // Don't actually remove the inner stats when the last listener is
  // removed - often its only a resize/redraw before immediately adding a new
  // listener and we don't want to disrupt the recording of stats for this.
  // Not removing means we use a bit more memory than strictly necessary if
  // the user removes an average, until the next restart.

  /// Adds a new value into the history.
  void addValue(V newValue) {
    _inner?.addValue(newValue);
  }

  Stats? get inner => _inner;
}

/// A statistic tracking mean of some property over a time window (and
/// potentially other things like min and max in the future).
class Stats<V extends Value> with ChangeNotifier {
  /// The interval that we store over.
  final StatsInterval interval;

  /// A unique identifier for the data being tracked.
  final String dataId;

  /// The times of values added into the accumulator.
  final Queue<DateTime> _expiries;

  /// A class to accumulate data over an interval.
  final ValueAccumulator<V> _accumulator;

  /// The average value, if any data is valid in the window.
  V? _mean;

  /// A timer to remove the next expiring value.
  Timer? _timer;

  Stats(this.interval, this.dataId)
    : _expiries = Queue(),
      _accumulator = ValueAccumulator.forType(V) as ValueAccumulator<V>;

  /// Adds a new value into the statistics.
  void addValue(final V newValue) {
    final now = clock.now();
    final expiry = now.add(interval.duration);
    _expiries.add(expiry);
    _accumulator.add(newValue);
    // Only add an expiry timer if we don't already have one running.
    _timer ??= Timer(interval.duration, () => _handleTimer());
    // Update the average and notify listeners.
    _mean = _accumulator.mean();
    notifyListeners();
  }

  /// Handles a timer to remove a value, always starting a new timer if there are values
  /// remaining to expire.
  void _handleTimer() {
    final now = clock.now();
    bool removedEntries = false;
    // Don't rely on this timer having fired at the correct time. Always remove everying that
    // has expired or is close to expiry.
    while (_expiries.isNotEmpty && _expiries.first.isBefore(now.add(_removalTolerance))) {
      _expiries.removeFirst();
      _accumulator.removeFirst();
      removedEntries = true;
    }
    // And add the next timer if there is still more stuff to expire.
    if (_expiries.isEmpty) {
      _timer = null;
    } else {
      _timer = Timer(_expiries.first.difference(now), () => _handleTimer());
    }
    // Update our tracked average and notify listeners is anything changed.
    if (removedEntries) {
      _mean = _accumulator.mean();
      notifyListeners();
    }
  }

  /// The average value over the window, if it exists
  V? get mean => _mean;

  /// The most recent value in the window, if it exists
  V? get last => _accumulator.last();
}
