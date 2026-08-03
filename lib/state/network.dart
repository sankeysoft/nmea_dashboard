// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/parsing/0183/common.dart';
import 'package:nmea_dashboard/state/parsing/2000/common.dart';
import 'package:nmea_dashboard/state/parsing/2000/ngt.dart';
import 'package:nmea_dashboard/state/parsing/2000/raw.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:udp/udp.dart';

/// How long to wait before retrying after a connection could not be opened at
/// all, e.g. because the settings name an unreachable host or the network is
/// unavailable.
const _networkErrorRetry = Duration(seconds: 15);

/// How long to wait before reconnecting after a TCP peer closes a connection
/// that had previously been opened successfully.
const _networkDisconnectRetry = Duration(seconds: 2);

/// How often an empty packet is inserted into the packet stream to give
/// subscribers an opportunity to cancel.
const _emptyPacketInterval = Duration(seconds: 3);

/// How long to wait after a condition that invalidates the connection before
/// acting on it, coalescing any further conditions that arrive in the meantime.
const _reconnectCoalesceDelay = Duration(milliseconds: 1500);

/// How long a connection may receive no data at all before it is assumed to be
/// dead and rebuilt. Deliberately slow: a working connection carrying no data is
/// common, e.g. when the instruments are switched off, and the conditions that
/// usually kill a socket are already handled by reconnecting on the events that
/// cause them.
const _idleTimeout = Duration(minutes: 5);

final _log = Logger('Network');

/// A function that converts a stream of network packets into a stream of bound values parsed
/// from the NMEA messages contained in those network packets.
typedef PacketProcessor = Stream<BoundValue?> Function(Stream<Uint8List> packetStream);

/// Returns an infinite stream of valid bound values read from a port specified
/// in the supplied network settings, logging any errors. Guaranteed to return
/// (potentially null) values at least every _timeout seconds even if no network
/// traffic is present to enable cancelling.
///
/// The connection is rebuilt automatically whenever the platform reports a
/// condition that may have silently invalidated it, and whenever no data at all
/// has been received for _idleTimeout. Tests may supply a
/// [customReconnectTrigger] and [customIdleTimeout] to drive those themselves.
Stream<BoundValue?> valuesFromNetwork(
  NetworkSettings settings, {
  ReconnectTrigger? customReconnectTrigger,
  Duration? customIdleTimeout,
}) {
  final packetProcessor = switch (settings.protocol) {
    (NetworkProtocol.nmea0183) => makePacketProcessingFunction(
      CrlfMessageSplitter(startRegex: RegExp(r'[\$!]')),
      Nmea0183Validator(settings.requireChecksum),
      Nmea0183Parser(),
    ),
    (NetworkProtocol.nmea2000ngt) => makePacketProcessingFunction(
      DleMessageSplitter(),
      NgtValidator(),
      Nmea2000Parser(),
    ),
    (NetworkProtocol.nmea2000raw) => makePacketProcessingFunction(
      YdRawMessageSplitter(),
      YdRawMessageValidator(),
      Nmea2000Parser(),
    ),
  };

  final idleTimeout = customIdleTimeout ?? _idleTimeout;
  Stream<BoundValue?> connect() => switch (settings.mode) {
    (NetworkMode.tcpConnect) => _valuesFromTcpConnect(
      settings.ipAddress,
      settings.port,
      packetProcessor,
      idleTimeout,
    ),
    (NetworkMode.udpListen) => _valuesFromUdpListen(settings.port, packetProcessor, idleTimeout),
  };

  return _restartOnTrigger(connect, customReconnectTrigger ?? PlatformReconnectTrigger());
}

/// Returns a stream of the values from a connection created by [connect],
/// replacing that connection with a new one whenever [trigger] reports the
/// existing one may no longer be usable. The trigger is disposed once the
/// returned stream is cancelled or its connection ends.
Stream<BoundValue?> _restartOnTrigger(
  Stream<BoundValue?> Function() connect,
  ReconnectTrigger trigger,
) {
  late final StreamController<BoundValue?> controller;
  StreamSubscription<BoundValue?>? valueSubscription;
  StreamSubscription<String>? triggerSubscription;
  var stopped = false;
  var restarting = false;

  void listenToNewConnection() {
    valueSubscription = connect().listen(
      controller.add,
      onError: controller.addError,
      onDone: () {
        stopped = true;
        triggerSubscription?.cancel();
        trigger.dispose();
        controller.close();
      },
    );
  }

  Future<void> restart(String reason) async {
    if (stopped || restarting) {
      return;
    }
    restarting = true;
    _log.info('Rebuilding network connection: $reason');
    await valueSubscription?.cancel();
    valueSubscription = null;
    restarting = false;
    if (!stopped) {
      // Keep supplying values while the replacement connection is established.
      controller.add(null);
      listenToNewConnection();
    }
  }

  controller = StreamController<BoundValue?>(
    onCancel: () async {
      stopped = true;
      await triggerSubscription?.cancel();
      await trigger.dispose();
      await valueSubscription?.cancel();
    },
  );
  triggerSubscription = trigger.reasons.listen((reason) => unawaited(restart(reason)));
  listenToNewConnection();
  return controller.stream;
}

