// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data/data_element_history.dart';
import 'package:nmea_dashboard/state/data/data_set.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

DataSet _makeDataSet(SharedPreferences prefs, {DerivedDataSettings? derivedSettings}) {
  return DataSet(
    NetworkSettings(prefs),
    derivedSettings ?? DerivedDataSettings(prefs),
    HistoryManagerImpl(prefs),
  );
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
  });
}
