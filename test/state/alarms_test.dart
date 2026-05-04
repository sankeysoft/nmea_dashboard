// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/foundation.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

final _staleness = Staleness(const Duration(seconds: 30));

/// DataElement debounces notifications within an 800 ms freshness window.
/// Sleep slightly longer between successive pushes so each one fires.
Future<void> _afterFreshness() => Future.delayed(const Duration(milliseconds: 850));

class _FakeRegistry with ChangeNotifier implements AlarmRegistry {
  final List<AlarmSpec> specs = [];

  @override
  Iterable<AlarmSpec> get alarmSpecs => specs;

  void replace(List<AlarmSpec> newSpecs) {
    specs
      ..clear()
      ..addAll(newSpecs);
    notifyListeners();
  }
}

class _NoopNotifier with ChangeNotifier {}

ConsistentDataElement<SingleValue<double>> _makeDepthElement() {
  return ConsistentDataElement.newForProperty(Source.network, Property.depthWithOffset, _staleness)
      as ConsistentDataElement<SingleValue<double>>;
}

void _push(DataElement<SingleValue<double>, SingleValue<double>> element, double meters) {
  element.updateValue(BoundValue(Source.network, element.property, SingleValue(meters)));
}

void main() {
  group('AlarmComparison', () {
    test('above triggers when current exceeds threshold', () {
      expect(AlarmComparison.above.test(11.0, 10.0), true);
      expect(AlarmComparison.above.test(10.0, 10.0), false);
      expect(AlarmComparison.above.test(9.0, 10.0), false);
    });

    test('below triggers when current is under threshold', () {
      expect(AlarmComparison.below.test(9.0, 10.0), true);
      expect(AlarmComparison.below.test(10.0, 10.0), false);
      expect(AlarmComparison.below.test(11.0, 10.0), false);
    });

    test('fromString round-trips enum names', () {
      expect(AlarmComparison.fromString('above'), AlarmComparison.above);
      expect(AlarmComparison.fromString('below'), AlarmComparison.below);
      expect(AlarmComparison.fromString('sideways'), isNull);
      expect(AlarmComparison.fromString(null), isNull);
    });
  });

  group('AlarmManager', () {
    late _FakeRegistry registry;
    late _NoopNotifier dataNotifier;
    late ConsistentDataElement<SingleValue<double>> depth;
    late ElementLookup lookup;

    setUp(() {
      registry = _FakeRegistry();
      dataNotifier = _NoopNotifier();
      depth = _makeDepthElement();
      lookup = (source, name) {
        if (source == Source.network && name == Property.depthWithOffset.name) {
          return depth;
        }
        return null;
      };
    });

    AlarmSpec depthBelowFt(double feet, {bool audible = false, bool enabled = true, SpecKey? key}) {
      return AlarmSpec(
        'Shallow',
        Source.network.name,
        Property.depthWithOffset.name,
        'feet',
        AlarmComparison.below.name,
        feet,
        audible: audible,
        enabled: enabled,
        key: key,
      );
    }

    test('starts inactive when no value present', () {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      expect(manager.triggered, isEmpty);
      expect(manager.audible, isEmpty);
    });

    test('transitions inactive → active when condition met', () {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      // 40 ft = 12.192 m. Push something below that to trigger.
      _push(depth, 10.0);
      expect(manager.triggered.length, 1);
      expect(manager.triggered.first.state, AlarmState.active);
    });

    test('respects display unit conversion', () async {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      // 40 ft ≈ 12.19 m. 12.5 m is above threshold (in feet), so no alarm.
      _push(depth, 12.5);
      expect(manager.triggered, isEmpty);

      await _afterFreshness();
      // 11.0 m ≈ 36 ft, well below threshold.
      _push(depth, 11.0);
      expect(manager.triggered.length, 1);
    });

    test('transitions active → inactive when condition clears', () async {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      _push(depth, 10.0);
      expect(manager.triggered.length, 1);

      await _afterFreshness();
      _push(depth, 20.0);
      expect(manager.triggered, isEmpty);
    });

    test('silence moves active → silenced; visual stays, audible drops', () {
      final spec = depthBelowFt(40.0, audible: true);
      registry.specs.add(spec);
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      _push(depth, 10.0);
      expect(manager.audible.length, 1);

      manager.silence(spec.key);
      expect(manager.triggered.length, 1);
      expect(manager.triggered.first.state, AlarmState.silenced);
      expect(manager.audible, isEmpty);
    });

    test('silenced → inactive when condition clears, then re-arms on re-trigger', () async {
      final spec = depthBelowFt(40.0, audible: true);
      registry.specs.add(spec);
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      _push(depth, 10.0);
      manager.silence(spec.key);
      expect(manager.triggered.first.state, AlarmState.silenced);

      await _afterFreshness();
      // Recover: silenced → inactive.
      _push(depth, 20.0);
      expect(manager.triggered, isEmpty);

      await _afterFreshness();
      // Re-trigger: should be active again, audible re-armed.
      _push(depth, 10.0);
      expect(manager.triggered.first.state, AlarmState.active);
      expect(manager.audible.length, 1);
    });

    test('disabled spec is ignored', () {
      registry.specs.add(depthBelowFt(40.0, enabled: false));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      _push(depth, 5.0);
      expect(manager.triggered, isEmpty);
    });

    test('isElementInAlarm reports highlighted source/element', () {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      _push(depth, 10.0);
      expect(
        manager.isElementInAlarm(Source.network.name, Property.depthWithOffset.name),
        true,
      );
      expect(manager.isElementInAlarm(Source.network.name, 'speedOverGround'), false);
      expect(manager.isElementInAlarm(Source.local.name, Property.depthWithOffset.name), false);
    });

    test('rebuild on registry change preserves silenced state of unrelated alarms', () {
      final shallow = depthBelowFt(40.0, audible: true);
      registry.specs.add(shallow);
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );

      _push(depth, 10.0);
      manager.silence(shallow.key);
      expect(manager.triggered.first.state, AlarmState.silenced);

      // Add a second unrelated alarm; the existing silenced alarm must not
      // revert to active.
      final critical = depthBelowFt(20.0);
      registry.replace([shallow, critical]);
      final shallowAfter = manager.triggered.firstWhere((t) => t.spec.key == shallow.key);
      expect(shallowAfter.state, AlarmState.silenced);
    });

    test('listeners fire on state changes', () async {
      registry.specs.add(depthBelowFt(40.0));
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      int events = 0;
      manager.addListener(() => events++);

      _push(depth, 10.0);
      expect(events, greaterThanOrEqualTo(1));

      await _afterFreshness();
      final before = events;
      _push(depth, 20.0);
      expect(events, greaterThan(before));
    });

    test('skips spec with unknown source', () {
      registry.specs.add(
        AlarmSpec(
          'broken',
          'somethingWrong',
          Property.depthWithOffset.name,
          'feet',
          'below',
          40.0,
        ),
      );
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      _push(depth, 5.0);
      expect(manager.triggered, isEmpty);
    });

    test('skips spec with unknown comparison', () {
      registry.specs.add(
        AlarmSpec(
          'broken',
          Source.network.name,
          Property.depthWithOffset.name,
          'feet',
          'sideways',
          40.0,
        ),
      );
      final manager = AlarmManager(
        registry: registry,
        lookup: lookup,
        dataNotifier: dataNotifier,
      );
      _push(depth, 5.0);
      expect(manager.triggered, isEmpty);
    });
  });
}
