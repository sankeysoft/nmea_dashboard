// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('uses defaults when prefs are empty', () async {
    final s = UiSettings(await _prefs());
    expect(s.firstRun, isTrue);
    expect(s.maxRunVersion, 0);
    expect(s.nightMode, isFalse);
    expect(s.darkTheme, isTrue);
    expect(s.valueFont, 'Lexend');
    expect(s.headingFont, 'Manrope');
    expect(s.keepScreenAwake, isFalse);
  });

  test('reads stored values from prefs', () async {
    final defaults = UiSettings(await _prefs());
    final s = UiSettings(
      await _prefs({
        'ui_first_run': !defaults.firstRun,
        'ui_max_run_version': 42,
        'ui_night_mode': !defaults.nightMode,
        'ui_dark_theme': !defaults.darkTheme,
        'ui_value_font': 'Orbitron',
        'ui_heading_font': 'Kanit',
        'ui_keep_screen_awake': !defaults.keepScreenAwake,
      }),
    );
    expect(s.firstRun, isNot(defaults.firstRun));
    expect(s.maxRunVersion, 42);
    expect(s.nightMode, isNot(defaults.nightMode));
    expect(s.darkTheme, isNot(defaults.darkTheme));
    expect(s.valueFont, 'Orbitron');
    expect(s.headingFont, 'Kanit');
    expect(s.keepScreenAwake, isNot(defaults.keepScreenAwake));
  });

  test('recordNewRun sets firstRun false, persists version, and notifies', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.recordNewRun(42);
    expect(s.firstRun, isFalse);
    expect(s.maxRunVersion, 42);
    expect(p.getBool('ui_first_run'), isFalse);
    expect(p.getInt('ui_max_run_version'), 42);
    expect(count, 1);
  });

  test('recordNewRun does not decrease version', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.recordNewRun(42);
    expect(s.maxRunVersion, 42);
    s.recordNewRun(40);
    expect(s.maxRunVersion, 42);
    expect(p.getInt('ui_max_run_version'), 42);
    expect(count, 2);
  });

  test('toggleNightMode flips nightMode and notifies each toggle', () async {
    final s = UiSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    s.toggleNightMode();
    expect(s.nightMode, isTrue);
    expect(count, 1);
    s.toggleNightMode();
    expect(s.nightMode, isFalse);
    expect(count, 2);
  });

  test('setNightMode sets nightMode, persists, and notifies', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setNightMode(true);
    expect(s.nightMode, isTrue);
    expect(p.getBool('ui_night_mode'), isTrue);
    expect(count, 1);
  });

  test('setDarkTheme sets darkTheme, persists, and notifies', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setDarkTheme(false);
    expect(s.darkTheme, isFalse);
    expect(p.getBool('ui_dark_theme'), isFalse);
    expect(count, 1);
  });

  test('setFonts with valueFont only leaves headingFont unchanged', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setFonts(valueFont: 'Orbitron');
    expect(s.valueFont, 'Orbitron');
    expect(s.headingFont, 'Manrope');
    expect(p.getString('ui_value_font'), 'Orbitron');
    expect(count, 1);
  });

  test('setFonts with headingFont only leaves valueFont unchanged', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setFonts(headingFont: 'Kanit');
    expect(s.valueFont, 'Lexend');
    expect(s.headingFont, 'Kanit');
    expect(p.getString('ui_heading_font'), 'Kanit');
    expect(count, 1);
  });

  test('setFonts sets both fonts in a single notification', () async {
    final s = UiSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    s.setFonts(valueFont: 'Orbitron', headingFont: 'Kanit');
    expect(s.valueFont, 'Orbitron');
    expect(s.headingFont, 'Kanit');
    expect(count, 1);
  });

  test('setKeepScreenAwake sets keepScreenAwake, persists, and notifies', () async {
    final p = await _prefs();
    final s = UiSettings(p);
    int count = 0;
    s.addListener(() => count++);
    s.setKeepScreenAwake(true);
    expect(s.keepScreenAwake, isTrue);
    expect(p.getBool('ui_keep_screen_awake'), isTrue);
    expect(count, 1);
  });
}
