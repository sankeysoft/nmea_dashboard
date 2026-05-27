// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';

/// Creates a theme based on the supplied UI settings, optionally tailoring to display
/// an element with an active alarm.
ThemeData createThemeData(UiSettings settings, {AlarmLevel? alarm}) {
  final palette = _Palette(settings.darkTheme, settings.nightMode);

  Color selectByAlarmLevel(Color none, Color warning, Color caution) {
    switch (alarm) {
      case AlarmLevel.warning:
        return warning;
      case AlarmLevel.caution:
        return caution;
      default:
        return none;
    }
  }

  Color selectByAlarmActive(Color none, Color set) {
    if (alarm != null) {
      return set;
    } else {
      return none;
    }
  }

  return ThemeData(
    primarySwatch: Colors.grey,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      // Primary and secondary are used for buttons and switches
      primary: selectByAlarmActive(palette.primary, palette.background),
      primaryContainer: selectByAlarmActive(palette.midPrimary, palette.weakestBackground),
      onPrimary: selectByAlarmLevel(palette.background, palette.warning, palette.caution),
      secondary: palette.secondary,
      onSecondary: palette.background,
      tertiary: palette.tertiary,
      onTertiary: palette.background,
      error: Colors.red,
      onError: Colors.white,
      // Surface is used for the data cells, app bar, and drawer.
      surface: selectByAlarmLevel(palette.midBackground, palette.warning, palette.caution),
      onSurface: palette.primary,
      // Surface tint is used for tiles, the drawer header, and missing data
      // in graphs.
      surfaceTint: selectByAlarmLevel(
        palette.weakestBackground,
        palette.midWarning,
        palette.midCaution,
      ),
    ),
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.midBackground,
    disabledColor: palette.weakestPrimary,
    textTheme: Typography.whiteMountainView.copyWith(
      // Used by dialogs.
      titleLarge: TextStyle(fontSize: 18, color: palette.primary),
      titleMedium: TextStyle(fontSize: 16, color: palette.primary),
      // Used by form fields.
      labelMedium: TextStyle(fontSize: 16, color: palette.primary),
      // Used by graph axes.
      labelSmall: TextStyle(
        fontSize: 14,
        fontFamily: settings.headingFont,
        color: selectByAlarmActive(palette.midPrimary, palette.weakestBackground),
      ),
      // Used by the actual data.
      headlineLarge: TextStyle(
        fontFamily: settings.valueFont,
        color: selectByAlarmActive(palette.primary, palette.midBackground),
      ),
      // Used by the headings and units.
      headlineMedium: TextStyle(
        fontFamily: settings.headingFont,
        color: selectByAlarmActive(palette.primary, palette.midBackground),
        height: 1,
      ),
    ),
  );
}

/// App-specific colors we actually want to control.
class _Palette {
  late final Color background;
  late final Color midBackground;
  late final Color weakestBackground;
  late final Color primary;
  late final Color midPrimary;
  late final Color weakestPrimary;
  late final Color secondary;
  late final Color tertiary;
  late final Color warning;
  late final Color midWarning;
  late final Color caution;
  late final Color midCaution;

  _Palette(bool darkTheme, bool nightMode) {
    if (nightMode) {
      primary = const Color(0xffff0000);
      midPrimary = const Color(0xffbb0000);
      weakestPrimary = const Color(0xff770000);
      secondary = const Color(0xffcc0000);
      tertiary = const Color(0xffbb0000);
      background = Colors.black;
      midBackground = const Color(0xff111111);
      weakestBackground = const Color(0xff222222);
      warning = const Color(0xffff0000);
      midWarning = const Color(0xffbb0000);
      caution = const Color(0xffbb0000);
      midCaution = const Color(0xff880000);
      return;
    } else if (darkTheme) {
      primary = Colors.white;
      midPrimary = Colors.grey.shade400;
      weakestPrimary = Colors.grey.shade700;
      secondary = Colors.green.shade300;
      tertiary = Colors.blue.shade300;
      background = Colors.black;
      midBackground = Colors.grey.shade900;
      weakestBackground = Colors.grey.shade800;
      warning = Colors.redAccent.shade400;
      midWarning = const Color(0xffb02220);
      caution = Colors.yellow.shade600;
      midCaution = const Color(0xffb8a502);
      return;
    } else {
      primary = Colors.black;
      midPrimary = Colors.grey.shade800;
      weakestPrimary = Colors.grey.shade600;
      secondary = Colors.green.shade600;
      tertiary = Colors.blue.shade600;
      background = Colors.white;
      midBackground = Colors.grey.shade100;
      weakestBackground = Colors.grey.shade300;
      warning = Colors.red.shade600;
      midWarning = Colors.red.shade900;
      caution = const Color(0xffb8a502);
      midCaution = const Color(0xff8b8124);
      return;
    }
  }
}
