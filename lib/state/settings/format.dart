// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('FormatSettings');

class FormatPreferences with ChangeNotifier {
  static const String _prefKey = 'format_usage_v1';
  static const int _initial = 1000;
  static const double _relaxation = 0.75;

  final SharedPreferences _prefs;
  final Map<String, Map<String, int>> _dimensionMap = {};

  FormatPreferences(this._prefs) {
    // Build a complete map for the current set of dimensions first, poplulated with defaults.
    for (final d in Dimension.values) {
      final Map<String, int> formatterMap = {};
      for (final f in formattersFor(d).entries) {
        formatterMap[f.key] = f.value.isDefault ? 1 : 0;
      }
      _dimensionMap[d.name] = formatterMap;
    }

    // Update this map using the prefs values where they exists. Note: Superficially this looked
    // similar to the _validateJsonList function, but the nested map and updating an existing
    // variable make it awkward to repeat that same pattern, just inline for now.
    final prefString = _prefs.getString(_prefKey) ?? '';
    if (prefString.isEmpty) {
      _log.info('No format usage found in shared preferences');
      return;
    }
    final dynamic decodedJson;
    try {
      decodedJson = json.decode(prefString);
    } on FormatException catch (ex) {
      _log.warning('Could not json decode format usage: $ex');
      return;
    }
    if (decodedJson is! Map<String, dynamic>) {
      _log.warning('Format usage did not decode to a json dict: $prefString');
      return;
    }

    for (final dimensionEntry in decodedJson.entries) {
      if (dimensionEntry.value is! Map<String, dynamic>) {
        _log.warning('Format usage value did not decode to a json dict: $prefString');
        return;
      }
      if (!_dimensionMap.containsKey(dimensionEntry.key)) {
        continue;
      }
      for (final formatterEntry in (dimensionEntry.value as Map<String, dynamic>).entries) {
        final usageInt = formatterEntry.value is int ? formatterEntry.value as int : null;
        if (_dimensionMap[dimensionEntry.key]?[formatterEntry.key] == null || usageInt == null) {
          continue;
        }
        _dimensionMap[dimensionEntry.key]?[formatterEntry.key] = usageInt;
      }
    }
  }

  // Record an instance of the user choosing a particular formatter on a dimension.
  void recordUsage(String? dimension, String? formatter) {
    // Leave silently if the caller provided null inputs.
    if (dimension == null || formatter == null) {
      return;
    }
    final formatters = _dimensionMap[dimension];
    if (formatters == null) {
      _log.warning('Recording format usage on unknown dimension: $dimension');
      return;
    }
    if (!formatters.containsKey(formatter)) {
      _log.warning('Recording format usage for unknown formatter on $dimension: $formatter');
      return;
    }
    formatters.updateAll((key, value) => (value * _relaxation).floor());
    formatters.update(formatter, (value) => value + _initial);
    _save();
    notifyListeners();
  }

  // Returns the most likely preffered formatter name for the supplied dimension based on past
  // usage.
  String? forDimension(String? dimension) {
    final formatters = _dimensionMap[dimension];
    if (formatters == null || formatters.isEmpty) {
      return null;
    }
    return formatters.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Saves the configuration of usage data into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, json.encode(_dimensionMap));
  }
}
