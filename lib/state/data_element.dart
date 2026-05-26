// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/alarms.dart';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_stats.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/values.dart';

/// The shortest time between triggering updates on an element.
const _freshnessLimit = Duration(milliseconds: 800);

/// A simple wrapper so many elements can share the same staleness timer.
class Staleness {
  Duration duration;
  Staleness(this.duration);
}

/// A single element of marine data based on a history of some data. The value
/// may change over time based on supplied inputs and may at times be invalid.
/// In the abstract case the type of input data (U) may not match the type of
/// stored data (V).
abstract class DataElement<V extends Value, U extends Value> with ChangeNotifier {
  /// This class's logger.
  static final _log = Logger('DataElement');

  /// A unique and developer readable string to identify this data element.
  final String id;

  /// The property we expect for incoming values.
  final Property property;

  /// The type of the values we store. Note this might be different
  /// than the types of values we accept (i.e. U)
  final Type storedType = V;

  /// The type of the values we accept as input. Note this might be different
  /// than the types of values we store (i.e. V)
  final Type inputType = U;

  /// The time from last update before the data is considered invalid.
  Staleness? staleness;

  /// A timer until the data is invalidated.
  Timer? stalenessTimer;

  /// A timer since the last update
  final Stopwatch lastUpdateStopwatch = Stopwatch();

  /// The most recent valid data accepted by this element.
  V? _value;

  /// The tier most recently accepted by this element, even if no longer valid.
  int? _tier;

  DataElement(this.id, this.property, this.staleness);

  /// A long name for the element, suitable for picking from a list.
  String get longName => property.longName;

  /// A short name for the element, suitable for use as a heading.
  String get shortName => property.shortName;

  /// The current value of the element.
  V? get value => _value;

  /// The current tier of the element.
  int? get tier => _tier;

  /// Invalidates the value held by this element.
  void invalidateValue() {
    if (_value != null) {
      lastUpdateStopwatch.stop();
      _value = null;
      notifyListeners();
    }
    stalenessTimer?.cancel();
    stalenessTimer = null;
  }

  /// Updates the value held by this element, returning true if the new value
  /// was accepted.
  bool updateValue(final BoundValue<U> newValue) {
    if (newValue.property != property) {
      throw InvalidTypeException(
        'Tried to update $property DataElement with ${newValue.property} value',
      );
    }
    // Record if this value causes us to change tier and discard worse data if
    // better tier data is still valid
    if (_tier != null && newValue.tier < _tier!) {
      _log.info('Upgrading $property from tier $_tier to tier ${newValue.tier}');
    } else if (_tier != null && newValue.tier > _tier!) {
      if (_value != null) {
        // Ignore any lower tier data we receive if better data is still valid.
        return false;
      }
      _log.warning('Downgrading $property from tier $_tier to tier ${newValue.tier}');
    }
    _tier = newValue.tier;

    // Set a new timer to invalidate this element if no new data is received,
    // replacing any previous timer.
    stalenessTimer?.cancel();
    if (staleness != null) {
      stalenessTimer = Timer(staleness!.duration, () => invalidateValue());
    }

    // Convert and store the new value and notify on change.
    final V newStoredValue = convertValue(newValue.value);
    if (newStoredValue != _value) {
      _value = newStoredValue;
      if (lastUpdateStopwatch.isRunning && lastUpdateStopwatch.elapsed < _freshnessLimit) {
        // If the value already changed recently don't fire listeners.
      } else {
        lastUpdateStopwatch.reset();
        lastUpdateStopwatch.start();
        notifyListeners();
      }
    }
    return true;
  }

  /// Converts an input value to a stored value.
  V convertValue(final U newValue);
}

/// A DataElement where the input type matches the storage type.
class ConsistentDataElement<V extends Value> extends DataElement<V, V> {
  ConsistentDataElement(Source source, property, staleness)
    : super('${source.name}_${property.name}', property, staleness);
  static ConsistentDataElement newForProperty(
    Source source,
    Property property,
    Staleness staleness,
  ) {
    // Hideousness to deal with Dart's crappy type system.
    if (property.dimension.storageType == SingleValue<double>) {
      // Create a different subclass with history when possible.
      return SingleValueDoubleConsistentDataElement(source, property, staleness);
    } else if (property.dimension.storageType == SingleValue<DateTime>) {
      return ConsistentDataElement<SingleValue<DateTime>>(source, property, staleness);
    } else if (property.dimension.storageType == DoubleValue<double>) {
      return ConsistentDataElement<DoubleValue<double>>(source, property, staleness);
    } else {
      throw InvalidTypeException(
        "Cannot create Element with unknown runtime type ${property.dimension}",
      );
    }
  }

