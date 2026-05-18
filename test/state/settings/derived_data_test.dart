// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _derivedDataSpecJson =
    '[{"name":"d1","inputSource":"network","inputElement":"depth","inputFormat":"feet","operation":"+","operand":1.5}]';

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Satisfy the wakelock Pigeon channel so setKeepScreenAwake() doesn't throw.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  test('starts empty when prefs are empty', () async {
    expect(DerivedDataSettings(await _prefs()).derivedDataSpecs, isEmpty);
  });

  test('loads specs from prefs on construction', () async {
    final s = DerivedDataSettings(await _prefs({'derived_v1': _derivedDataSpecJson}));
    final specs = s.derivedDataSpecs.toList();
    expect(specs.length, 1);
    expect(specs[0].name, 'd1');
    expect(specs[0].inputSource, 'network');
    expect(specs[0].operation, '+');
    expect(specs[0].operand, 1.5);
  });

  test('starts empty when prefs contain invalid JSON', () async {
    expect(DerivedDataSettings(await _prefs({'derived_v1': 'not json'})).derivedDataSpecs, isEmpty);
  });

  test('starts empty when prefs contain non-list JSON', () async {
    expect(DerivedDataSettings(await _prefs({'derived_v1': '{"a":1}'})).derivedDataSpecs, isEmpty);
  });

  test('setElement adds a spec, persists, and notifies', () async {
    final p = await _prefs();
    final s = DerivedDataSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setElement(DerivedDataSpec('d1', 'network', 'depth', 'feet', '+', 1.0));
    expect(s.derivedDataSpecs.length, 1);
    expect(s.derivedDataSpecs.first.name, 'd1');
    expect(p.getString('derived_v1'), isNotNull);
    expect(count, 1);
  });

  test('setElement replaces a spec with the same key', () async {
    final s = DerivedDataSettings(await _prefs());
    final spec = DerivedDataSpec('original', 'network', 'depth', 'feet', '+', 1.0);
    s.setElement(spec);
    s.setElement(DerivedDataSpec('updated', 'network', 'depth', 'feet', '+', 2.0, key: spec.key));
    expect(s.derivedDataSpecs.length, 1);
    expect(s.derivedDataSpecs.first.name, 'updated');
  });

  test('removeElement removes a spec, persists, and notifies', () async {
    final s = DerivedDataSettings(await _prefs());
    final spec = DerivedDataSpec('d1', 'network', 'depth', 'feet', '+', 1.0);
    s.setElement(spec);
    int count = 0;
    s.addListener(() => count++);
    s.removeElement(spec);
    expect(s.derivedDataSpecs, isEmpty);
    expect(count, 1);
  });

  test('replaceElements replaces all specs, persists, and notifies', () async {
    final s = DerivedDataSettings(await _prefs());
    s.setElement(DerivedDataSpec('old', 'network', 'depth', 'feet', '+', 1.0));
    int count = 0;
    s.addListener(() => count++);
    s.replaceElements([
      DerivedDataSpec('new1', 'network', 'speed', 'knots', '*', 2.0),
      DerivedDataSpec('new2', 'network', 'wind', 'degrees', '+', 5.0),
    ]);
    final specs = s.derivedDataSpecs.toList();
    expect(specs.length, 2);
    expect(specs[0].name, 'new1');
    expect(specs[1].name, 'new2');
    expect(count, 1);
  });

  test('useClipboard with valid JSON replaces specs, persists, and notifies', () async {
    final s = DerivedDataSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard(_derivedDataSpecJson), isTrue);
    expect(s.derivedDataSpecs.length, 1);
    expect(count, 1);
  });

  test('useClipboard with invalid JSON makes no changes', () async {
    final s = DerivedDataSettings(await _prefs());
    s.setElement(DerivedDataSpec('existing', 'network', 'depth', 'feet', '+', 1.0));
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard('not json'), isFalse);
    expect(s.derivedDataSpecs.length, 1);
    expect(count, 0);
  });

  test('useClipboard with dryRun validates but makes no changes', () async {
    final s = DerivedDataSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard(_derivedDataSpecJson, dryRun: true), isTrue);
    expect(s.derivedDataSpecs, isEmpty);
    expect(count, 0);
  });

  test('toJson round-trips through construction', () async {
    final s1 = DerivedDataSettings(await _prefs());
    s1.setElement(DerivedDataSpec('d1', 'network', 'depth', 'feet', '+', 1.5));
    final s2 = DerivedDataSettings(await _prefs({'derived_v1': s1.toJson()}));
    expect(s2.derivedDataSpecs.first.name, 'd1');
    expect(s2.derivedDataSpecs.first.operand, 1.5);
  });
}
