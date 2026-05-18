// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('Settings');

/// Settings for the derived data definitions, notifies when any
/// of these change.
class DerivedDataSettings with ChangeNotifier {
  static const String _prefKey = 'derived_v1';
  final SharedPreferences _prefs;
  final Map<SpecKey, DerivedDataSpec> _derivedDataSpecs = {};

  /// Creates settings from the supplied prefs, starting empty if
  /// the shared prefs are missing of invalid.
  DerivedDataSettings(this._prefs) {
    final prefString = _prefs.getString(_prefKey);
    // Stick with the default empty map if load fails.
    _fromJson(json: prefString ?? '', source: 'shared preferences');
  }

  /// An iterator over the data specs in order.
  Iterable<DerivedDataSpec> get derivedDataSpecs => _derivedDataSpecs.values;

  /// Replaces the current set of derived data with the supplied specifications.
  void replaceElements(Iterable<DerivedDataSpec> derivedDataSpecs) {
    _derivedDataSpecs.clear();
    for (final derivedDataSpec in derivedDataSpecs) {
      _derivedDataSpecs[derivedDataSpec.key] = derivedDataSpec;
    }
    _save();
    notifyListeners();
  }

  /// Adds or replaces the supplied specification in the current set of derived
  /// data.
  void setElement(DerivedDataSpec spec) {
    _derivedDataSpecs[spec.key] = spec;
    _save();
    notifyListeners();
  }

  /// Deletes the supplied specification from current set of pages.
  void removeElement(DerivedDataSpec spec) {
    _derivedDataSpecs.remove(spec.key);
    _save();
    notifyListeners();
  }

  /// Replaces the current set of pages with pages from a json encoded string,
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

  /// Returns a json string containing the configuration of all derived data.
  String toJson() {
    final jsonIterator = _derivedDataSpecs.values.toList();
    return json.encode(jsonIterator);
  }

  /// Overwrites all data with elements from a json encoded string, making no
  /// changes if the string is not valid or if dryRun is true. Returns true on
  /// success.
  bool _fromJson({required String json, required String source, bool dryRun = false}) {
    // Use the helper function to convert to a list of bare specs
    final specs = validateJsonList(
      json,
      (e) => DerivedDataSpec.fromJson(e),
      'derived data settings',
      _log,
      minimumLength: 0,
    );
    // Leave with a failure if this didn't work or success we're dry running and
    // it did.
    if (specs == null) {
      return false;
    } else if (dryRun) {
      return true;
    }

    // If we're not dry run use the specs to repopulate the map.
    _derivedDataSpecs.clear();
    for (final spec in specs) {
      _derivedDataSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${specs.length} derived elements from $source');
    return true;
  }

  /// Saves the configuration of all derived data into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}
