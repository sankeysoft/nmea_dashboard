// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _alarmSpecJson =
    '[{"source":"network","element":"depth","type":"caution","format":"feet","min": 10.0}]';

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  test('starts empty when prefs are empty', () async {
    expect(AlarmSettings(await _prefs()).alarmSpecs, isEmpty);
  });

  test('loads specs from prefs on construction', () async {
    final s = AlarmSettings(await _prefs({'alarm_v1': _alarmSpecJson}));
    final specs = s.alarmSpecs.toList();
    expect(specs.length, 1);
    expect(specs[0].source, 'network');
    expect(specs[0].element, 'depth');
    expect(specs[0].type, 'caution');
    expect(specs[0].format, 'feet');
    expect(specs[0].min, 10);
    expect(specs[0].max, isNull);
  });

  test('starts empty when prefs contain invalid JSON', () async {
    expect(AlarmSettings(await _prefs({'alarm_v1': 'not json'})).alarmSpecs, isEmpty);
  });

  test('starts empty when prefs contain non-list JSON', () async {
    expect(AlarmSettings(await _prefs({'alarm_v1': '{"a":1}'})).alarmSpecs, isEmpty);
  });

  test('setElement adds a spec, persists, and notifies', () async {
    final p = await _prefs();
    final s = AlarmSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setAlarm(AlarmSpec('network', 'depth', 'caution', 'feet', min: 10));
    expect(s.alarmSpecs.length, 1);
    expect(s.alarmSpecs.first.element, 'depth');
    expect(p.getString('alarm_v1'), isNotNull);
    expect(count, 1);
  });

  test('setElement replaces a spec with the same key', () async {
    final s = AlarmSettings(await _prefs());
    final spec = AlarmSpec('network', 'depth', 'caution', 'feet', min: 10);
    s.setAlarm(spec);
    s.setAlarm(AlarmSpec('network', 'TWS', 'warning', 'knots', max: 30.0, key: spec.key));
    expect(s.alarmSpecs.length, 1);
    expect(s.alarmSpecs.first.element, 'TWS');
  });

  test('removeElement removes a spec, persists, and notifies', () async {
    final s = AlarmSettings(await _prefs());
    final spec = AlarmSpec('network', 'depth', 'caution', 'feet', min: 10);
    s.setAlarm(spec);
    int count = 0;
    s.addListener(() => count++);
    s.removeElement(spec);
    expect(s.alarmSpecs, isEmpty);
    expect(count, 1);
  });

  test('replaceElements replaces all specs, persists, and notifies', () async {
    final s = AlarmSettings(await _prefs());
    s.setAlarm(AlarmSpec('network', 'depth', 'caution', 'feet', min: 10));
    int count = 0;
    s.addListener(() => count++);
    s.replaceElements([
      AlarmSpec('network', 'TWS', 'warning', 'knots', max: 30.0),
      AlarmSpec('network', 'TWD', 'caution', 'degrees', min: 10.0, max: 90.0),
    ]);
    final specs = s.alarmSpecs.toList();
    expect(specs.length, 2);
    expect(specs[0].element, 'TWS');
    expect(specs[1].element, 'TWD');
    expect(count, 1);
  });

  test('useClipboard with valid JSON replaces specs, persists, and notifies', () async {
    final s = AlarmSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard(_alarmSpecJson), isTrue);
    expect(s.alarmSpecs.length, 1);
    expect(count, 1);
  });

  test('useClipboard with invalid JSON makes no changes', () async {
    final s = AlarmSettings(await _prefs());
    s.setAlarm(AlarmSpec('network', 'depth', 'caution', 'feet', min: 10));
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard('not json'), isFalse);
    expect(s.alarmSpecs.length, 1);
    expect(count, 0);
  });

  test('useClipboard with dryRun validates but makes no changes', () async {
    final s = AlarmSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    expect(s.useClipboard(_alarmSpecJson, dryRun: true), isTrue);
    expect(s.alarmSpecs, isEmpty);
    expect(count, 0);
  });

  test('toJson round-trips through construction', () async {
    final s1 = AlarmSettings(await _prefs());
    s1.setAlarm(AlarmSpec('network', 'depth', 'caution', 'feet',
        averagingInterval: 'oneMinute', min: 10.0, max: 150.0));
    final s2 = AlarmSettings(await _prefs({'alarm_v1': s1.toJson()}));
    expect(s2.alarmSpecs.first.element, 'depth');
    expect(s2.alarmSpecs.first.averagingInterval, 'oneMinute');
    expect(s2.alarmSpecs.first.min, 10.0);
    expect(s2.alarmSpecs.first.max, 150.0);
  });
}
