// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('AlarmSettings');

/// Settings for the alarms, notifies when any of these change.
class AlarmSettings with ChangeNotifier {
  static const String _prefKey = 'alarm_v1';
  final SharedPreferences _prefs;
  final Map<SpecKey, AlarmSpec> _alarmSpecs = {};

  /// Creates settings from the supplied prefs, starting empty if
  /// the shared prefs are missing or invalid.
  AlarmSettings(this._prefs) {
    final specs = validateJsonList(
      prefJson(_prefs, _prefKey, _log),
      (e) => AlarmSpec.fromJson(e),
      'alarm settings',
      _log,
    );
    // Stick with the default empty map if load fails.
    if (specs != null) {
      _useSpecs(specs, 'shared preferences');
    }
  }

  /// An iterator over the alarm specs in order.
  Iterable<AlarmSpec> get alarmSpecs => _alarmSpecs.values;

  /// Replaces the current set of alarms with the supplied specifications.
  void replaceElements(Iterable<AlarmSpec> alarmSpecs) {
    _alarmSpecs.clear();
    for (final alarmSpec in alarmSpecs) {
      _alarmSpecs[alarmSpec.key] = alarmSpec;
    }
    _save();
    notifyListeners();
  }

  /// Adds or replaces the supplied specification in the current set of alarms.
  void setAlarm(AlarmSpec spec) {
    _alarmSpecs[spec.key] = spec;
    _save();
    notifyListeners();
  }

  /// Deletes the supplied specification from current set of alarms.
  void removeElement(AlarmSpec spec) {
    _alarmSpecs.remove(spec.key);
    _save();
    notifyListeners();
  }

  /// Replaces the current set of alarms with specs from clipboard text, making no changes if
  /// the text is not valid or if dryRun is true. Returns true on success.
  bool useClipboard(String text, {bool dryRun = false}) {
    final specs = validateJsonList(
      clipboardData(text, ClipboardKind.alarms),
      (e) => AlarmSpec.fromJson(e),
      'alarm clipboard',
      _log,
    );
    if (specs == null) {
      return false;
    } else if (!dryRun) {
      _useSpecs(specs, 'clipboard');
      _save();
      notifyListeners();
    }
    return true;
  }

  /// Returns clipboard text containing the configuration of all alarms.
  String toClipboard() {
    return encodeClipboard(ClipboardKind.alarms, _alarmSpecs.values.toList());
  }

  /// Returns a json string containing the configuration of all alarms.
  String toJson() {
    final jsonIterator = _alarmSpecs.values.toList();
    return json.encode(jsonIterator);
  }

  /// Replaces the map of alarms with the supplied specs.
  void _useSpecs(List<AlarmSpec> specs, String source) {
    _alarmSpecs.clear();
    for (final spec in specs) {
      _alarmSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${specs.length} alarms from $source');
  }

  /// Saves the configuration of all alarms into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}
