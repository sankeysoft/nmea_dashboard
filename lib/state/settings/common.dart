// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exposes all the basic settings for the application, and handles the
/// persistence of these settings.
class Settings with ChangeNotifier {
  final NetworkSettings network;
  final DerivedDataSettings derived;
  final AlarmSettings alarm;
  final UiSettings ui;
  final PageSettings pages;
  final FormatPreferences formatPreferences;
  final PackageInfo packageInfo;

  Settings(SharedPreferences prefs, String defaultPages, this.packageInfo)
    : network = NetworkSettings(prefs),
      derived = DerivedDataSettings(prefs),
      alarm = AlarmSettings(prefs),
      ui = UiSettings(prefs),
      pages = PageSettings(prefs, defaultPages),
      formatPreferences = FormatPreferences(prefs);

  static Future<Settings> create() async {
    // Create all Futures then await them all. Futures.wait() would lose
    // type information.
    final prefsFut = SharedPreferences.getInstance();
    final defaultPagesFut = getDefaultPages();
    final packageInfoFut = PackageInfo.fromPlatform();
    return Settings(await prefsFut, await defaultPagesFut, await packageInfoFut);
  }
}

Future<String> getDefaultPages() async {
  return await rootBundle.loadString('assets/default_pages.json');
}

/// A primitive value stored in a shared pref key.
class PrefValue<T> {
  final SharedPreferences _prefs;
  final String _key;
  T _value;
  PrefValue(this._prefs, this._key, T defaultVal) : _value = _read(_prefs, _key, defaultVal);

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
class PrefMappedValue<P, N> {
  final PrefValue<P> _prefValue;
  N? _nativeValue;
  final N Function(P) mapFn;
  final P Function(N) unmapFn;

  PrefMappedValue(SharedPreferences prefs, String key, N defaultVal, this.mapFn, this.unmapFn)
    : _prefValue = PrefValue(prefs, key, unmapFn(defaultVal));

  N get value {
    _nativeValue ??= mapFn(_prefValue.value);
    return _nativeValue!;
  }

  void set(N value) {
    _nativeValue = value;
    _prefValue.set(unmapFn(value));
  }
}

/// Validates the supplied input is non null and contains a json list,
/// logging detailed messages containing `target` and returning null if
/// any problems are found.
List<T>? validateJsonList<T>(
  String input,
  T Function(Map<String, dynamic>) decoder,
  String target,
  Logger log, {
  int minimumLength = 0,
}) {
  if (input.isEmpty) {
    log.info('No $target found in shared preferences');
    return null;
  }
  final dynamic decodedJson;
  try {
    decodedJson = json.decode(input);
  } on FormatException catch (ex) {
    log.warning('Could not json decode $target: $ex');
    return null;
  }
  if (decodedJson is! List<dynamic>) {
    log.warning('$target did not decode to a json list: $input');
    return null;
  }
  if (decodedJson.length < minimumLength) {
    log.warning('$target did contained ${decodedJson.length} entries');
    return null;
  }

  List<T> returnList = [];
  for (final decodedEntry in decodedJson) {
    try {
      returnList.add(decoder(decodedEntry));
    } on TypeError catch (ex) {
      log.warning('$target entry did not decode: $ex');
      return null;
    }
  }
  return returnList;
}
