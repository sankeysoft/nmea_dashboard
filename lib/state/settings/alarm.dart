// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
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
    final prefString = _prefs.getString(_prefKey);
    // Stick with the default empty map if load fails.
    _fromJson(json: prefString ?? '', source: 'shared preferences');
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

  /// Replaces the current set of alarms with specs from a json encoded string,
  /// making no changes if the string is not valid or if dryRun is true.
  /// Returns true on success.
  bool useClipboard(String text, {bool dryRun = false}) {
    bool success = _fromJson(json: text, source: 'clipboard', dryRun: dryRun);
    if (!dryRun && success) {
      _save();
      notifyListeners();
    }
    return success;
  }

  /// Returns a json string containing the configuration of all alarms.
  String toJson() {
    final jsonIterator = _alarmSpecs.values.toList();
    return json.encode(jsonIterator);
  }

  /// Overwrites all data with elements from a json encoded string, making no
  /// changes if the string is not valid or if dryRun is true. Returns true on
  /// success.
  bool _fromJson({required String json, required String source, bool dryRun = false}) {
    // Use the helper function to convert to a list of bare specs
    final specs = validateJsonList(
      json,
      (e) => AlarmSpec.fromJson(e),
      'alarm settings',
      _log,
      minimumLength: 0,
    );
    // Leave with a failure if this didn't work or success if we're dry running and
    // it did.
    if (specs == null) {
      return false;
    } else if (dryRun) {
      return true;
    }

    // If we're not dry run use the specs to repopulate the map.
    _alarmSpecs.clear();
    for (final spec in specs) {
      _alarmSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${specs.length} alarms from $source');
    return true;
  }

  /// Saves the configuration of all alarms into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}

// The different levels of alarm, driving the different ways they are announced.
enum AlarmType { caution, warning }