  @override
  V convertValue(V newValue) {
    return newValue;
  }
}

mixin WithHistory<V extends Value, U extends Value> on DataElement<V, U> {
  late final Map<HistoryInterval, OptionalHistory<V>> _histories = Map.fromEntries(
    HistoryInterval.values.map((i) => MapEntry(i, OptionalHistory<V>(i, id))),
  );

  /// Records a new value into all active histories.
  void addHistoryValue(final V newValue) {
    for (final history in _histories.values) {
      history.addValue(newValue);
    }
  }

  /// Notifies all histories of the supplied manager.
  /// Guaranteed to be called before histories are used.
  void registerHistoryManager(HistoryManager manager) {
    for (final history in _histories.values) {
      history.registerManager(manager);
    }
  }

  /// Returns the history for the supplied interval.
  OptionalHistory history(HistoryInterval interval) {
    return _histories[interval]!;
  }
}

// A DataElement that is capable of averaging its values over time.
mixin WithStats<V extends Value, U extends Value> on DataElement<V, U> {
  late final Map<StatsInterval, OptionalStats<V>> _stats = Map.fromEntries(
    StatsInterval.values.map((i) => MapEntry(i, OptionalStats<V>(i, id))),
  );

  /// Records a new value into all active stats and check for changes in alarm state.
  void addStatsValue(final V newValue) {
    for (final stats in _stats.values) {
      stats.addValue(newValue);
    }
  }

  /// Returns the stats for the supplied interval.
  OptionalStats stats(StatsInterval interval) {
    return _stats[interval]!;
  }
}

enum _AlarmUpdateType { all, currentValue, singleStatistic }

// A DataElement that is capable of monitoring alarms against the current and averaging values.
mixin WithAlarms<V extends Value, U extends Value> on DataElement<V, U> {
  /// The list of registered alarms for this element.
  final List<Alarm> _alarms = [];

  /// The map of currently registered statistics callbacks.
  final Map<OptionalStats, VoidCallback> _statsCallbacks = {};

  /// The most critical alarm state for this element.
  final AlarmState _alarmState = AlarmState();

  /// A manager that we notify of
  late AlarmManager _alarmManager;

  /// Registers a manager that will be used to persist and communicate alarms.
  /// Guaranteed to be called before any alarms are added.
  void registerAlarmManager(AlarmManager manager) {
    _alarmManager = manager;
  }

  /// Clear all alarms on this DataElement.
  void clearAlarms() {
    for (final entry in _statsCallbacks.entries) {
      entry.key.removeListener(entry.value);
    }
    _statsCallbacks.clear();
    for (final alarm in _alarms) {
      _alarmManager.clearAlarm(alarm);
    }
    _alarms.clear();
    _alarmState.set(null);
  }

  /// Add a new alarm to this element. Raising an ArgumentError if the type is incompatible.
  void addAlarm(Alarm alarm) {
    if (alarm.property != property) {
      throw ArgumentError("alarm property ${alarm.property} != element property $property");
    } else if (alarm.formatter.valueType != storedType) {
      throw ArgumentError("alarm type ${alarm.formatter.valueType} != element type $storedType");
    }
    if (alarm.averagingInterval != null) {
      if (this is! WithStats) {
        throw ArgumentError("averaging alarm set on element without stats: $longName");
      }
      // Register to be informed about changes in this statistic (unless we did before).
      final stats = (this as WithStats).stats(alarm.averagingInterval!);
      if (!_statsCallbacks.keys.contains(stats)) {
        void callback() => _updateAlarms(
          _AlarmUpdateType.singleStatistic,
          statisticInterval: alarm.averagingInterval,
        );
        _statsCallbacks[stats] = callback;
        stats.addListener(callback);
      }
    }
    _alarms.add(alarm);
    // Sort reversed so we consider higher priority alarms first.
    _alarms.sort((a, b) => b.compareTo(a));
    _updateAlarms(_AlarmUpdateType.all);
  }

  /// Method to be called after a change in the element value.
  void onValueChange() {
    _updateAlarms(_AlarmUpdateType.currentValue);
  }

  void _updateAlarms(_AlarmUpdateType updateType, {StatsInterval? statisticInterval}) {
    AlarmLevel? highestLevel;
    for (final alarm in _alarms) {
      bool? active;
      if (alarm.averagingInterval == null) {
        // Alarm is based on current value. Try to set active based on current state if
        // included in the update request.
        if ({_AlarmUpdateType.currentValue, _AlarmUpdateType.all}.contains(updateType)) {
          // Assess activeness based on the value.
          active = (value == null) ? null : alarm.isTriggered(value!);
        }
      } else {
        // Alarm is based on an average over some statistics interval. Try to set active based
        // on stats if included in the update request.
        if (updateType == _AlarmUpdateType.all ||
            (updateType == _AlarmUpdateType.singleStatistic &&
                statisticInterval == alarm.averagingInterval)) {
          final stats = (this as WithStats).stats(alarm.averagingInterval!);
          final mean = stats.inner?.mean;
          active = (mean == null) ? null : alarm.isTriggered(mean);
        }
      }
      // Inform our manager about the potentially new state.
      if (active == true) {
        _alarmManager.setAlarm(alarm);
      } else if (active == false) {
        _alarmManager.clearAlarm(alarm);
      }
      // If we determined the alarm is currently active or didn't update but the alarm was
      // previously active, include it in the highest level determination.
      if (active == true || (active == null && _alarmManager.activeAlarms.contains(alarm))) {
        if (highestLevel == null) {
          highestLevel = alarm.level;
        } else if (alarm.level > highestLevel) {
          highestLevel = alarm.level;
        }
      }
    }
    _alarmState.set(highestLevel);
  }

  AlarmState get alarmState => _alarmState;
}

