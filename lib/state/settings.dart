// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This allows the `User` class to access private members in
/// the generated file. The value for this is *.g.dart, where
/// the star denotes the source file name.
part 'settings.g.dart';

final _log = Logger('Settings');

/// Exposes all the basic settings for the application, and handles the
/// persistence of these settings.
class Settings with ChangeNotifier {
  final NetworkSettings network;
  final DerivedDataSettings derived;
  final UiSettings ui;
  final PageSettings pages;
  final PackageInfo packageInfo;

  Settings(SharedPreferences prefs, this.packageInfo)
      : network = NetworkSettings(prefs),
        derived = DerivedDataSettings(prefs),
        ui = UiSettings(prefs),
        pages = PageSettings(prefs);

  static Future<Settings> create() async {
    // Create all Futures then await them all. Futures.wait() would lose
    // type information.
    final prefsFut = SharedPreferences.getInstance();
    final packageInfoFut = PackageInfo.fromPlatform();
    return Settings(await prefsFut, await packageInfoFut);
  }
}

/// A primitive value stored in a shared pref key.
class _PrefValue<T> {
  final SharedPreferences _prefs;
  final String _key;
  T _value;
  _PrefValue(this._prefs, this._key, T defaultVal)
      : _value = _read(_prefs, _key, defaultVal);

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

