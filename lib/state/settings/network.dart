// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings for interaction with the network.
class NetworkSettings with ChangeNotifier {
  final PrefMappedValue<int, NetworkMode> _mode;
  final PrefMappedValue<String, InternetAddress> _ipAddress;
  final PrefValue<int> _port;
  final PrefMappedValue<int, NetworkProtocol> _protocol;
  final PrefValue<bool> _requireChecksum;
  final PrefMappedValue<int, Duration> _staleness;
  final PrefValue<bool> _defaultVariationEnabled;
  final PrefValue<double> _defaultVariationValue;

  NetworkSettings(SharedPreferences prefs)
    : _mode = PrefMappedValue(
        prefs,
        'network_mode',
        NetworkMode.udpListen,
        (p) => (p >= 0 && p < NetworkMode.values.length)
            ? NetworkMode.values[p]
            : NetworkMode.udpListen,
        (n) => n.index,
      ),
      _ipAddress = PrefMappedValue(
        prefs,
        'network_address',
        InternetAddress("192.168.4.1"),
        (p) => InternetAddress(p),
        (n) => n.address,
      ),
      _port = PrefValue(prefs, 'network_port', 2000),
      _protocol = PrefMappedValue(
        prefs,
        'network_protocol',
        NetworkProtocol.nmea0183,
        (p) => (p >= 0 && p < NetworkProtocol.values.length)
            ? NetworkProtocol.values[p]
            : NetworkProtocol.nmea0183,
        (n) => n.index,
      ),
      _requireChecksum = PrefValue(prefs, 'network_checksum', true),
      _staleness = PrefMappedValue(
        prefs,
        'network_staleness_seconds',
        const Duration(seconds: 10),
        (p) => Duration(seconds: p),
        (n) => n.inSeconds,
      ),
      _defaultVariationEnabled = PrefValue(prefs, 'default_variation_enabled', false),
      _defaultVariationValue = PrefValue(prefs, 'default_variation_value', 0.0);

  NetworkMode get mode => _mode.value;
  InternetAddress get ipAddress => _ipAddress.value;
  int get port => _port.value;
  NetworkProtocol get protocol => _protocol.value;
  bool get requireChecksum => _requireChecksum.value;
  Duration get staleness => _staleness.value;

  /// Whether defaultVariation should be used when no variation is received from the network.
  bool get defaultVariationEnabled => _defaultVariationEnabled.value;

  /// The magnetic variation to use when none is received from the network, in degrees with east
  /// positive and west negative. Only used if defaultVariationEnabled is true.
  double get defaultVariationValue => _defaultVariationValue.value;

  void set({
    NetworkMode? mode,
    int? port,
    InternetAddress? ipAddress,
    NetworkProtocol? protocol,
    bool? requireChecksum,
    Duration? staleness,
    bool? defaultVariationEnabled,
    double? defaultVariationValue,
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
    if (protocol != null) {
      _protocol.set(protocol);
    }
    if (requireChecksum != null) {
      _requireChecksum.set(requireChecksum);
    }
    if (staleness != null) {
      _staleness.set(staleness);
    }
    if (defaultVariationEnabled != null) {
      _defaultVariationEnabled.set(defaultVariationEnabled);
    }
    if (defaultVariationValue != null) {
      _defaultVariationValue.set(defaultVariationValue);
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

// The supported protocol modes.
enum NetworkProtocol {
  nmea0183('NMEA0183', NetworkStandard.nmea0183),
  nmea2000ngt('NMEA2000 ActiSense NGT', NetworkStandard.nmea2000),
  nmea2000raw('NMEA2000 YD RAW', NetworkStandard.nmea2000);

  //nmea2000assembled('NMEA2000 Packets', NetworkStandard.nmea2000);

  final String description;

  final NetworkStandard standard;

  const NetworkProtocol(this.description, this.standard);
}
