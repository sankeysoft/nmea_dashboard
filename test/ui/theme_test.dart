// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:nmea_dashboard/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UiSettings> _settings({
  bool? nightMode,
  bool? darkTheme,
  String? valueFont,
  String? headingFont,
}) async {
  SharedPreferences.setMockInitialValues({
    if (nightMode != null) 'ui_night_mode': nightMode,
    if (darkTheme != null) 'ui_dark_theme': darkTheme,
    if (valueFont != null) 'ui_value_font': valueFont,
    if (headingFont != null) 'ui_heading_font': headingFont,
  });
  return UiSettings(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('palette selection', () {
    test('light theme: black on white', () async {
      final theme = createThemeData(await _settings(nightMode: false, darkTheme: false));
      expect(theme.scaffoldBackgroundColor, Colors.white);
      expect(theme.canvasColor, Colors.grey.shade100);
      expect(theme.colorScheme.primary, Colors.black);
    });

    test('dark theme: white on black', () async {
      final theme = createThemeData(await _settings(nightMode: false, darkTheme: true));
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.canvasColor, Colors.grey.shade900);
      expect(theme.colorScheme.primary, Colors.white);
    });

    test('night mode wins over darkTheme', () async {
      final theme = createThemeData(await _settings(nightMode: true, darkTheme: false));
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.primary, const Color(0xffff0000));
    });
  });

  group('alarm wiring (dark theme)', () {
    test('no alarm: surface is midBackground, primary is palette primary', () async {
      final theme = createThemeData(await _settings(darkTheme: true));
      expect(theme.colorScheme.surface, Colors.grey.shade900);
      expect(theme.colorScheme.primary, Colors.white);
    });

    test('caution alarm: surface/onPrimary use caution and primary flips to background', () async {
      final theme = createThemeData(
        await _settings(darkTheme: true),
        alarm: AlarmLevel.caution,
      );
      expect(theme.colorScheme.surface, Colors.yellow.shade600);
      expect(theme.colorScheme.onPrimary, Colors.yellow.shade600);
      expect(theme.colorScheme.primary, Colors.black);
    });

    test('warning alarm: surface/onPrimary use warning', () async {
      final theme = createThemeData(
        await _settings(darkTheme: true),
        alarm: AlarmLevel.warning,
      );
      expect(theme.colorScheme.surface, Colors.redAccent.shade400);
      expect(theme.colorScheme.onPrimary, Colors.redAccent.shade400);
    });
  });

  group('font wiring', () {
    test('value and heading fonts propagate from settings to text theme', () async {
      final theme = createThemeData(
        await _settings(valueFont: 'AAA', headingFont: 'BBB'),
      );
      expect(theme.textTheme.headlineLarge!.fontFamily, 'AAA');
      expect(theme.textTheme.headlineMedium!.fontFamily, 'BBB');
      expect(theme.textTheme.labelSmall!.fontFamily, 'BBB');
    });
  });
}
