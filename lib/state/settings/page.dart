// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('PageSettings');

Future<String> _getDefaultPages() async {
  return await rootBundle.loadString('assets/default_pages.json');
}

/// Settings for the data pages and their contents, notifies when the
/// set of pages changes. Each page notifies when it changes.
class PageSettings with ChangeNotifier {
  static const String _prefKey = 'page_v1';
  final SharedPreferences _prefs;
  final Map<SpecKey, DataPageSpec> _dataPageSpecs = {};
  SpecKey? _selectedPageKey;

  /// Creates a settings page from the supplied prefs, or from defaults if
  /// the shared prefs are missing or invalid.
  PageSettings(this._prefs, String defaultJson) {
    if (!_useJson(prefJson(_prefs, _prefKey, _log), 'shared preferences')) {
      _useJson(decodeJson(defaultJson, 'default pages', _log), 'defaults');
    }
  }

  /// The index of the page that should be displayed by default; either the
  /// newest created page or the last selected.
  int? get selectedPageIndex {
    int idx = 0;
    for (SpecKey pageKey in _dataPageSpecs.keys) {
      if (pageKey == _selectedPageKey) {
        return idx;
      }
      idx++;
    }
    return null;
  }

  /// Records selection of a page on some top level UI.
  void selectPage(int index) {
    _selectedPageKey = _dataPageSpecs.keys.toList()[index];
  }

  /// An iterator over the pages in order.
  Iterable<DataPageSpec> get dataPageSpecs => _dataPageSpecs.values;

  /// Returns a page by its key.
  DataPageSpec? lookupByKey(SpecKey pageKey) {
    return _dataPageSpecs[pageKey];
  }

  /// Replaces the current set of pages with the defaults.
  void useDefaults() async {
    _useJson(decodeJson(await _getDefaultPages(), 'default pages', _log), 'defaults');
    _save();
    _selectedPageKey = null;
    notifyListeners();
  }

  /// Replaces the current set of pages with pages from clipboard text, making no changes if the
  /// text is not valid or if dryRun is true. Returns true on success.
  bool useClipboard(String text, {bool dryRun = false}) {
    final pageSpecs = validateJsonList(
      clipboardData(text, ClipboardKind.pages),
      (p) => DataPageSpec.fromJson(p),
      'pages clipboard',
      _log,
      minimumLength: 1,
    );
    if (pageSpecs == null) {
      return false;
    } else if (!dryRun) {
      _usePages(pageSpecs, 'clipboard');
      _save();
      _selectedPageKey = null;
      notifyListeners();
    }
    return true;
  }

  /// Returns clipboard text containing the configuration of all pages.
  String toClipboard() {
    return encodeClipboard(ClipboardKind.pages, _dataPageSpecs.values.toList());
  }

  /// Returns clipboard text containing the configuration of a single page.
  static String pageToClipboard(DataPageSpec pageSpec) {
    return encodeClipboard(ClipboardKind.page, pageSpec);
  }

  /// Returns a new page spec from clipboard text, or null if the text is not valid.
  static DataPageSpec? pageFromClipboard(String text) {
    return validateJsonObject(
      clipboardData(text, ClipboardKind.page),
      (p) => DataPageSpec.fromJson(p),
      'page clipboard',
      _log,
    );
  }

  /// Returns clipboard text containing the configuration of a single cell.
  static String cellToClipboard(DataCellSpec cellSpec) {
    return encodeClipboard(ClipboardKind.cell, cellSpec);
  }

  /// Returns a new cell spec from clipboard text, or null if the text is not valid.
  static DataCellSpec? cellFromClipboard(String text) {
    return validateJsonObject(
      clipboardData(text, ClipboardKind.cell),
      (c) => DataCellSpec.fromJson(c),
      'cell clipboard',
      _log,
    );
  }

  /// Replaces the current set of pages with the supplied specifications.
  void replacePages(Iterable<DataPageSpec> pageSpecs) {
    _dataPageSpecs.clear();
    for (final pageSpec in pageSpecs) {
      _dataPageSpecs[pageSpec.key] = pageSpec;
    }
    _save();
    notifyListeners();
  }

  /// Adds or replaces the supplied specification in the current set of pages.
  void setPage(DataPageSpec pageSpec) {
    // Update most recently selected if we don't already have this key.
    if (!_dataPageSpecs.containsKey(pageSpec.key)) {
      _selectedPageKey = pageSpec.key;
    }
    _dataPageSpecs[pageSpec.key] = pageSpec;
    _save();
    notifyListeners();
  }

  /// Deletes the supplied specification from current set of pages.
  void removePage(DataPageSpec pageSpec) {
    _dataPageSpecs.remove(pageSpec.key);
    _save();
    notifyListeners();
  }

  /// Updates the supplied cell specification using its key.
  void updateCell(DataCellSpec cellSpec) {
    for (final page in _dataPageSpecs.values) {
      if (page.containsCell(cellSpec.key)) {
        page.updateCell(cellSpec);
        _save();
        return;
      }
    }
    _log.warning('Could not find page to update ${cellSpec.key}');
  }

  /// Returns a json string containing the configuration of all pages.
  String toJson() {
    final jsonIterator = _dataPageSpecs.values.toList();
    return json.encode(jsonIterator);
  }

  /// Overwrites all data with pages from decoded json, making no changes if
  /// the json is not valid. Returns true on success.
  bool _useJson(Object? decodedJson, String source) {
    // Use the helper function to convert to a list of bare specs
    final pageSpecs = validateJsonList(
      decodedJson,
      (p) => DataPageSpec.fromJson(p),
      'page settings',
      _log,
      minimumLength: 1,
    );
    if (pageSpecs == null) {
      return false;
    }
    _usePages(pageSpecs, source);
    return true;
  }

  /// Replaces the map of pages with the supplied specs.
  void _usePages(List<DataPageSpec> pageSpecs, String source) {
    _dataPageSpecs.clear();
    for (final spec in pageSpecs) {
      _dataPageSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${pageSpecs.length} pages from $source');
  }

  /// Saves the configuration of all data pages into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}