class SingleValueDoubleConsistentDataElement extends ConsistentDataElement<SingleValue<double>>
    with WithHistory, WithStats, WithAlarms {
  SingleValueDoubleConsistentDataElement(super.source, super.property, super.staleness);

  @override
  bool updateValue(final BoundValue<SingleValue<double>> newValue) {
    final accepted = super.updateValue(newValue);
    if (accepted) {
      addStatsValue(newValue.value);
      addHistoryValue(newValue.value);
      onValueChange();
    }
    return accepted;
  }
}

/// A special case element for displaying bearings using a reference variation
class BearingDataElement extends DataElement<AugmentedBearing, SingleValue<double>>
    with WithHistory, WithStats, WithAlarms {
  // Only output a log warning for discarding mag heading due to missing
  // variation once each time the condition occurs.
  static bool loggedMissingVariation = false;

  final ConsistentDataElement<SingleValue<double>> variation;

  BearingDataElement(Source source, this.variation, property, staleness)
    : super('${source.name}_${property.name}', property, staleness);

  @override
  bool updateValue(final BoundValue<SingleValue<double>> newValue) {
    late bool accepted;

    /// Handle the special case of the element storing heading, which can
    /// accept either true headings or magnetic headings that it converts.
    if (newValue.property == Property.headingMag && property == Property.heading) {
      final variationValue = variation.value;
      if (variationValue == null) {
        if (!loggedMissingVariation) {
          DataElement._log.warning('Cannot use mag heading while variation is unknown');
          loggedMissingVariation = true;
        }
        return false;
      }
      final trueHeading = (newValue.value.data - variationValue.data) % 360.0;
      accepted = super.updateValue(
        BoundValue(
          newValue.source,
          Property.heading,
          SingleValue<double>(trueHeading),
          tier: newValue.tier,
        ),
      );
      loggedMissingVariation = false;
    } else {
      accepted = super.updateValue(newValue);
    }
    if (accepted && _value != null) {
      addStatsValue(_value!);
      addHistoryValue(_value!);
      onValueChange();
    }
    return accepted;
  }

  @override
  AugmentedBearing convertValue(SingleValue<double> newValue) {
    // Just store the variation each time we receive a new bearing. This means
    // we can't update the output if the variation changes without bearing
    // updates but since variation changes far less frequently thats unlikely
    // to be a problem.
    return AugmentedBearing(newValue.data, variation.value?.data);
  }
}
