// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/specs.dart';

final _log = Logger('Alarms');

/// The runtime status of an individual alarm.
enum AlarmState {
  /// The alarm condition is not currently met.
  inactive,

  /// The condition is met and the alarm is announcing.
  active,

  /// The condition is met but the user dismissed the audible part. Visual
  /// highlighting still applies.
  silenced,
}

/// The comparison operator used by an alarm. Stored on disk as the literal
/// name of the enum value.
enum AlarmComparison {
  above,
  below;

  /// Whether the [current] value triggers the alarm against [threshold].
  bool test(double current, double threshold) {
    switch (this) {
      case AlarmComparison.above:
        return current > threshold;
      case AlarmComparison.below:
        return current < threshold;
    }
  }

  /// Returns a comparison from its unqualified name.
  static AlarmComparison? fromString(String? name) {
    return AlarmComparison.values.asNameMap()[name];
  }
}

/// A read-only registry of alarm specifications.
///
/// Implemented by [AlarmSettings] in production and by light-weight fakes in
/// tests so the [AlarmManager] does not need to depend on shared preferences.
abstract class AlarmRegistry implements Listenable {
  Iterable<AlarmSpec> get alarmSpecs;
}

/// Looks up the data element backing a given source/element pair.
typedef ElementLookup = DataElement? Function(Source source, String element);

/// A snapshot of an alarm that is currently triggered.
class TriggeredAlarm {
  final AlarmSpec spec;
  final AlarmState state;
  TriggeredAlarm(this.spec, this.state);
}

/// Reactive runtime that evaluates alarm conditions across data elements.
///
/// Listens to the supplied [AlarmRegistry] and rebuilds whenever the set of
/// alarms changes, and to [dataNotifier] so it picks up newly created derived
/// elements. For each enabled spec it adds a listener to the corresponding
/// data element and tracks the alarm state.
class AlarmManager with ChangeNotifier {
  final AlarmRegistry _registry;
  final ElementLookup _lookup;
  final Listenable _dataNotifier;
  final Map<SpecKey, _AlarmRuntime> _runtimes = {};

  AlarmManager({
    required AlarmRegistry registry,
    required ElementLookup lookup,
    required Listenable dataNotifier,
  }) : _registry = registry,
       _lookup = lookup,
       _dataNotifier = dataNotifier {
    _rebuild();
    _registry.addListener(_rebuild);
    _dataNotifier.addListener(_rebuild);
  }

  /// Convenience constructor that wires the manager to the public surface
  /// of [DataSet].
  factory AlarmManager.fromDataSet(AlarmRegistry registry, DataSet dataSet) {
    return AlarmManager(registry: registry, lookup: dataSet.find, dataNotifier: dataSet);
  }

  /// Snapshots of all alarms currently in `active` or `silenced` state.
  Iterable<TriggeredAlarm> get triggered => _runtimes.values
      .where((r) => r.state != AlarmState.inactive)
      .map((r) => TriggeredAlarm(r.spec, r.state));

  /// Snapshots of all alarms currently in `active` state with audible enabled.
  Iterable<TriggeredAlarm> get audible => _runtimes.values
      .where((r) => r.state == AlarmState.active && r.spec.audible)
      .map((r) => TriggeredAlarm(r.spec, r.state));

  /// True if any triggered alarm watches the supplied source/element pair.
  bool isElementInAlarm(String source, String element) {
    return _runtimes.values.any(
      (r) =>
          r.state != AlarmState.inactive && r.spec.source == source && r.spec.element == element,
    );
  }

  /// Silences the audible part of the named alarm. Visual highlighting and
  /// internal `silenced` state remain until the condition clears.
  void silence(SpecKey key) {
    _runtimes[key]?.silence();
  }

  void _rebuild() {
    // Capture old states so unrelated config changes don't wipe a silenced
    // alarm's user intent.
    final preservedStates = <SpecKey, AlarmState>{};
    for (final entry in _runtimes.entries) {
      preservedStates[entry.key] = entry.value.state;
      entry.value.dispose();
    }
    _runtimes.clear();

    for (final spec in _registry.alarmSpecs) {
      if (!spec.enabled) continue;

      final source = Source.fromString(spec.source);
      if (source == null) {
        _log.warning('Alarm "${spec.name}" references unknown source ${spec.source}');
        continue;
      }
      final element = _lookup(source, spec.element);
      if (element == null) {
        _log.warning(
          'Alarm "${spec.name}" references unknown element ${spec.source}:${spec.element}',
        );
        continue;
      }
      final formatter = formattersFor(element.property.dimension)[spec.format];
      if (formatter is! NumericFormatter) {
        _log.warning('Alarm "${spec.name}" has non-numeric format ${spec.format}');
        continue;
      }
      final comparison = AlarmComparison.fromString(spec.comparison);
      if (comparison == null) {
        _log.warning('Alarm "${spec.name}" has invalid comparison ${spec.comparison}');
        continue;
      }

      _runtimes[spec.key] = _AlarmRuntime(
        spec: spec,
        element: element,
        formatter: formatter,
        comparison: comparison,
        seedState: preservedStates[spec.key] ?? AlarmState.inactive,
        onChange: notifyListeners,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _registry.removeListener(_rebuild);
    _dataNotifier.removeListener(_rebuild);
    for (final r in _runtimes.values) {
      r.dispose();
    }
    _runtimes.clear();
    super.dispose();
  }
}

class _AlarmRuntime {
  final AlarmSpec spec;
  final DataElement _element;
  final NumericFormatter _formatter;
  final AlarmComparison _comparison;
  final VoidCallback _onChange;
  AlarmState _state;
  late final VoidCallback _listener;

  _AlarmRuntime({
    required this.spec,
    required DataElement element,
    required NumericFormatter formatter,
    required AlarmComparison comparison,
    required AlarmState seedState,
    required VoidCallback onChange,
  }) : _element = element,
       _formatter = formatter,
       _comparison = comparison,
       _onChange = onChange,
       _state = seedState {
    _listener = _evaluate;
    _element.addListener(_listener);
    // Re-evaluate immediately against the current value. Seeded state survives
    // only if the condition still holds.
    _evaluate();
  }

  AlarmState get state => _state;

  void _evaluate() {
    final value = _element.value;
    bool conditionMet = false;
    if (value != null) {
      // Formatter is generic over the element's storage type. Lookup happens
      // through the element's dimension which guarantees the types align.
      final number = _formatter.toNumber(value);
      if (number is double) {
        conditionMet = _comparison.test(number, spec.threshold);
      }
    }

    final AlarmState newState;
    if (!conditionMet) {
      // Stale data or back in safe range collapses to inactive, which also
      // re-arms an audible re-trigger when the condition next holds.
      newState = AlarmState.inactive;
    } else if (_state == AlarmState.silenced) {
      newState = AlarmState.silenced;
    } else {
      newState = AlarmState.active;
    }

    if (newState != _state) {
      _state = newState;
      _onChange();
    }
  }

  void silence() {
    if (_state == AlarmState.active) {
      _state = AlarmState.silenced;
      _onChange();
    }
  }

  void dispose() {
    _element.removeListener(_listener);
  }
}
