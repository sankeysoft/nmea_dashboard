// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/settings.dart';

/// Creates a theme based on the supplied UI settings.
ThemeData createThemeData(UiSettings settings) {
  final palette = _Palette(settings.nightMode);

  return ThemeData(
    primarySwatch: Colors.grey,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      // Primary and secondary are used for buttons and switches
      primary: palette.primary,
      primaryContainer: palette.midPrimary,
      onPrimary: palette.darkestBackground,
      secondary: palette.secondary,
      onSecondary: palette.darkestBackground,
      tertiary: palette.tertiary,
      onTertiary: palette.darkestBackground,
      error: Colors.red,
      onError: Colors.white,
      // Surface is used for the data cells, app bar, and drawer.
      surface: palette.midBackground,
      onSurface: palette.primary,
      // Surface tint is used for tiles, the drawer header, and missing data
      // in graphs.
      surfaceTint: palette.lightestBackground,
    ),
    scaffoldBackgroundColor: palette.darkestBackground,
    canvasColor: palette.midBackground,
    disabledColor: palette.dimmestPrimary,
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
        color: palette.midPrimary,
      ),
      // Used by the actual data.
      headlineLarge: TextStyle(fontFamily: settings.valueFont, color: palette.primary),
      // Used by the headings and units.
      headlineMedium: TextStyle(
        fontFamily: settings.headingFont,
        color: palette.midPrimary,
        height: 1,
      ),
    ),
  );
}

/// App-specific colors we actually want to control.
class _Palette {
  late final Color lightestBackground;
  late final Color midBackground;
  late final Color darkestBackground;
  late final Color primary;
  late final Color midPrimary;
  late final Color dimmestPrimary;
  late final Color secondary;
  late final Color tertiary;

  _Palette(bool nightMode) {
    if (nightMode) {
      primary = const Color(0xffff0000);
      midPrimary = const Color(0xffbb0000);
      dimmestPrimary = const Color(0xff770000);
      secondary = const Color(0xffcc0000);
      tertiary = const Color(0xffbb0000);
      lightestBackground = const Color(0xff222222);
      midBackground = const Color(0xff111111);
      darkestBackground = Colors.black;
      return;
    } else {
      primary = Colors.white;
      midPrimary = Colors.grey.shade400;
      dimmestPrimary = Colors.grey.shade700;
      secondary = Colors.green.shade300;
      tertiary = Colors.blue.shade300;
      lightestBackground = Colors.grey.shade800;
      midBackground = Colors.grey.shade900;
      darkestBackground = Colors.black;
      return;
    }
  }
}
