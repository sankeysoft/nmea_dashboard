// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
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
}
