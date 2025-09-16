// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_stats.dart';
import 'package:nmea_dashboard/state/formatting.dart';
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
/// In the asbstract case the type of input data (U) may not match the type of
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
    if (property.dimension.type == SingleValue<double>) {
      // Create a different subclass with history when possible.
      return SingleValueDoubleConsistentDataElement(source, property, staleness);
    } else if (property.dimension.type == SingleValue<DateTime>) {
      return ConsistentDataElement<SingleValue<DateTime>>(source, property, staleness);
    } else if (property.dimension.type == DoubleValue<double>) {
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
  void registerManager(HistoryManager manager) {
    for (final history in _histories.values) {
      history.registerManager(manager);
    }
  }

  /// Returns the history for the supplied interval.
  OptionalHistory history(HistoryInterval interval) {
    return _histories[interval]!;
  }
}

mixin WithStats<V extends Value, U extends Value> on DataElement<V, U> {
  late final Map<StatsInterval, OptionalStats<V>> _stats = Map.fromEntries(
    StatsInterval.values.map((i) => MapEntry(i, OptionalStats<V>(i, id))),
  );

  /// Records a new value into all active stats.
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

class SingleValueDoubleConsistentDataElement extends ConsistentDataElement<SingleValue<double>>
    with WithHistory, WithStats {
  SingleValueDoubleConsistentDataElement(super.source, super.property, super.staleness);

  @override
  bool updateValue(final BoundValue<SingleValue<double>> newValue) {
    final accepted = super.updateValue(newValue);
    if (accepted) {
      addStatsValue(newValue.value);
      addHistoryValue(newValue.value);
    }
    return accepted;
  }
}

/// A special case element for displaying bearings using a reference variation
class BearingDataElement extends DataElement<AugmentedBearing, SingleValue<double>>
    with WithHistory, WithStats {
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
    }
    return accepted;
  }

  @override
  AugmentedBearing convertValue(SingleValue<double> newValue) {
    // Just store the variation each time we receive a new bearing. This means
    // we can't update the output if the variation changes without bearing
    // updates but since variation changes far less frequently thats unlikely
    // to be a problem.
    return AugmentedBearing(newValue, variation.value);
  }
}

/// A DataElement whose value is derived from some other value.
class DerivedDataElement extends DataElement<SingleValue<double>, SingleValue<double>>
    with WithHistory, WithStats {
  final String _name;
  final DataElement<SingleValue<double>, Value> _sourceElement;
  final ConvertingFormatter _formatter;
  final Operation _operation;
  final double _operand;

  DerivedDataElement(
    this._name,
    this._sourceElement,
    this._formatter,
    this._operation,
    this._operand,
  ) : super(
        '${_name}_from_${_sourceElement.id}',
        _sourceElement.property,
        /* No staleness, source will notify on invalid */ null,
      ) {
    // Update self when the sourceElement sends a notification.
    _sourceElement.addListener(() {
      final sourceValue = _sourceElement.value;
      final sourceConverted = _formatter.toNumber(sourceValue);
      // Convert the source value to the target units and check its not null
      if (sourceConverted == null) {
        invalidateValue();
      } else {
        // Apply the operation then convert back to the native units for its
        // dimension.
        final derivedConverted = _operation.apply(sourceConverted, _operand);
        updateValue(
          BoundValue(
            Source.derived,
            _sourceElement.property,
            _formatter.fromNumber(derivedConverted),
          ),
        );
      }
    });
  }

  @override
  bool updateValue(final BoundValue<SingleValue<double>> newValue) {
    final accepted = super.updateValue(newValue);
    if (accepted && _value != null) {
      addStatsValue(_value!);
      addHistoryValue(_value!);
    }
    return accepted;
  }

  @override
  SingleValue<double> convertValue(SingleValue<double> newValue) {
    return newValue;
  }

  @override
  String get shortName => _name;

  @override
  String get longName => _name;
}
