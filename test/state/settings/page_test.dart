// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pageJson1 =
    '[{"name":"p1","cells":[{"source":"network","element":"depth","type":"current","format":"feet"}]}]';
const _pageJson2 =
    '[{"name":"p2","cells":[{"source":"local","element":"time","type":"current","format":"hhmm"}]}]';

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
}
