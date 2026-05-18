// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/settings.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pageJson1 =
    '[{"name":"p1","cells":[{"source":"network","element":"depth","type":"current","format":"feet"}]}]';
const _pageJson2 =
    '[{"name":"p2","cells":[{"source":"local","element":"time","type":"current","format":"hhmm"}]}]';
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

  // ──────────────── NetworkSettings ────────────────

  group('NetworkSettings', () {
    test('uses defaults when prefs are empty', () async {
      final s = NetworkSettings(await _prefs());
      expect(s.mode, NetworkMode.udpListen);
      expect(s.ipAddress.address, '192.168.4.1');
      expect(s.port, 2000);
      expect(s.requireChecksum, isTrue);
      expect(s.staleness, const Duration(seconds: 10));
    });

    test('reads stored values from prefs', () async {
      final s = NetworkSettings(
        await _prefs({
          'network_mode': 1,
          'network_address': '10.0.0.1',
          'network_port': 3000,
          'network_checksum': false,
          'network_staleness_seconds': 30,
        }),
      );
      expect(s.mode, NetworkMode.tcpConnect);
      expect(s.ipAddress.address, '10.0.0.1');
      expect(s.port, 3000);
      expect(s.requireChecksum, isFalse);
      expect(s.staleness, const Duration(seconds: 30));
    });

    test('out-of-range mode index falls back to udpListen', () async {
      final s = NetworkSettings(await _prefs({'network_mode': 99}));
      expect(s.mode, NetworkMode.udpListen);
    });

    test('set() updates all fields and persists to prefs', () async {
      final p = await _prefs();
      final s = NetworkSettings(p);
      s.set(
        mode: NetworkMode.tcpConnect,
        port: 5000,
        ipAddress: InternetAddress('10.0.0.2'),
        requireChecksum: false,
        staleness: const Duration(seconds: 20),
      );
      expect(s.mode, NetworkMode.tcpConnect);
      expect(s.port, 5000);
      expect(s.ipAddress.address, '10.0.0.2');
      expect(s.requireChecksum, isFalse);
      expect(s.staleness, const Duration(seconds: 20));
      expect(p.getInt('network_mode'), 1);
      expect(p.getString('network_address'), '10.0.0.2');
      expect(p.getInt('network_port'), 5000);
      expect(p.getBool('network_checksum'), isFalse);
      expect(p.getInt('network_staleness_seconds'), 20);
    });

    test('set() with only some fields leaves others unchanged', () async {
      final s = NetworkSettings(await _prefs());
      s.set(port: 9999);
      expect(s.mode, NetworkMode.udpListen);
      expect(s.port, 9999);
      expect(s.requireChecksum, isTrue);
    });

    test('set() notifies listeners', () async {
      final s = NetworkSettings(await _prefs());
      int count = 0;
      s.addListener(() => count++);
      s.set(port: 9999);
      expect(count, 1);
    });
  });

  // ──────────────── UiSettings ────────────────

  group('UiSettings', () {
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
  });

  // ──────────────── DerivedDataSettings ────────────────

  group('DerivedDataSettings', () {
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
      expect(
        DerivedDataSettings(await _prefs({'derived_v1': 'not json'})).derivedDataSpecs,
        isEmpty,
      );
    });

    test('starts empty when prefs contain non-list JSON', () async {
      expect(
        DerivedDataSettings(await _prefs({'derived_v1': '{"a":1}'})).derivedDataSpecs,
        isEmpty,
      );
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
  });

  // ──────────────── PageSettings ────────────────

  group('PageSettings', () {
    test('loads defaults when prefs are empty', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      expect(s.dataPageSpecs.length, 1);
      expect(s.dataPageSpecs.first.name, 'p1');
    });

    test('loads from prefs when prefs contain valid JSON', () async {
      final s = PageSettings(await _prefs({'page_v1': _pageJson2}), _pageJson1);
      expect(s.dataPageSpecs.first.name, 'p2');
    });

    test('falls back to defaults when prefs contain invalid JSON', () async {
      final s = PageSettings(await _prefs({'page_v1': 'not json'}), _pageJson1);
      expect(s.dataPageSpecs.first.name, 'p1');
    });

    test('falls back to defaults when prefs contain an empty page list', () async {
      // minimumLength: 1 means an empty list is rejected.
      final s = PageSettings(await _prefs({'page_v1': '[]'}), _pageJson1);
      expect(s.dataPageSpecs.first.name, 'p1');
    });

    test('selectedPageIndex is null before any explicit selection', () async {
      expect(PageSettings(await _prefs(), _pageJson1).selectedPageIndex, isNull);
    });

    test('selectPage makes selectedPageIndex return the right index', () async {
      const twoPages =
          '[{"name":"a","cells":[{"source":"network","element":"depth","type":"current","format":"feet"}]},'
          '{"name":"b","cells":[{"source":"network","element":"depth","type":"current","format":"feet"}]}]';
      final s = PageSettings(await _prefs(), twoPages);
      s.selectPage(1);
      expect(s.selectedPageIndex, 1);
      s.selectPage(0);
      expect(s.selectedPageIndex, 0);
    });

    test('lookupByKey finds a page by its key', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      final page = s.dataPageSpecs.first;
      expect(s.lookupByKey(page.key), page);
    });

    test('lookupByKey returns null for an unknown key', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      expect(s.lookupByKey(const SpecKey(99999)), isNull);
    });

    test('setPage adds a new page, selects it, persists, and notifies', () async {
      final p = await _prefs();
      final s = PageSettings(p, _pageJson1);
      int count = 0;
      s.addListener(() => count++);
      s.setPage(DataPageSpec('new page', []));
      expect(s.dataPageSpecs.length, 2);
      expect(s.selectedPageIndex, 1);
      expect(p.getString('page_v1'), isNotNull);
      expect(count, 1);
    });

    test('setPage replaces an existing page without changing selection', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      final existing = s.dataPageSpecs.first;
      s.selectPage(0);
      s.setPage(DataPageSpec('updated', [], key: existing.key));
      expect(s.dataPageSpecs.length, 1);
      expect(s.dataPageSpecs.first.name, 'updated');
      expect(s.selectedPageIndex, 0);
    });

    test('removePage removes a page, persists, and notifies', () async {
      final p = await _prefs();
      final s = PageSettings(p, _pageJson1);
      int count = 0;
      s.addListener(() => count++);
      s.removePage(s.dataPageSpecs.first);
      expect(s.dataPageSpecs, isEmpty);
      expect(count, 1);
    });

    test('replacePages replaces all pages, persists, and notifies', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      int count = 0;
      s.addListener(() => count++);
      s.replacePages([DataPageSpec('page a', []), DataPageSpec('page b', [])]);
      final specs = s.dataPageSpecs.toList();
      expect(specs.length, 2);
      expect(specs[0].name, 'page a');
      expect(specs[1].name, 'page b');
      expect(count, 1);
    });

    test('updateCell updates a cell in the containing page', () async {
      final s = PageSettings(await _prefs({'page_v1': _pageJson1}), _pageJson1);
      final page = s.dataPageSpecs.first;
      final cellKey = page.cells.first.key;
      s.updateCell(DataCellSpec('local', 'time', 'current', 'hhmm', key: cellKey));
      expect(page.cells.first.source, 'local');
      expect(page.cells.first.element, 'time');
    });

    test('useClipboard with valid JSON replaces pages, clears selection, and notifies', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      s.selectPage(0);
      int count = 0;
      s.addListener(() => count++);
      expect(s.useClipboard(_pageJson2), isTrue);
      expect(s.dataPageSpecs.first.name, 'p2');
      expect(s.selectedPageIndex, isNull);
      expect(count, 1);
    });

    test('useClipboard with invalid JSON makes no changes', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      int count = 0;
      s.addListener(() => count++);
      expect(s.useClipboard('not json'), isFalse);
      expect(s.dataPageSpecs.first.name, 'p1');
      expect(count, 0);
    });

    test('useClipboard with dryRun validates but makes no changes', () async {
      final s = PageSettings(await _prefs(), _pageJson1);
      int count = 0;
      s.addListener(() => count++);
      expect(s.useClipboard(_pageJson2, dryRun: true), isTrue);
      expect(s.dataPageSpecs.first.name, 'p1');
      expect(count, 0);
    });

    test('toJson round-trips through construction', () async {
      final s1 = PageSettings(await _prefs(), _pageJson1);
      s1.setPage(DataPageSpec('added', []));
      final s2 = PageSettings(await _prefs({'page_v1': s1.toJson()}), _pageJson1);
      expect(s2.dataPageSpecs.length, 2);
      expect(s2.dataPageSpecs.last.name, 'added');
    });
  });

  // ──────────────── FormatPreferences ────────────────

  group('FormatPreferences', () {
    test('construction with invalid JSON falls back to defaults', () async {
      final s = FormatPreferences(await _prefs({'format_usage_v1': 'not json'}));
      expect(s.forDimension(Dimension.speed.name), 'knots');
      expect(s.forDimension(Dimension.depth.name), 'feet');
      expect(s.forDimension(Dimension.angle.name), 'degrees');
    });

    test('construction with non-map JSON falls back to defaults', () async {
      final s = FormatPreferences(await _prefs({'format_usage_v1': '[1, 2, 3]'}));
      expect(s.forDimension(Dimension.speed.name), 'knots');
      expect(s.forDimension(Dimension.depth.name), 'feet');
      expect(s.forDimension(Dimension.angle.name), 'degrees');
    });

    test('forDimension returns null for unknown dimension', () async {
      expect(FormatPreferences(await _prefs()).forDimension(null), isNull);
      expect(FormatPreferences(await _prefs()).forDimension('not_a_dimension'), isNull);
    });

    test('recordUsage with null dimension or formatter does nothing silently', () async {
      final p = await _prefs();
      final s = FormatPreferences(p);
      int count = 0;
      s.addListener(() => count++);
      s.recordUsage(null, 'knots');
      s.recordUsage(Dimension.speed.name, null);
      expect(count, 0);
      expect(p.getString('format_usage_v1'), isNull);
    });

    test('recordUsage with unknown dimension or formatter does not notify', () async {
      final p = await _prefs();
      final s = FormatPreferences(p);
      int count = 0;
      s.addListener(() => count++);
      s.recordUsage(Dimension.speed.name, 'not_a_formatter');
      s.recordUsage('not_a_dimension', 'knots');
      expect(count, 0);
      expect(p.getString('format_usage_v1'), isNull);
    });

    test('recordUsage notifies and persists to prefs', () async {
      final p = await _prefs();
      final s = FormatPreferences(p);
      int count = 0;
      s.addListener(() => count++);
      s.recordUsage(Dimension.speed.name, 'knots');
      expect(count, 1);
      expect(p.getString('format_usage_v1'), isNotNull);
    });

    test('recordUsage makes a non-default formatter preferred after one use', () async {
      final s = FormatPreferences(await _prefs());
      // 'knots' is the default (weight 1), 'metersPerSec' starts at 0.
      expect(s.forDimension(Dimension.speed.name), 'knots');
      // Relaxation drops knots to floor(1*0.75)=0, then metersPerSec gets +1000.
      s.recordUsage(Dimension.speed.name, 'metersPerSec');
      expect(s.forDimension(Dimension.speed.name), 'metersPerSec');
    });

    test('usage preference is restored from persisted prefs', () async {
      final p = await _prefs();
      final s1 = FormatPreferences(p);
      expect(s1.forDimension(Dimension.speed.name), 'knots');

      s1.recordUsage(Dimension.speed.name, 'metersPerSec');
      expect(s1.forDimension(Dimension.speed.name), 'metersPerSec');

      final s2 = FormatPreferences(p);
      expect(s2.forDimension(Dimension.speed.name), 'metersPerSec');
    });
  });
}
