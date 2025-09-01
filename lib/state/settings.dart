// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This allows the other class to access private members in
/// the JsonSerializable generated file.
//part 'settings.g.dart';

final _log = Logger('Settings');

/// Exposes all the basic settings for the application, and handles the
/// persistence of these settings.
class Settings with ChangeNotifier {
  final NetworkSettings network;
  final DerivedDataSettings derived;
  final UiSettings ui;
  final PageSettings pages;
  final PackageInfo packageInfo;

  Settings(SharedPreferences prefs, String defaultPages, this.packageInfo)
    : network = NetworkSettings(prefs),
      derived = DerivedDataSettings(prefs),
      ui = UiSettings(prefs),
      pages = PageSettings(prefs, defaultPages);

  static Future<Settings> create() async {
    // Create all Futures then await them all. Futures.wait() would lose
    // type information.
    final prefsFut = SharedPreferences.getInstance();
    final defaultPagesFut = _getDefaultPages();
    final packageInfoFut = PackageInfo.fromPlatform();
    return Settings(await prefsFut, await defaultPagesFut, await packageInfoFut);
  }
}

Future<String> _getDefaultPages() async {
  return await rootBundle.loadString('assets/default_pages.json');
}

/// A primitive value stored in a shared pref key.
class _PrefValue<T> {
  final SharedPreferences _prefs;
  final String _key;
  T _value;
  _PrefValue(this._prefs, this._key, T defaultVal) : _value = _read(_prefs, _key, defaultVal);

  T get value => _value;

  void set(T value) {
    _value = value;
    if (T == double) {
      _prefs.setDouble(_key, _value as double);
    } else if (T == int) {
      _prefs.setInt(_key, _value as int);
    } else if (T == bool) {
      _prefs.setBool(_key, _value as bool);
    } else if (T == String) {
      _prefs.setString(_key, _value as String);
    } else {
      throw InvalidTypeException('Invalid type for PrefValue $T');
    }
  }

  static T _read<T>(SharedPreferences prefs, String key, T defaultVal) {
    if (T == double) {
      return (prefs.getDouble(key) ?? defaultVal) as T;
    } else if (T == int) {
      return (prefs.getInt(key) ?? defaultVal) as T;
    } else if (T == bool) {
      return (prefs.getBool(key) ?? defaultVal) as T;
    } else if (T == String) {
      return (prefs.getString(key) ?? defaultVal) as T;
    } else {
      throw InvalidTypeException('Invalid type for PrefValue $T');
    }
  }
}

/// A value that can be mapped to a primitive stored in a shared pref key.
class _PrefMappedValue<P, N> {
  final _PrefValue<P> _prefValue;
  N? _nativeValue;
  final N Function(P) mapFn;
  final P Function(N) unmapFn;

  _PrefMappedValue(SharedPreferences prefs, String key, N defaultVal, this.mapFn, this.unmapFn)
    : _prefValue = _PrefValue(prefs, key, unmapFn(defaultVal));

  N get value {
    _nativeValue ??= mapFn(_prefValue.value);
    return _nativeValue!;
  }

  void set(N value) {
    _nativeValue = value;
    _prefValue.set(unmapFn(value));
  }
}

/// Validates the the supplied input is non null and contains a json list,
/// logging detailed messages containing `target` and returning null if
/// any problems are found.
List<T>? _validateJsonList<T>(
  String input,
  T Function(Map<String, dynamic>) decoder,
  String target, {
  int minimumLength = 0,
}) {
  if (input.isEmpty) {
    _log.info('No $target found in shared preferences');
    return null;
  }
  final dynamic decodedJson;
  try {
    decodedJson = json.decode(input);
  } on FormatException catch (ex) {
    _log.warning('Could not json decode $target: $ex');
    return null;
  }
  if (decodedJson is! List<dynamic>) {
    _log.warning('$target did not decode to a json list: $input');
    return null;
  }
  if (decodedJson.length < minimumLength) {
    _log.warning('$target did contained ${decodedJson.length} entries');
    return null;
  }

  List<T> returnList = [];
  for (final decodedEntry in decodedJson) {
    try {
      returnList.add(decoder(decodedEntry));
    } on TypeError catch (ex) {
      _log.warning('$target entry did not decode: $ex');
      return null;
    }
  }
  return returnList;
}

/// Settings for interaction with the network.
class NetworkSettings with ChangeNotifier {
  final _PrefMappedValue<int, NetworkMode> _mode;
  final _PrefMappedValue<String, InternetAddress> _ipAddress;
  final _PrefValue<int> _port;
  final _PrefValue<bool> _requireChecksum;
  final _PrefMappedValue<int, Duration> _staleness;