  static T _read<T>(prefs, key, T defaultVal) {
    if (T == double) {
      return prefs.getDouble(key) ?? defaultVal;
    } else if (T == int) {
      return prefs.getInt(key) ?? defaultVal;
    } else if (T == bool) {
      return prefs.getBool(key) ?? defaultVal;
    } else if (T == String) {
      return prefs.getString(key) ?? defaultVal;
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

  _PrefMappedValue(SharedPreferences prefs, String key, N defaultVal,
      this.mapFn, this.unmapFn)
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
    String input, T Function(Map<String, dynamic>) decoder, String target,
    {int minimumLength = 0}) {
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

/// A unique identifier for some item read from settings.
class _SettingsKey extends ValueKey<int> {
  const _SettingsKey(super.value);

  static int _nextValue = 1;

  static int allocate() {
    _nextValue += 1;
    return _nextValue - 1;
  }
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
            (n) => n.index),
        _ipAddress = _PrefMappedValue(
            prefs,
            'network_address',
            InternetAddress("192.168.4.1"),
            (p) => InternetAddress(p),
            (n) => n.address),
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

  void set(
      {NetworkMode? mode,
      int? port,
      InternetAddress? ipAddress,
      bool? requireChecksum,
      Duration? staleness}) {
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
    'FredokaOne',
    'Inter',
    'Kanit',
    'Lexend',
    'Manrope',
    'Orbitron',
    'Roboto',
    'Sniglet'
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
  final Map<DerivedDataKey, KeyedDerivedDataSpec> _derivedDataSpecs = {};

  /// Creates settings from the supplied prefs, starting empty if
  /// the shared prefs are missing of invalid.
  DerivedDataSettings(this._prefs) {
    final prefString = _prefs.getString(_prefKey);
    // Stick with the default empty map if load fails.
    _fromJson(json: prefString ?? '', source: 'shared preferences');
  }

  /// An interator over the data specs in order.
  Iterable<KeyedDerivedDataSpec> get derivedDataSpecs =>
      _derivedDataSpecs.values;

  /// Replaces the current set of derived data with the supplied specifications.
  void replaceElements(Iterable<KeyedDerivedDataSpec> derivedDataSpecs) {
    _derivedDataSpecs.clear();
    for (final derivedDataSpec in derivedDataSpecs) {
      _derivedDataSpecs[derivedDataSpec.key] = derivedDataSpec;
    }
    _save();
    notifyListeners();
  }

  /// Adds or replaces the supplied specification in the current set of derived data.
  void setElement(KeyedDerivedDataSpec spec) {
    _derivedDataSpecs[spec.key] = spec;
    _save();
    notifyListeners();
  }

  /// Deletes the supplied specification from current set of pages.
  void removeElement(KeyedDerivedDataSpec spec) {
    _derivedDataSpecs.remove(spec.key);
    _save();
    notifyListeners();
  }

  /// Replaces the current set of pages with pages from a json encoded string,
  /// making no changes if the string is not valid or if dryRun is true.
  /// Returns true on success.
  bool useClipboard(text, {bool dryRun = false}) {
    bool success = _fromJson(json: text, source: 'clipboard', dryRun: dryRun);
    if (!dryRun && success) {
      _save();
      notifyListeners();
    }
    return success;
  }

  /// Returns a json stringSaves the configuration of all data pages into shared prefs.
  String toJson() {
    final jsonIterator =
        _derivedDataSpecs.values.map((spec) => spec.toBareSpec()).toList();
    return json.encode(jsonIterator);
  }

  /// Overwrites all data with elements from a json encoded string, making no changes if
  /// the string is not valid or if dryRun is true. Returns true on success.
  bool _fromJson(
      {required String json, required String source, bool dryRun = false}) {
    // Use the helper function to convert to a list of bare specs
    final bareSpecs = _validateJsonList(
        json, (e) => DerivedDataSpec.fromJson(e), 'derived data settings',
        minimumLength: 0);
    // Leave with a failure if this didn't work or success we're dry running and it did.
    if (bareSpecs == null) {
      return false;
    } else if (dryRun) {
      return true;
    }

    // If we're not dry run and have bare specs use them to create a KeyedSpec in the map.
    _derivedDataSpecs.clear();
    for (final bareSpec in bareSpecs) {
      final keyedSpec = KeyedDerivedDataSpec.fromBareSpec(bareSpec);
      _derivedDataSpecs[keyedSpec.key] = keyedSpec;
    }
    _log.info('Loaded ${bareSpecs.length} derived elements from $source');
    return true;
  }

  /// Saves the configuration of all derived data into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}

/// A specification for an element of derived data and a key
/// to uniquely identify it.
class KeyedDerivedDataSpec {
  final DerivedDataKey key;
  final DerivedDataSpec _spec;

  KeyedDerivedDataSpec(this.key, this._spec);

  static KeyedDerivedDataSpec fromBareSpec(DerivedDataSpec bareSpec,
      {DerivedDataKey? key}) {
    return KeyedDerivedDataSpec(key ?? DerivedDataKey.make(), bareSpec);
  }

  DerivedDataSpec toBareSpec() => _spec;

  String get name => _spec.name;
  String get inputSource => _spec.inputSource;
  String get inputElement => _spec.inputElement;
  String get inputFormat => _spec.inputFormat;
  String get operation => _spec.operation;
  double get operand => _spec.operand;
}

/// A unique identifier for each derived data element.
class DerivedDataKey extends _SettingsKey {
  const DerivedDataKey(super.value);

  static DerivedDataKey make() {
    return DerivedDataKey(_SettingsKey.allocate());
  }
}

/// A serializable specification that may be used to recreate an
/// element of derived data.
@JsonSerializable()
class DerivedDataSpec {
  /// The name of the derived data field.
  final String name;

  /// The name of the input source.
  final String inputSource;

  /// The name of the input element within source.
  final String inputElement;

  /// The units in which to work with the input.
  final String inputFormat;

  /// The operation to apply to the input data element.
  final String operation;

  /// The value to feed into the operation.
  final double operand;

  DerivedDataSpec(this.name, this.inputSource, this.inputElement,
      this.inputFormat, this.operation, this.operand);

  factory DerivedDataSpec.fromJson(Map<String, dynamic> json) =>
      _$DerivedDataSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DerivedDataSpecToJson(this);
}

/// Settings for the data pages and their contents, notifies when the
/// set of pages changes. Each page notifies when it changes.
class PageSettings with ChangeNotifier {
  static const String _prefKey = 'page_v1';
  final SharedPreferences _prefs;
  final Map<DataPageKey, KeyedDataPageSpec> _dataPageSpecs = {};
  DataPageKey? _selectedKey;

  /// Creates a settings page from the supplied prefs, or from defaults if
  /// the shared prefs are missing of invalid.
  PageSettings(this._prefs) {
    final prefString = _prefs.getString(_prefKey);
    if (!_fromJson(json: prefString ?? '', source: 'shared preferences')) {
      _fromJson(json: _defaultPageSpecs, source: 'defaults');
    }
  }

  /// The index of the page that should be displayed by default; either the
  /// newest created page of the last selected.
  int? get selectedPageIndex {
    int idx = 0;
    for (DataPageKey key in _dataPageSpecs.keys) {
      if (key == _selectedKey) {
        return idx;
      }
      idx++;
    }
    return null;
  }

  /// Records selection of a page on some top level UI.
  void selectPage(int index) {
    _selectedKey = _dataPageSpecs.keys.toList()[index];
  }

  /// An iterator over the pages in order.
  Iterable<KeyedDataPageSpec> get dataPageSpecs => _dataPageSpecs.values;

  /// Returns a page by its key.
  KeyedDataPageSpec? lookupByKey(DataPageKey key) {
    return _dataPageSpecs[key];
  }

  /// Replaces the current set of pages with the defaults.
  void useDefaults() {
    _fromJson(json: _defaultPageSpecs, source: 'defaults');
    _save();
    _selectedKey = null;
    notifyListeners();
  }

  /// Replaces the current set of pages with pages from a json encoded string,
  /// making no changes if the string is not valid or if dryRun is true.
  /// Returns true on success.
  bool useClipboard(text, {bool dryRun = false}) {
    bool success = _fromJson(json: text, source: 'clipboard', dryRun: dryRun);
    if (!dryRun && success) {
      _save();
      _selectedKey = null;
      notifyListeners();
    }
    return success;
  }

  /// Replaces the current set of pages with the supplied specifications.
  void replacePages(Iterable<KeyedDataPageSpec> pageSpecs) {
    _dataPageSpecs.clear();
    for (final pageSpec in pageSpecs) {
      _dataPageSpecs[pageSpec.key] = pageSpec;
    }
    _save();
    notifyListeners();
  }

  /// Adds or replaces the supplied specification in the current set of pages.
  void setPage(KeyedDataPageSpec pageSpec) {
    // Update most recently selected if we don't already have this key.
    if (!_dataPageSpecs.containsKey(pageSpec.key)) {
      _selectedKey = pageSpec.key;
    }
    _dataPageSpecs[pageSpec.key] = pageSpec;
    _save();
    notifyListeners();
  }

  /// Deletes the supplied specification from current set of pages.
  void removePage(KeyedDataPageSpec pageSpec) {
    _dataPageSpecs.remove(pageSpec.key);
    _save();
    notifyListeners();
  }

  /// Updates the supplied cell key with a new specification.
  void updateCell(DataCellKey cellKey, DataCellSpec cellSpec) {
    final page = _dataPageSpecs[cellKey.pageKey];
    if (page == null) {
      _log.warning('Could not find page to update ${cellKey.pageKey}');
    } else {
      page.updateCell(cellKey, cellSpec);
      _save();
    }
  }

  /// Returns a json stringSaves the configuration of all data pages into shared prefs.
  String toJson() {
    final jsonIterator =
        _dataPageSpecs.values.map((pageSpec) => pageSpec.toBareSpec()).toList();
    return json.encode(jsonIterator);
  }

  /// Overwrites all data with pages from a json encoded string, making no changes if
  /// the string is not valid or if dryRun is true. Returns true on success.
  bool _fromJson(
      {required String json, required String source, bool dryRun = false}) {
    // Use the helper function to convert to a list of bare specs
    final barePageSpecs = _validateJsonList(
        json, (p) => DataPageSpec.fromJson(p), 'page settings',
        minimumLength: 1);
    // Leave with a failure if this didn't work or success we're dry running and it did.
    if (barePageSpecs == null) {
      return false;
    } else if (dryRun) {
      return true;
    }

    // If we're not dry run and have bare specs use them to create a KeyedSpec in the map.
    _dataPageSpecs.clear();
    for (final bareSpec in barePageSpecs) {
      final keyedSpec = KeyedDataPageSpec.fromBareSpec(bareSpec);
      _dataPageSpecs[keyedSpec.key] = keyedSpec;
    }
    _log.info('Loaded ${barePageSpecs.length} pages from $source');
    return true;
  }

  /// Saves the configuration of all data pages into shared prefs.
  void _save() {
    _prefs.setString(_prefKey, toJson());
  }
}

/// A specification for a data page and a key to uniquely identify it.
class KeyedDataPageSpec extends ChangeNotifier {
  final DataPageKey key;
  final String _name;
  final List<KeyedDataCellSpec> _cellList;
  final Map<DataCellKey, KeyedDataCellSpec> _cellMap = {};

  KeyedDataPageSpec(this.key, this._name, this._cellList) {
    // Build the map for fast lookup.
    for (final cell in _cellList) {
      _cellMap[cell.key] = cell;
    }
  }

  static KeyedDataPageSpec fromBareSpec(DataPageSpec barePage,
      {DataPageKey? key}) {
    final pageKey = key ?? DataPageKey.make();
    final cellList = barePage.cells
        .map((bareCell) =>
            KeyedDataCellSpec(DataCellKey.make(pageKey), bareCell))
        .toList();
    return KeyedDataPageSpec(pageKey, barePage.name, cellList);
  }

  DataPageSpec toBareSpec() {
    return DataPageSpec(
        _name, cells.map((keyedCell) => keyedCell.toBareSpec()).toList());
  }

  String get name => _name;
  List<KeyedDataCellSpec> get cells => _cellList;

  /// Updates the supplied cell key with a new specification.
  void updateCell(DataCellKey cellKey, DataCellSpec cellSpec) {
    final cell = _cellMap[cellKey];
    if (cell == null) {
      _log.warning('Could not find cell to update $cellKey');
    } else {
      cell._spec = cellSpec;
      notifyListeners();
    }
  }
}

/// A unique identifier for each data page.
class DataPageKey extends _SettingsKey {
  const DataPageKey(super.value);

  static DataPageKey make() {
    return DataPageKey(_SettingsKey.allocate());
  }
}

/// A serializable specification that may be used to recreate a table
/// of data elements.
@JsonSerializable(explicitToJson: true)
class DataPageSpec {
  /// A short name for the page
  final String name;

  /// The data to display in the table
  final List<DataCellSpec> cells;

  DataPageSpec(this.name, this.cells);

  factory DataPageSpec.fromJson(Map<String, dynamic> json) =>
      _$DataPageSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DataPageSpecToJson(this);
}

/// A specification for a data page and a key to uniquely identify it.
class KeyedDataCellSpec {
  final DataCellKey key;
  DataCellSpec _spec;

  KeyedDataCellSpec(this.key, this._spec);

  DataCellSpec toBareSpec() => _spec;

  String get source => _spec.source;
  String get element => _spec.element;
  String get format => _spec.format;
  String? get name => _spec.name;
}

/// A unique identifier for each data cell.
class DataCellKey extends _SettingsKey {
  final DataPageKey pageKey;
  const DataCellKey(super.value, this.pageKey);

  static DataCellKey make(DataPageKey pageKey) {
    return DataCellKey(_SettingsKey.allocate(), pageKey);
  }
}

/// A serializable specification that may be used to recreate a displayable
/// data element.
@JsonSerializable()
class DataCellSpec {
  /// The name of the source.
  final String source;

  /// The name of the element supplying data within source.
  final String element;

  /// The format to use when rendering the element.
  final String format;

  /// An optional name to override the source name on display.
  final String? name;

  DataCellSpec(this.source, this.element, this.format, {this.name});

  factory DataCellSpec.fromJson(Map<String, dynamic> json) =>
      _$DataCellSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DataCellSpecToJson(this);
}

const String _defaultPageSpecs = '''
[{
	"name": "Standard",
	"cells": [
    {"source": "local", "element": "localTime", "format": "hms"},
    {"source": "network", "element": "heading", "format": "mag"},
		{"source": "network", "element": "distanceTrip", "format": "nm"},
		{"source": "network", "element": "depthWithOffset", "format": "feet"},
		{"source": "network", "element": "speedThroughWater", "format": "knots"},
		{"source": "network", "element": "trueWindSpeed", "format": "knots"},
		{"source": "network", "element": "trueWindDirection", "format": "true"},
		{"source": "network", "element": "pressure", "format": "millibars"},
		{"source": "network", "element": "speedOverGround", "format": "knots"},
	  {"source": "network", "element": "gpsPosition", "format": "degMin"}
  ]
}, {
	"name": "All data",
	"cells": [
    {"source": "local", "element": "utcTime", "format": "ymdhms"},
		{"source": "network", "element": "gpsPosition", "format": "degMinSec"},
		{"source": "network", "element": "gpsHdop", "format": "meters"},
		{"source": "network", "element": "heading", "format": "mag"},
		{"source": "network", "element": "courseOverGround", "format": "mag"},
		{"source": "network", "element": "variation", "format": "degrees"},
		{"source": "network", "element": "rateOfTurn", "format": "degreesPerSec"},
		{"source": "network", "element": "distanceTrip", "format": "nm"},
		{"source": "network", "element": "distanceTotal", "format": "nm"},
		{"source": "network", "element": "speedOverGround", "format": "knots"},
		{"source": "network", "element": "speedThroughWater", "format": "knots"},
		{"source": "network", "element": "currentSet", "format": "true"},
		{"source": "network", "element": "currentDrift", "format": "knots"},
		{"source": "network", "element": "depthWithOffset", "format": "feet"},
		{"source": "network", "element": "depthUncalibrated", "format": "feet"},
		{"source": "network", "element": "trueWindSpeed", "format": "knots"},
		{"source": "network", "element": "trueWindDirection", "format": "true"},
		{"source": "network", "element": "pressure", "format": "millibars"},
		{"source": "network", "element": "apparentWindSpeed", "format": "knots"},
		{"source": "network", "element": "apparentWindAngle", "format": "degrees"},
		{"source": "network", "element": "waterTemperature", "format": "farenheit"},
		{"source": "network", "element": "roll", "format": "degrees"},
		{"source": "network", "element": "pitch", "format": "degrees"},
		{"source": "network", "element": "rudderAngle", "format": "degrees"}
  ]
}, {
  "name": "Medium",
  "cells": [
    {"source": "local", "element": "localTime", "format": "hms"},
    {"source": "network", "element": "heading", "format": "mag"},
    {"source": "network", "element": "distanceTrip", "format": "nm"},
    {"source": "network", "element": "depthWithOffset", "format": "feet"},
		{"source": "network", "element": "speedThroughWater", "format": "knots2dp"},
		{"source": "network", "element": "speedOverGround", "format": "knots2dp"},
		{"source": "network", "element": "trueWindSpeed", "format": "knots"},
		{"source": "network", "element": "trueWindDirection", "format": "true"},
		{"source": "network", "element": "gpsPosition", "format": "degMin"},
		{"source": "network", "element": "pressure", "format": "millibars"},
		{"source": "network", "element": "waterTemperature", "format": "farenheit"},
		{"source": "network", "element": "apparentWindSpeed", "format": "knots"}
  ]
}]
''';
