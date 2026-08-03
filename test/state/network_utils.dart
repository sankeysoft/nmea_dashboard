// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:io';

import 'package:nmea_dashboard/state/network.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udp/udp.dart';

/// A reconnect trigger that only fires when a test asks it to.
class FakeReconnectTrigger implements ReconnectTrigger {
  final _controller = StreamController<String>.broadcast();
  bool disposed = false;

  @override
  Stream<String> get reasons => _controller.stream;

  void request(String reason) => _controller.add(reason);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

/// Waits until [condition] holds, polling frequently, and throws if it has not
/// happened within [timeout].
Future<void> waitFor(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

/// Returns a port number that is free at the time of the call.
Future<int> freePort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final port = probe.port;
  probe.close();
  return port;
}

/// Returns network settings backed by empty mock preferences.
Future<NetworkSettings> emptySettings() async {
  SharedPreferences.setMockInitialValues({});
  return NetworkSettings(await SharedPreferences.getInstance());
}

/// Sends the supplied packets to a UDP listen subscription reading the supplied protocol on the
/// loopback interface, returning every value the subscription received.
Future<List<BoundValue>> valuesFromUdpPackets(
  NetworkProtocol protocol,
  List<List<int>> packets, {
  bool requireChecksum = true,
}) async {
  final port = await freePort();
  final settings = (await emptySettings())
    ..set(
      mode: NetworkMode.udpListen,
      port: port,
      protocol: protocol,
      requireChecksum: requireChecksum,
    );

  final received = <BoundValue>[];
  final subscription = valuesFromNetwork(settings, customReconnectTrigger: FakeReconnectTrigger())
      .listen((v) {
        if (v != null) received.add(v);
      });

  final sender = await UDP.bind(Endpoint.any());
  final destination = Endpoint.loopback(port: Port(port));
  await Future.delayed(const Duration(milliseconds: 200));
  for (final packet in packets) {
    await sender.send(packet, destination);
  }
  await Future.delayed(const Duration(milliseconds: 300));

  await subscription.cancel();
  sender.close();
  return received;
}
