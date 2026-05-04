// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/specs.dart';
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
