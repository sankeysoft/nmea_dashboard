// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Satisfy the wakelock Pigeon channel so setKeepScreenAwake() doesn't throw.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  test('uses defaults when prefs are empty', () async {
    final s = NetworkSettings(await _prefs());
    expect(s.mode, NetworkMode.udpListen);
    expect(s.ipAddress.address, '192.168.4.1');
    expect(s.port, 2000);
    expect(s.protocol, NetworkProtocol.nmea0183);
    expect(s.requireChecksum, isTrue);
    expect(s.staleness, const Duration(seconds: 10));
  });

  test('reads stored values from prefs', () async {
    final s = NetworkSettings(
      await _prefs({
        'network_mode': 1,
        'network_address': '10.0.0.1',
        'network_port': 3000,
        'network_protocol': 1,
        'network_checksum': false,
        'network_staleness_seconds': 30,
      }),
    );
    expect(s.mode, NetworkMode.tcpConnect);
    expect(s.ipAddress.address, '10.0.0.1');
    expect(s.port, 3000);
    expect(s.protocol, NetworkProtocol.nmea2000ngt);
    expect(s.requireChecksum, isFalse);
    expect(s.staleness, const Duration(seconds: 30));
  });

  test('out-of-range mode index falls back to udpListen', () async {
    final s = NetworkSettings(await _prefs({'network_mode': 99}));
    expect(s.mode, NetworkMode.udpListen);
  });

  test('out-of-range protocol index falls back to nmea0183', () async {
    expect(
      NetworkSettings(await _prefs({'network_protocol': 99})).protocol,
      NetworkProtocol.nmea0183,
    );
    expect(
      NetworkSettings(await _prefs({'network_protocol': -1})).protocol,
      NetworkProtocol.nmea0183,
    );
  });

  test('set() updates all fields and persists to prefs', () async {
    final p = await _prefs();
    final s = NetworkSettings(p);
    s.set(
      mode: NetworkMode.tcpConnect,
      port: 5000,
      ipAddress: InternetAddress('10.0.0.2'),
      protocol: NetworkProtocol.nmea2000ngt,
      requireChecksum: false,
      staleness: const Duration(seconds: 20),
    );
    expect(s.mode, NetworkMode.tcpConnect);
    expect(s.port, 5000);
    expect(s.ipAddress.address, '10.0.0.2');
    expect(s.protocol, NetworkProtocol.nmea2000ngt);
    expect(s.requireChecksum, isFalse);
    expect(s.staleness, const Duration(seconds: 20));
    expect(p.getInt('network_mode'), 1);
    expect(p.getString('network_address'), '10.0.0.2');
    expect(p.getInt('network_port'), 5000);
    expect(p.getInt('network_protocol'), 1);
    expect(p.getBool('network_checksum'), isFalse);
    expect(p.getInt('network_staleness_seconds'), 20);
  });

  test('set() with only some fields leaves others unchanged', () async {
    final s = NetworkSettings(await _prefs());
    s.set(port: 9999);
    expect(s.mode, NetworkMode.udpListen);
    expect(s.port, 9999);
    expect(s.requireChecksum, isTrue);
  });

  test('set() notifies listeners', () async {
    final s = NetworkSettings(await _prefs());
    int count = 0;
    s.addListener(() => count++);
    s.set(port: 9999);
    expect(count, 1);
  });
}
