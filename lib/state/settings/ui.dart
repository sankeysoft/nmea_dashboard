// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Settings for the user interface style.
class UiSettings with ChangeNotifier {
  final PrefValue<bool> _firstRun;
  final PrefValue<int> _maxRunVersion;
  final PrefValue<bool> _nightMode;
  final PrefValue<bool> _darkTheme;
  final PrefValue<String> _valueFont;
  final PrefValue<String> _headingFont;
  final PrefMappedValue<int, HeadingSize> _maxHeading;
  final PrefValue<bool> _keepScreenAwake;
  final PrefValue<int> _alarmSilenceSeconds;

  // This hardcoded list matches the assets we added to the pubspec.
  static const List<String> availableFonts = [
    'Digital',
    'FredokaOne',
    'Inter',
    'Kanit',
    'Lexend',
    'Manrope',
    'Orbitron',
    'Roboto',
    'Sniglet',
  ];

  UiSettings(SharedPreferences prefs)
    : _firstRun = PrefValue(prefs, 'ui_first_run', true),
      _maxRunVersion = PrefValue(prefs, 'ui_max_run_version', 0),
      _nightMode = PrefValue(prefs, 'ui_night_mode', false),
      _darkTheme = PrefValue(prefs, 'ui_dark_theme', true),
      _valueFont = PrefValue(prefs, 'ui_value_font', 'Lexend'),
      _headingFont = PrefValue(prefs, 'ui_heading_font', 'Manrope'),
      _maxHeading = PrefMappedValue(
        prefs,
        'ui_max_heading_height',
        HeadingSize.medium,
        HeadingSize.closest,
        (n) => n.maxHeight,
      ),
      _keepScreenAwake = PrefValue(prefs, 'ui_keep_screen_awake', false),
      _alarmSilenceSeconds = PrefValue(prefs, 'ui_alarm_silence_seconds', 0);

  bool get firstRun => _firstRun.value;
  int get maxRunVersion => _maxRunVersion.value;
  bool get nightMode => _nightMode.value;
  bool get darkTheme => _darkTheme.value;
  String get valueFont => _valueFont.value;
  String get headingFont => _headingFont.value;
  HeadingSize get maxHeading => _maxHeading.value;
  bool get keepScreenAwake => _keepScreenAwake.value;
  Duration? get alarmSilenceTime =>
      _alarmSilenceSeconds.value == 0 ? null : Duration(seconds: _alarmSilenceSeconds.value);

  void recordNewRun(int version) {
    _firstRun.set(false);
    // Only ever let the last run version increase; if a user downgrades then
    // upgrades we don't want to communicate new changed twice.
    if (version > _maxRunVersion.value) {
      _maxRunVersion.set(version);
    }
    notifyListeners();
  }

  void toggleNightMode() {
    setNightMode(!_nightMode.value);
  }

  void setNightMode(bool isNight) {
    _nightMode.set(isNight);
    notifyListeners();
  }

  void setDarkTheme(bool isDark) {
    _darkTheme.set(isDark);
    notifyListeners();
  }

  void setFonts({String? valueFont, String? headingFont}) {
    if (valueFont != null) {
      _valueFont.set(valueFont);
    }
    if (headingFont != null) {
      _headingFont.set(headingFont);
    }
    notifyListeners();
  }

  void setMaxHeading(HeadingSize size) {
    _maxHeading.set(size);
    notifyListeners();
  }

  void setKeepScreenAwake(bool keepAwake) {
    _keepScreenAwake.set(keepAwake);
    WakelockPlus.toggle(enable: keepAwake);
    notifyListeners();
  }

  void setAlarmSilenceTime(Duration? duration) {
    _alarmSilenceSeconds.set(duration == null ? 0 : duration.inSeconds);
    notifyListeners();
  }
}

// The supported limits on the height of the heading line in a cell.
enum HeadingSize {
  small('Small', 24),
  medium('Medium', 48),
  large('Large', 96);

  final String description;
  final int maxHeight;
  const HeadingSize(this.description, this.maxHeight);

  /// Returns the size whose height is closest to `height`, preferring the smaller on a tie.
  static HeadingSize closest(int height) => HeadingSize.values.reduce((best, size) {
    final distance = (size.maxHeight - height).abs();
    final bestDistance = (best.maxHeight - height).abs();
    return (distance < bestDistance ||
            (distance == bestDistance && size.maxHeight < best.maxHeight))
        ? size
        : best;
  });
}