  NetworkSettings(SharedPreferences prefs)
    : _mode = _PrefMappedValue(
        prefs,
        'network_mode',
        NetworkMode.udpListen,
        (p) => (p >= 0 && p < NetworkMode.values.length)
            ? NetworkMode.values[p]
            : NetworkMode.udpListen,
        (n) => n.index,
      ),
      _ipAddress = _PrefMappedValue(
        prefs,
        'network_address',
        InternetAddress("192.168.4.1"),
        (p) => InternetAddress(p),
        (n) => n.address,
      ),
      _port = _PrefValue(prefs, 'network_port', 2000),
      _requireChecksum = _PrefValue(prefs, 'network_checksum', true),
      _staleness = _PrefMappedValue(
        prefs,
        'network_staleness_seconds',
        const Duration(seconds: 10),
        (p) => Duration(seconds: p),
        (n) => n.inSeconds,
      );

  NetworkMode get mode => _mode.value;
  InternetAddress get ipAddress => _ipAddress.value;
  int get port => _port.value;
  bool get requireChecksum => _requireChecksum.value;
  Duration get staleness => _staleness.value;

  void set({
    NetworkMode? mode,
    int? port,
    InternetAddress? ipAddress,
    bool? requireChecksum,
    Duration? staleness,
  }) {
    if (mode != null) {
      _mode.set(mode);
    }
    if (port != null) {
      _port.set(port);
    }
    if (ipAddress != null) {
      _ipAddress.set(ipAddress);
    }
    if (requireChecksum != null) {
      _requireChecksum.set(requireChecksum);
    }
    if (staleness != null) {
      _staleness.set(staleness);
    }
    notifyListeners();
  }
}

// The various network connection modes.
enum NetworkMode {
  udpListen('Listen on UDP port'),
  tcpConnect('Connect to TCP port');

  final String description;
  const NetworkMode(this.description);
}

/// Settings for the user interface style.
class UiSettings with ChangeNotifier {
  final _PrefValue<bool> _firstRun;
  final _PrefValue<bool> _nightMode;
  final _PrefValue<String> _valueFont;
  final _PrefValue<String> _headingFont;

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
    : _firstRun = _PrefValue(prefs, 'ui_first_run', true),
      _nightMode = _PrefValue(prefs, 'ui_night_mode', false),
      _valueFont = _PrefValue(prefs, 'ui_value_font', 'Lexend'),
      _headingFont = _PrefValue(prefs, 'ui_heading_font', 'Manrope');

  bool get firstRun => _firstRun.value;
  bool get nightMode => _nightMode.value;
  String get valueFont => _valueFont.value;
  String get headingFont => _headingFont.value;

  void clearFirstRun() {
    _firstRun.set(false);
    notifyListeners();
  }

  void toggleNightMode() {
    setNightMode(!_nightMode.value);
  }

  void setNightMode(bool night) {
    _nightMode.set(night);
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
}

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

  /// An interator over the data specs in order.
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
    final specs = _validateJsonList(
      json,
      (e) => DerivedDataSpec.fromJson(e),
      'derived data settings',
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
    final prefString = _prefs.getString(_prefKey);
    if (!_fromJson(json: prefString ?? '', source: 'shared preferences')) {
      _fromJson(json: defaultJson, source: 'defaults');
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
    _fromJson(json: await _getDefaultPages(), source: 'defaults');
    _save();
    _selectedPageKey = null;
    notifyListeners();
  }

  /// Replaces the current set of pages with pages from a json encoded string,
  /// making no changes if the string is not valid or if dryRun is true.
  /// Returns true on success.
  bool useClipboard(String text, {bool dryRun = false}) {
    bool success = _fromJson(json: text, source: 'clipboard', dryRun: dryRun);
    if (!dryRun && success) {
      _save();
      _selectedPageKey = null;
      notifyListeners();
    }
    return success;
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

  /// Overwrites all data with pages from a json encoded string, making no
  /// changes if the string is not valid or if dryRun is true. Returns true on
  /// success.
  bool _fromJson({required String json, required String source, bool dryRun = false}) {
    // Use the helper function to convert to a list of bare specs
    final pageSpecs = _validateJsonList(
      json,
      (p) => DataPageSpec.fromJson(p),
      'page settings',
      minimumLength: 1,
    );
    // Leave with a failure if this didn't work or success we're dry running and
    // it did.
    if (pageSpecs == null) {
      return false;
    } else if (dryRun) {
      return true;
    }

    // If we're not dry run and have specs use them to create a map.
    _dataPageSpecs.clear();
    for (final spec in pageSpecs) {
      _dataPageSpecs[spec.key] = spec;
    }
    _log.info('Loaded ${pageSpecs.length} pages from $source');
    return true;
  }

  /// Saves the configuration of all data pages into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}