/// Returns an infinite stream of valid bound values read from the supplied TCP
/// address and port, logging any errors, guaranteed to return (potentially
/// null) values at least every _timeout seconds even if no network traffic is
/// present to enable cancelling.
Stream<BoundValue?> _valuesFromTcpConnect(
  InternetAddress ipAddress,
  int portNum,
  PacketProcessor processPackets,
  Duration idleTimeout,
) async* {
  _log.info('Starting TCP stream on $ipAddress:$portNum');
  try {
    while (true) {
      Socket? socket;
      try {
        socket = await Socket.connect(ipAddress, portNum);
        final monitor = _MonitoredPacketStream(socket, idleTimeout);
        await for (final value in processPackets(monitor.packets)) {
          yield value;
        }
        if (monitor.endedIdle) {
          _log.warning(
            'No data received on TCP stream to $ipAddress:$portNum for '
            '${idleTimeout.inMinutes} minutes, reconnecting',
          );
        } else {
          _log.info('TCP stream on $ipAddress:$portNum was closed by the peer, reconnecting');
        }
        yield null;
        await Future.delayed(_networkDisconnectRetry);
      } on SocketException catch (e) {
        _log.warning(
          'Exception opening TCP stream on $ipAddress:$portNum. '
          'Please check your network settings. ($e)',
        );
        yield null;
        await Future.delayed(_networkErrorRetry);
      } finally {
        socket?.destroy();
      }
    }
  } finally {
    _log.info('Closing TCP stream to $ipAddress:$portNum');
  }
}

/// Returns an infinite stream of valid bound values read from the supplied
/// network port, logging any errors, guaranteed to return (potentially null)
/// values at least every _timeout seconds even if no network traffic is present
/// to enable cancelling.
Stream<BoundValue?> _valuesFromUdpListen(
  int portNum,
  PacketProcessor processPackets,
  Duration idleTimeout,
) async* {
  _log.info('Starting UDP listen stream on $portNum');
  try {
    while (true) {
      UDP? receiver;
      try {
        receiver = await UDP.bind(Endpoint.any(port: Port(portNum)));
        final monitor = _MonitoredPacketStream(
          receiver.asStream().map((d) => d?.data ?? _emptyPacket),
          idleTimeout,
        );
        await for (final value in processPackets(monitor.packets)) {
          yield value;
        }
        if (monitor.endedIdle) {
          _log.warning(
            'No data received on UDP port $portNum for '
            '${idleTimeout.inMinutes} minutes, rebinding',
          );
        }
        yield null;
        await Future.delayed(_networkDisconnectRetry);
      } on SocketException catch (e) {
        _log.warning(
          'Exception opening UDP listen on $portNum. '
          'Please check your network settings. ($e)',
        );
        yield null;
        await Future.delayed(_networkErrorRetry);
      } finally {
        receiver?.close();
      }
    }
  } finally {
    _log.info('Closing UDP listen to $portNum');
  }
}

final Uint8List _emptyPacket = Uint8List(0);

/// Presents a source of network packets as a stream that always supplies a packet within
/// _emptyPacketInterval, inserting empty packets while the source is quiet so that subscribers
/// always have an opportunity to cancel. The stream completes when the source completes, or when
/// no data at all has been received from the source for the supplied idle timeout.
class _MonitoredPacketStream {
  /// How many consecutive quiet intervals are tolerated before declaring the source idle.
  final int _maxQuietIntervals;
  late final StreamController<Uint8List> _controller;
  late final StreamSubscription<Uint8List> _subscription;
  late final Timer _timer;
  var _dataSinceLastInterval = false;
  var _quietIntervals = 0;
  var _endedIdle = false;

  _MonitoredPacketStream(Stream<Uint8List> source, Duration idleTimeout)
    : _maxQuietIntervals = (idleTimeout.inMilliseconds / _emptyPacketInterval.inMilliseconds)
          .ceil()
          .clamp(1, double.maxFinite.toInt()) {
    _controller = StreamController<Uint8List>(
      onCancel: () {
        _timer.cancel();
        return _subscription.cancel();
      },
    );
    _timer = Timer.periodic(_emptyPacketInterval, (_) => _onInterval());
    _subscription = source.listen(
      _onPacket,
      onError: _controller.addError,
      onDone: () {
        _timer.cancel();
        _controller.close();
      },
    );
  }

  /// The packets read from the source, padded with empty packets.
  Stream<Uint8List> get packets => _controller.stream;

