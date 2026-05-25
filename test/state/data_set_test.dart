// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

DataSet _makeDataSet(
  SharedPreferences prefs, {
  DerivedDataSettings? derivedSettings,
  AlarmSettings? alarmSettings,
}) {
  return DataSet(
    NetworkSettings(prefs),
    derivedSettings ?? DerivedDataSettings(prefs),
    alarmSettings ?? AlarmSettings(prefs),
    HistoryManagerImpl(prefs),
  );
}

BoundValue<SingleValue<double>> _depthMeters(double meters) {
  return BoundValue(Source.network, Property.depthWithOffset, SingleValue(meters));
}

// A valid derived spec: offset depth in feet using the add operation.
DerivedDataSpec _depthSpec(String name) =>
    DerivedDataSpec(name, 'network', 'depthWithOffset', 'feet', 'add', 1.0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataSet default pages', () {
    test('all cells reference valid elements', () async {
      final prefs = await _prefs();
      final defaultJson = await File('assets/default_pages.json').readAsString();
      final pageSettings = PageSettings(prefs, defaultJson);
      final dataSet = _makeDataSet(prefs);

      expect(pageSettings.dataPageSpecs, isNotEmpty);
      for (final page in pageSettings.dataPageSpecs) {
        for (final cell in page.cells) {
          final source = Source.fromString(cell.source);
          expect(
            source,
            isNotNull,
            reason: '"${cell.source}" in page "${page.name}" is not a valid source',
          );
          expect(
            dataSet.find(source!, cell.element),
            isNotNull,
            reason: '"${cell.source}:${cell.element}" in page "${page.name}" not found in dataset',
          );
        }
      }
    });
  });

  group('DataSet structure', () {
    test('sources contains all three source types', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.sources.containsKey(Source.network), isTrue);
      expect(dataSet.sources.containsKey(Source.local), isTrue);
      expect(dataSet.sources.containsKey(Source.derived), isTrue);
    });

    test('all network properties are present', () async {
      final dataSet = _makeDataSet(await _prefs());
      for (final property in Property.values) {
        if (property.sources.contains(Source.network)) {
          expect(
            dataSet.find(Source.network, property.name),
            isNotNull,
            reason: '${property.name} should be findable in network source',
          );
        }
      }
    });

    test('all local properties are present', () async {
      final dataSet = _makeDataSet(await _prefs());
      for (final property in Property.values) {
        if (property.sources.contains(Source.local)) {
          expect(
            dataSet.find(Source.local, property.name),
            isNotNull,
            reason: '${property.name} should be findable in local source',
          );
        }
      }
    });
  });

  group('DataSet find()', () {
    test('returns element for known network property', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.find(Source.network, 'depthWithOffset'), isNotNull);
    });

    test('returns null for unknown element name', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.find(Source.network, 'doesNotExist'), isNull);
    });
  });

  group('DataSet derived data', () {
    test('valid spec creates a derived element', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      derived.replaceElements([_depthSpec('Offset Depth')]);
      expect(dataSet.find(Source.derived, 'Offset Depth'), isNotNull);
    });

    test('spec with unknown element name is skipped', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      derived.replaceElements([
        DerivedDataSpec('Bad', 'network', 'noSuchElement', 'feet', 'add', 0.0),
      ]);
      expect(dataSet.sources[Source.derived], isEmpty);
    });

    test('spec with unknown operation is skipped', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      derived.replaceElements([
        DerivedDataSpec('Bad', 'network', 'depthWithOffset', 'feet', 'noSuchOp', 0.0),
      ]);
      expect(dataSet.sources[Source.derived], isEmpty);
    });

    test('spec with derived input source is rejected', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      derived.replaceElements([
        DerivedDataSpec('Bad', 'derived', 'someElement', 'feet', 'add', 0.0),
      ]);
      expect(dataSet.sources[Source.derived], isEmpty);
    });

    test('derived elements rebuild when specs change', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);

      derived.replaceElements([_depthSpec('Offset Depth')]);
      expect(dataSet.find(Source.derived, 'Offset Depth'), isNotNull);

      derived.replaceElements([]);
      expect(dataSet.find(Source.derived, 'Offset Depth'), isNull);
    });

    test('spec referencing a non-double input source is skipped', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      // gpsPosition is DoubleValue<double>, not SingleValue<double>.
      derived.replaceElements([
        DerivedDataSpec('Bad', 'network', 'gpsPosition', 'degMin', 'add', 0.0),
      ]);
      expect(dataSet.sources[Source.derived], isEmpty);
    });

    test('spec referencing a non-simple format is skipped', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      // crossTrackError is SingleValue<double> but uses CustomNumericFormatter,
      // not SimpleSvdFormatter.
      derived.replaceElements([
        DerivedDataSpec('Bad', 'network', 'crossTrackError', 'feet', 'add', 0.0),
      ]);
      expect(dataSet.sources[Source.derived], isEmpty);
    });

    test('DataSet notifies its own listeners when derived settings change', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived);
      int count = 0;
      dataSet.addListener(() => count++);
      derived.replaceElements([_depthSpec('Offset Depth')]);
      expect(count, 1);
    });
  });

  group('DataSet computed source', () {
    test('computed source is registered and non-empty', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.sources.containsKey(Source.computed), isTrue);
      expect(dataSet.sources[Source.computed], isNotEmpty);
    });

    test('vmgWind element is findable', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.find(Source.computed, Property.vmgWind.name), isNotNull);
    });

    test('vmgWaypoint element is findable', () async {
      final dataSet = _makeDataSet(await _prefs());
      expect(dataSet.find(Source.computed, Property.vmgWaypoint.name), isNotNull);
    });
  });

  group('DataSet alarm binding', () {
    AlarmSpec depthAlarmSpec({double? min, double? max, String type = 'caution'}) {
      return AlarmSpec('network', 'depthWithOffset', type, 'feet', min: min, max: max);
    }

    test('valid alarm spec attaches to the matching element', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, alarmSettings: alarms);
      alarms.replaceElements([depthAlarmSpec(min: 10.0)]);

      final element = dataSet.find(Source.network, 'depthWithOffset') as WithAlarms;
      expect(element.alarmState.level, isNull);

      // 5 feet is below the 10 ft min, so the alarm should trigger.
      (element as DataElement).updateValue(_depthMeters(5.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);

      // Updating to a value inside the safe range clears the alarm.
      (element as DataElement).updateValue(_depthMeters(50.0 / metersToFeet));
      expect(element.alarmState.level, isNull);
    });

    test('alarm with unknown element is silently ignored', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, alarmSettings: alarms);
      // Mix a bad spec with a valid one and confirm the valid one still binds.
      alarms.replaceElements([
        AlarmSpec('network', 'doesNotExist', 'caution', 'feet', min: 10.0),
        depthAlarmSpec(min: 10.0),
      ]);

      final element = dataSet.find(Source.network, 'depthWithOffset') as WithAlarms;
      (element as DataElement).updateValue(_depthMeters(5.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);
    });

    test('alarm on a non-WithAlarms element is silently ignored', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      // The 'variation' element is a plain ConsistentDataElement and does not
      // have the WithAlarms mixin, so a valid Alarm.fromSpec for it must be
      // skipped at bind time. Pair it with a valid alarm to ensure binding of
      // other alarms still proceeds.
      alarms.replaceElements([
        AlarmSpec('network', 'variation', 'caution', 'degrees', min: -30.0),
        depthAlarmSpec(min: 10.0),
      ]);
      // Should not throw and the depth alarm should still be active.
      final element =
          _makeDataSet(prefs, alarmSettings: alarms).find(Source.network, 'depthWithOffset')
              as WithAlarms;
      (element as DataElement).updateValue(_depthMeters(5.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);
    });

    test('spec that fails Alarm.fromSpec is silently ignored', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, alarmSettings: alarms);
      // 'badFormat' is not a valid format for depth - fromSpec throws.
      alarms.replaceElements([
        AlarmSpec('network', 'depthWithOffset', 'caution', 'badFormat', min: 10.0),
        depthAlarmSpec(max: 100.0),
      ]);
      final element = dataSet.find(Source.network, 'depthWithOffset') as WithAlarms;
      (element as DataElement).updateValue(_depthMeters(200.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);
    });

    test('changing AlarmSettings rebinds alarms', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, alarmSettings: alarms);
      final element = dataSet.find(Source.network, 'depthWithOffset') as WithAlarms;

      alarms.replaceElements([depthAlarmSpec(min: 10.0)]);
      (element as DataElement).updateValue(_depthMeters(5.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);

      // Removing the spec must clear the binding (and therefore the active level).
      alarms.replaceElements([]);
      expect(element.alarmState.level, isNull);
    });

    test('changing DerivedDataSettings also rebinds alarms', () async {
      final prefs = await _prefs();
      final derived = DerivedDataSettings(prefs);
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, derivedSettings: derived, alarmSettings: alarms);
      alarms.replaceElements([depthAlarmSpec(min: 10.0)]);

      final element = dataSet.find(Source.network, 'depthWithOffset') as WithAlarms;
      (element as DataElement).updateValue(_depthMeters(5.0 / metersToFeet));
      expect(element.alarmState.level, AlarmLevel.caution);

      // A derived-data change triggers _createAndBindAlarms; the alarm should
      // remain bound and active afterwards.
      derived.replaceElements([_depthSpec('Offset Depth')]);
      expect(element.alarmState.level, AlarmLevel.caution);
    });

    test('DataSet notifies its own listeners when alarm settings change', () async {
      final prefs = await _prefs();
      final alarms = AlarmSettings(prefs);
      final dataSet = _makeDataSet(prefs, alarmSettings: alarms);
      int count = 0;
      dataSet.addListener(() => count++);
      alarms.replaceElements([depthAlarmSpec(min: 10.0)]);
      expect(count, 1);
    });
  });
}
