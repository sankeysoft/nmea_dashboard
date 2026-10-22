// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/parsing/0183/common.dart';
import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/network.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:udp/udp.dart';

import 'network_utils.dart';

// A valid DPT sentence that yields depthWithOffset and depthUncalibrated.
const _dpt = r'$YDDPT,18.56,-1.61,140.0,*67';

// A valid MTW sentence that yields waterTemperature.
const _mtw = r'$YDMTW,21.5,C*08';

// The same MTW sentence without its checksum.
const _mtwNoChecksum = r'$YDMTW,21.5,C';

Uint8List _pkt(String s) => Uint8List.fromList(s.codeUnits);

/// A fake platform implementation letting tests drive connectivity events.
class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _current;

  _FakeConnectivityPlatform(this._current);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  void emit(List<ConnectivityResult> results) {
    _current = results;
    _controller.add(results);
  }
}

/// Drives the binding through a background/foreground cycle.
void _cycleAppToForeground() {
  final binding = WidgetsBinding.instance;
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
}

/// Runs [body] against a new trigger, returning every reason it reported.
List<String> _collectReasons(
  _FakeConnectivityPlatform platform,
  void Function(FakeAsync async) body,
) {
  final reasons = <String>[];
  late final PlatformReconnectTrigger trigger;
  fakeAsync((async) {
    ConnectivityPlatform.instance = platform;
    trigger = PlatformReconnectTrigger();
    trigger.reasons.listen(reasons.add);
    // Let the initial connectivity check complete before the test runs.
    async.elapse(const Duration(seconds: 1));
    body(async);
    async.elapse(const Duration(seconds: 5));
    trigger.dispose();
    async.flushTimers();
  });
  return reasons;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('makePacketProcessingFunction', () {
    late PacketProcessor processPackets;

    setUp(() {
      processPackets = makePacketProcessingFunction(
        CrlfMessageSplitter(startRegex: RegExp(r'[\$!]')),
        Nmea0183Validator(true),
        Nmea0183Parser(),
      );
    });

    test('empty packet yields null', () async {
      final stream = processPackets(Stream.fromIterable([Uint8List(0)]));
      expect(await stream.take(1).toList(), [null]);
    });

    test('LF-terminated sentence yields parsed BoundValues', () async {
      final stream = processPackets(Stream.fromIterable([_pkt('$_dpt\n')]));
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('CRLF-terminated sentence yields parsed BoundValues', () async {
      final stream = processPackets(Stream.fromIterable([_pkt('$_dpt\r\n')]));
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('sentences from multiple packets yield all values', () async {
      // Each packet supplies one complete sentence.
      final stream = processPackets(Stream.fromIterable([_pkt('$_dpt\n'), _pkt('$_dpt\n')]));
      final values = await stream.where((v) => v != null).map((v) => v!).take(4).toList();
      expect(values.map((v) => v.property), [
        Property.depthWithOffset,
        Property.depthUncalibrated,
        Property.depthWithOffset,
        Property.depthUncalibrated,
      ]);
    });

    test('sentence split across two packets yields values', () async {
      final mid = _dpt.length ~/ 2;
      final stream = processPackets(
        Stream.fromIterable([_pkt(_dpt.substring(0, mid)), _pkt('${_dpt.substring(mid)}\n')]),
      );
      final values = await stream.where((v) => v != null).map((v) => v!).take(2).toList();
      expect(values.map((v) => v.property), [Property.depthWithOffset, Property.depthUncalibrated]);
    });

    test('adjacent sentences without line terminators yield all values', () async {
      // The $ starting the third sentence flushes the second out of remaining.
      final stream = processPackets(Stream.fromIterable([_pkt('$_dpt$_dpt\n\$')]));
      final values = await stream.where((v) => v != null).map((v) => v!).take(4).toList();
      expect(values.map((v) => v.property), [
        Property.depthWithOffset,
        Property.depthUncalibrated,
        Property.depthWithOffset,
        Property.depthUncalibrated,
      ]);
    });

    test('invalid checksum logs warning and yields no value', () async {
      final stream = processPackets(
        Stream.fromIterable([
          _pkt(
            r'$YDDPT,18.56,-1.61,140.0,*00'
            '\n',
          ),
          Uint8List(0),
        ]),
      );
      // The FormatException is caught; the subsequent empty packet emits null.
      expect(await stream.take(1).toList(), [null]);
    });
  });

  group('makePacketProcessingFunction invalid data detection', () {
    const invalid = 'not nmea\n';
    late PacketProcessor processPackets;

    setUp(() {
      processPackets = makePacketProcessingFunction(
        CrlfMessageSplitter(startRegex: RegExp(r'[\$!]')),
        Nmea0183Validator(true),
        Nmea0183Parser(),
      );
    });

    /// Processes [packets], returning every invalid data report logged.
    Future<List<String>> reports(List<String> packets) async {
      final reports = <String>[];
      final logs = Logger.root.onRecord
          .where((r) => r.loggerName == 'Network' && r.message.contains('consecutive invalid'))
          .listen((r) => reports.add(r.message));
      await processPackets(Stream.fromIterable(packets.map(_pkt))).drain<void>();
      await logs.cancel();
      return reports;
    }

    test('reports after 50 consecutive invalid packets', () async {
      expect(await reports(List.filled(49, invalid)), isEmpty);
      expect(await reports([invalid]), hasLength(1));
    });

    test('reports only once', () async {
      expect(await reports(List.filled(200, invalid)), hasLength(1));
    });

    test('a valid message resets the count', () async {
      expect(
        await reports([...List.filled(49, invalid), '$_mtw\n', ...List.filled(49, invalid)]),
        isEmpty,
      );
    });

    test('a packet containing both valid and invalid messages resets the count', () async {
      expect(
        await reports([
          ...List.filled(49, invalid),
          // The trailing start marker forces the splitter to flush the valid sentence.
          '$invalid$_mtw\n\$',
          ...List.filled(49, invalid),
        ]),
        isEmpty,
      );
    });

    test('packets containing only partial messages do not affect the count', () async {
      expect(
        await reports([...List.filled(49, invalid), r'$YDMTW', ...List.filled(49, ',')]),
        isEmpty,
      );
    });

    test('counts data discarded by the splitter', () async {
      // Packets too long to be a message and with no terminator are discarded by the splitter.
      expect(await reports(List.filled(50, 'x' * 1030)), hasLength(1));
    });
  });

  group('valuesFromNetwork', () {
    test('udp listen receives values and releases the port when cancelled', () async {
      final port = await freePort();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: port, protocol: NetworkProtocol.nmea0183);

      final received = [];
      final subscription =
          valuesFromNetwork(settings, customReconnectTrigger: FakeReconnectTrigger()).listen((v) {
            if (v != null) received.add(v.property);
          });

      final sender = await UDP.bind(Endpoint.any());
      await Future.delayed(const Duration(milliseconds: 200));
      await sender.send('$_mtw\r\n'.codeUnits, Endpoint.loopback(port: Port(port)));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, isNotEmpty);

      await subscription.cancel();
      await Future.delayed(const Duration(milliseconds: 200));

      // An exclusive bind only succeeds if the receiver released the port on cancellation.
      final rebind = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: false,
      );
      rebind.close();
      sender.close();
    });

    test('udp listen yields periodic nulls when no traffic is present', () async {
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: await freePort());
      expect(
        await valuesFromNetwork(
          settings,
          customReconnectTrigger: FakeReconnectTrigger(),
        ).take(2).toList(),
        [null, null],
      );
    });

    test('udp listen keeps parsing after a malformed packet', () async {
      final port = await freePort();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: port, protocol: NetworkProtocol.nmea0183);

      final received = [];
      final subscription =
          valuesFromNetwork(settings, customReconnectTrigger: FakeReconnectTrigger()).listen((v) {
            if (v != null) received.add(v.property);
          });

      final sender = await UDP.bind(Endpoint.any());
      final destination = Endpoint.loopback(port: Port(port));
      await Future.delayed(const Duration(milliseconds: 200));
      await sender.send([0xFF, 0xFE, 0x00, 0x80, 0x41], destination);
      await Future.delayed(const Duration(milliseconds: 100));
      // The malformed bytes remain buffered ahead of the first sentence, so the split falls on
      // its leading '$' and a second sentence is needed to flush the first one out.
      await sender.send('$_mtw\r\n'.codeUnits, destination);
      await sender.send('$_mtw\r\n'.codeUnits, destination);
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, contains(Property.waterTemperature));

      await subscription.cancel();
      sender.close();
    });

    test('udp listen honours the require checksum setting', () async {
      final packet = '$_mtwNoChecksum\r\n'.codeUnits;
      expect(
        await valuesFromUdpPackets(NetworkProtocol.nmea0183, [packet], requireChecksum: false),
        isNotEmpty,
      );
      expect(await valuesFromUdpPackets(NetworkProtocol.nmea0183, [packet]), isEmpty);
    });

    test('tcp connect reconnects after the peer drops the connection', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = StreamQueue(server);

      final settings = (await emptySettings())
        ..set(
          mode: NetworkMode.tcpConnect,
          ipAddress: InternetAddress.loopbackIPv4,
          port: server.port,
          protocol: NetworkProtocol.nmea0183,
        );

      final received = [];
      final subscription =
          valuesFromNetwork(settings, customReconnectTrigger: FakeReconnectTrigger()).listen((v) {
            if (v != null) received.add(v.property);
          });

      final first = await accepted.next.timeout(const Duration(seconds: 5));
      first.add('$_mtw\r\n'.codeUnits);
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, contains(Property.waterTemperature));
      received.clear();

      first.destroy();

      final second = await accepted.next.timeout(const Duration(seconds: 10));
      second.add('$_mtw\r\n'.codeUnits);
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, contains(Property.waterTemperature));

      await subscription.cancel();
      await accepted.cancel();
    });

    test('tcp connect receives values and closes the connection when cancelled', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = Completer<Socket>();
      final disconnected = Completer<void>();
      server.listen((connection) {
        accepted.complete(connection);
        connection.listen((_) {}, onDone: disconnected.complete);
      });

      final settings = (await emptySettings())
        ..set(
          mode: NetworkMode.tcpConnect,
          ipAddress: InternetAddress.loopbackIPv4,
          port: server.port,
          protocol: NetworkProtocol.nmea0183,
        );

      final received = [];
      final subscription =
          valuesFromNetwork(settings, customReconnectTrigger: FakeReconnectTrigger()).listen((v) {
            if (v != null) received.add(v.property);
          });

      final connection = await accepted.future.timeout(const Duration(seconds: 5));
      connection.add('$_mtw\r\n'.codeUnits);
      await Future.delayed(const Duration(milliseconds: 300));
      expect(received, isNotEmpty);

      await subscription.cancel();
      // The server only sees the connection end if the client released its socket on cancellation.
      await disconnected.future.timeout(const Duration(seconds: 5));
      await server.close();
    });
  });

  group('valuesFromNetwork reconnects', () {
    test('udp listen rebinds and keeps delivering values when requested', () async {
      final port = await freePort();
      final trigger = FakeReconnectTrigger();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: port, protocol: NetworkProtocol.nmea0183);

      final received = [];
      final subscription = valuesFromNetwork(settings, customReconnectTrigger: trigger).listen((v) {
        if (v != null) received.add(v.property);
      });

      final sender = await UDP.bind(Endpoint.any());
      final destination = Endpoint.loopback(port: Port(port));
      await Future.delayed(const Duration(milliseconds: 200));
      await sender.send('$_mtw\r\n'.codeUnits, destination);
      await waitFor(() => received.isNotEmpty);
      received.clear();

      trigger.request('test');

      // The same subscription keeps working over the replacement socket, which
      // is only possible if the old one released the port.
      await waitFor(() async {
        await sender.send('$_mtw\r\n'.codeUnits, destination);
        return received.isNotEmpty;
      });
      expect(received, contains(Property.waterTemperature));

      await subscription.cancel();
      sender.close();
    });

    test('tcp connect makes a new connection when requested', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = StreamQueue(server);
      final trigger = FakeReconnectTrigger();

      final settings = (await emptySettings())
        ..set(
          mode: NetworkMode.tcpConnect,
          ipAddress: InternetAddress.loopbackIPv4,
          port: server.port,
          protocol: NetworkProtocol.nmea0183,
        );

      final received = [];
      final subscription = valuesFromNetwork(settings, customReconnectTrigger: trigger).listen((v) {
        if (v != null) received.add(v.property);
      });

      final first = await accepted.next.timeout(const Duration(seconds: 5));
      var firstClosed = false;
      first.listen((_) {}, onDone: () => firstClosed = true);
      first.add('$_mtw\r\n'.codeUnits);
      await waitFor(() => received.isNotEmpty);
      received.clear();

      trigger.request('test');

      // The peer never closed the first connection, so the client must have.
      await waitFor(() => firstClosed);
      final second = await accepted.next.timeout(const Duration(seconds: 10));
      second.add('$_mtw\r\n'.codeUnits);
      await waitFor(() => received.isNotEmpty);
      expect(received, contains(Property.waterTemperature));

      await subscription.cancel();
      await accepted.cancel();
      await server.close();
    });

    test('cancelling the subscription disposes the trigger', () async {
      final trigger = FakeReconnectTrigger();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: await freePort());

      final subscription = valuesFromNetwork(
        settings,
        customReconnectTrigger: trigger,
      ).listen((_) {});
      await Future.delayed(const Duration(milliseconds: 200));
      expect(trigger.disposed, isFalse);

      await subscription.cancel();
      expect(trigger.disposed, isTrue);
    });

    test('a reconnect requested during cancellation does not reopen the port', () async {
      final port = await freePort();
      final trigger = FakeReconnectTrigger();
      final settings = (await emptySettings())..set(mode: NetworkMode.udpListen, port: port);

      final subscription = valuesFromNetwork(
        settings,
        customReconnectTrigger: trigger,
      ).listen((_) {});
      await Future.delayed(const Duration(milliseconds: 200));

      // Request a reconnect that is still in flight when the stream is cancelled.
      trigger.request('test');
      await subscription.cancel();
      await Future.delayed(const Duration(seconds: 4));

      // An exclusive bind only succeeds if no replacement socket was opened.
      final rebind = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: false,
      );
      rebind.close();
    });
  });

  group('valuesFromNetwork idle watchdog', () {
    /// Collects every network log message matching [prefix] until cancelled.
    StreamSubscription collectLogs(List<String> into, {String prefix = ''}) {
      return Logger.root.onRecord
          .where((r) => r.loggerName == 'Network' && r.message.startsWith(prefix))
          .listen((r) => into.add(r.message));
    }

    test('udp listen rebinds and resumes receiving after no data arrives', () async {
      final port = await freePort();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: port, protocol: NetworkProtocol.nmea0183);

      final warnings = <String>[];
      final logs = collectLogs(warnings, prefix: 'No data received');

      final received = [];
      final subscription =
          valuesFromNetwork(
            settings,
            customReconnectTrigger: FakeReconnectTrigger(),
            customIdleTimeout: const Duration(milliseconds: 1),
          ).listen((v) {
            if (v != null) received.add(v.property);
          });

      await waitFor(() => warnings.isNotEmpty);
      expect(warnings.first, contains('No data received on UDP port $port'));

      // The replacement socket takes the same port and still delivers values.
      final sender = await UDP.bind(Endpoint.any());
      final destination = Endpoint.loopback(port: Port(port));
      await waitFor(() async {
        await sender.send('$_mtw\r\n'.codeUnits, destination);
        return received.isNotEmpty;
      });
      expect(received, contains(Property.waterTemperature));

      await subscription.cancel();
      await logs.cancel();
      sender.close();
    });

    test('a quiet connection is left alone until the idle timeout expires', () async {
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: await freePort());

      final warnings = <String>[];
      final logs = collectLogs(warnings, prefix: 'No data received');

      final subscription = valuesFromNetwork(
        settings,
        customReconnectTrigger: FakeReconnectTrigger(),
        customIdleTimeout: const Duration(seconds: 20),
      ).listen((_) {});

      await Future.delayed(const Duration(seconds: 5));
      expect(warnings, isEmpty);

      await subscription.cancel();
      await logs.cancel();
    });

    test('data that produces no values still counts as a live connection', () async {
      final port = await freePort();
      final settings = (await emptySettings())
        ..set(mode: NetworkMode.udpListen, port: port, protocol: NetworkProtocol.nmea0183);

      final warnings = <String>[];
      final logs = collectLogs(warnings, prefix: 'No data received');

      final received = [];
      final subscription =
          valuesFromNetwork(
            settings,
            customReconnectTrigger: FakeReconnectTrigger(),
            customIdleTimeout: const Duration(seconds: 4),
          ).listen((v) {
            if (v != null) received.add(v);
          });

      // Bytes that never form a sentence, as a misconfigured protocol would give.
      final sender = await UDP.bind(Endpoint.any());
      final destination = Endpoint.loopback(port: Port(port));
      final until = DateTime.now().add(const Duration(seconds: 7));
      while (DateTime.now().isBefore(until)) {
        await sender.send([0x01, 0x02, 0x03, 0x04], destination);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      expect(received, isEmpty);
      expect(warnings, isEmpty);

      await subscription.cancel();
      await logs.cancel();
      sender.close();
    });

    test('tcp connect reports an idle timeout rather than a peer disconnect', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = StreamQueue(server);

      final settings = (await emptySettings())
        ..set(
          mode: NetworkMode.tcpConnect,
          ipAddress: InternetAddress.loopbackIPv4,
          port: server.port,
          protocol: NetworkProtocol.nmea0183,
        );

      final messages = <String>[];
      final logs = collectLogs(messages);

      final subscription = valuesFromNetwork(
        settings,
        customReconnectTrigger: FakeReconnectTrigger(),
        customIdleTimeout: const Duration(milliseconds: 1),
      ).listen((_) {});

      final first = await accepted.next.timeout(const Duration(seconds: 5));
      var firstClosed = false;
      first.listen((_) {}, onDone: () => firstClosed = true);

      // The peer sends nothing and never closes, so only the watchdog can end this.
      await waitFor(() => firstClosed);
      await accepted.next.timeout(const Duration(seconds: 10));

      expect(messages, contains(startsWith('No data received on TCP stream')));
      expect(messages.where((m) => m.contains('closed by the peer')), isEmpty);

      await subscription.cancel();
      await accepted.cancel();
      await server.close();
      await logs.cancel();
    });
  });

  group('PlatformReconnectTrigger connectivity', () {
    test('reports a change in connectivity', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.mobile]);
      });
      expect(reasons, ['network changed to mobile']);
    });

    test('does not report the initial state being echoed back', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.wifi]);
      });
      expect(reasons, isEmpty);
    });

    test('reports loss of connectivity', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.none]);
      });
      expect(reasons, ['network changed to none']);
    });

    test('describes multiple simultaneous connections in a stable order', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.none]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.wifi, ConnectivityResult.ethernet]);
      });
      expect(reasons, ['network changed to ethernet+wifi']);
    });

    test('coalesces a rapid burst of changes into one report', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.none]);
        async.elapse(const Duration(milliseconds: 200));
        platform.emit([ConnectivityResult.mobile]);
        async.elapse(const Duration(milliseconds: 200));
        platform.emit([ConnectivityResult.wifi]);
      });
      expect(reasons, ['network changed to wifi']);
    });

    test('reports changes that are further apart separately', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        platform.emit([ConnectivityResult.none]);
        async.elapse(const Duration(seconds: 5));
        platform.emit([ConnectivityResult.wifi]);
      });
      expect(reasons, ['network changed to none', 'network changed to wifi']);
    });
  });

  group('PlatformReconnectTrigger lifecycle', () {
    test('reports the app returning to the foreground', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = _collectReasons(platform, (async) {
        _cycleAppToForeground();
      });
      expect(reasons, ['app resumed']);
    });

    test('coalesces a resume and a connectivity change into one report', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.none]);
      final reasons = _collectReasons(platform, (async) {
        _cycleAppToForeground();
        async.elapse(const Duration(milliseconds: 200));
        platform.emit([ConnectivityResult.wifi]);
      });
      expect(reasons, ['network changed to wifi']);
    });
  });

  group('PlatformReconnectTrigger dispose', () {
    test('stops reporting once disposed', () {
      final platform = _FakeConnectivityPlatform([ConnectivityResult.wifi]);
      final reasons = <String>[];
      fakeAsync((async) {
        ConnectivityPlatform.instance = platform;
        final trigger = PlatformReconnectTrigger();
        trigger.reasons.listen(reasons.add);
        async.elapse(const Duration(seconds: 1));
        trigger.dispose();
        async.flushMicrotasks();
        platform.emit([ConnectivityResult.mobile]);
        _cycleAppToForeground();
        async.elapse(const Duration(seconds: 5));
      });
      expect(reasons, isEmpty);
    });
  });
}
