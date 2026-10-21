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

final _log = Logger('DerivedDataSettings');

/// Settings for the derived data definitions, notifies when any
/// of these change.
class DerivedDataSettings with ChangeNotifier {
  static const String _prefKey = 'derived_v1';
  final SharedPreferences _prefs;
  final Map<SpecKey, DerivedDataSpec> _derivedDataSpecs = {};

  /// Creates settings from the supplied prefs, starting empty if
  /// the shared prefs are missing or invalid.
  DerivedDataSettings(this._prefs) {
    final specs = validateJsonList(
      prefJson(_prefs, _prefKey, _log),
      (e) => DerivedDataSpec.fromJson(e),
      'derived data settings',
      _log,
    );
    // Stick with the default empty map if load fails.
    if (specs != null) {
      _useSpecs(specs, 'shared preferences');
    }
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

  /// Replaces the current set of derived data with specs from clipboard text, making no changes
  /// if the text is not valid or if dryRun is true. Returns true on success.
  bool useClipboard(String text, {bool dryRun = false}) {
    final specs = validateJsonList(
      clipboardData(text, ClipboardKind.derivedData),
      (e) => DerivedDataSpec.fromJson(e),
      'derived data clipboard',
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

  /// Returns clipboard text containing the configuration of all derived data.
  String toClipboard() {
    return encodeClipboard(ClipboardKind.derivedData, _derivedDataSpecs.values.toList());
  }

  /// Returns a json string containing the configuration of all derived data.
  String toJson() {
    final jsonIterator = _derivedDataSpecs.values.toList();
    return json.encode(jsonIterator);
  }

  /// Replaces the map of derived data with the supplied specs.
  void _useSpecs(List<DerivedDataSpec> specs, String source) {
    _derivedDataSpecs.clear();
    for (final spec in specs) {
      _derivedDataSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${specs.length} derived elements from $source');
  }

  /// Saves the configuration of all derived data into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}