  /// Whether the stream completed because the source was idle rather than because it ended.
  bool get endedIdle => _endedIdle;

  void _onPacket(Uint8List packet) {
    // Only data counts towards liveness. Some sources supply empty packets of their own when they
    // have nothing to report, and those say nothing about whether the connection still works.
    if (packet.isNotEmpty) {
      _dataSinceLastInterval = true;
    }
    _controller.add(packet);
  }

  void _onInterval() {
    if (_dataSinceLastInterval) {
      _dataSinceLastInterval = false;
      _quietIntervals = 0;
    } else {
      _quietIntervals += 1;
    }
    if (_quietIntervals >= _maxQuietIntervals) {
      _endedIdle = true;
      _timer.cancel();
      _subscription.cancel();
      _controller.close();
    } else {
      _controller.add(_emptyPacket);
    }
  }
}

/// Returns a function that converts a packet stream into a stream of the valid
/// values read using the supplied splitter, validator, and parser, logging any
/// errors and returning null for every empty packet in the supplied stream.
PacketProcessor makePacketProcessingFunction<M, S>(
  MessageSplitter<M> splitter,
  MessageValidator<M, S> validator,
  MessageParser<M, S> parser,
) {
  return (Stream<Uint8List> packetStream) async* {
    await for (final packet in packetStream) {
      parser.logAndClearIfNeeded();
      if (packet.isEmpty) {
        // Empty packets are included in the stream even if no traffic is
        // present so we can return empty values that let a subscriber cancel
        // the stream.
        yield null;
      } else {
        for (final message in splitter.read(packet)) {
          ValidatedMessage<M, S>? validated;
          try {
            validated = validator.validate(message);
          } on FormatException catch (e) {
            final fakeValidated = ValidatedMessage(0, 0, message);
            _log.warning('Error validating ${fakeValidated.payloadToString()}: ${e.message}');
          }
          if (validated == null) {
            continue;
          }
          try {
            for (final value in parser.parseWithCounting(validated)) {
              yield value;
            }
          } on FormatException catch (e) {
            _log.warning(
              'Error parsing ${validated.type}/${validated.sender} '
              '${validated.payloadToString()}: ${e.message}',
            );
          }
        }
      }
    }
  };
}

/// A source of events indicating that any existing network connection may no
/// longer be usable and should be rebuilt.
abstract class ReconnectTrigger {
  /// A broadcast stream of short descriptions of why a reconnect is advised.
  Stream<String> get reasons;

  /// Releases all resources held by this trigger.
  Future<void> dispose();
}

/// A [ReconnectTrigger] driven by the platform conditions that commonly
/// invalidate a socket without ever reporting an error: the app returning to
/// the foreground and the device changing network.
class PlatformReconnectTrigger implements ReconnectTrigger {
  final _controller = StreamController<String>.broadcast();
  late final AppLifecycleListener _lifecycleListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _coalesceTimer;
  String? _pendingReason;
  String? _lastConnectivity;

  PlatformReconnectTrigger() {
    final source = Connectivity();
    _lifecycleListener = AppLifecycleListener(onResume: () => _report('app resumed'));
    unawaited(_seedConnectivity(source));
    _connectivitySubscription = source.onConnectivityChanged.listen(
      _handleConnectivity,
      onError: (Object e) => _log.warning('Error monitoring connectivity: $e'),
    );
  }

  @override
  Stream<String> get reasons => _controller.stream;

  /// Records the connectivity present at construction so that a platform which
  /// echoes the current state on subscription does not look like a change.
  Future<void> _seedConnectivity(Connectivity source) async {
    try {
      _lastConnectivity ??= _describeConnectivity(await source.checkConnectivity());
    } on Exception catch (e) {
      _log.warning('Error checking connectivity: $e');
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final description = _describeConnectivity(results);
    final previous = _lastConnectivity;
    _lastConnectivity = description;
    if (previous != null && previous != description) {
      _report('network changed to $description');
    }
  }

  /// Reports [reason] once no further events have arrived for
  /// _reconnectCoalesceDelay.
  void _report(String reason) {
    _pendingReason = reason;
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_reconnectCoalesceDelay, () {
      final reason = _pendingReason;
      _pendingReason = null;
      _coalesceTimer = null;
      if (reason != null && !_controller.isClosed) {
        _controller.add(reason);
      }
    });
  }

  @override
  Future<void> dispose() async {
    _coalesceTimer?.cancel();
    _lifecycleListener.dispose();
    await _connectivitySubscription?.cancel();
    await _controller.close();
  }
}

/// Returns a stable human readable description of a set of connectivity types.
String _describeConnectivity(List<ConnectivityResult> results) {
  final names = results.map((result) => result.name).toList()..sort();
  return names.isEmpty ? 'nothing' : names.join('+');
}
