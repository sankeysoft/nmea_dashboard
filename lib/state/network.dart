// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/parsing/0183/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/splitters.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:udp/udp.dart';

const _networkErrorRetry = Duration(seconds: 15);

final _log = Logger('Network');

/// Returns an infinite stream of valid bound values read from a port specified
/// in the supplied network settings, logging any errors. Guaranteed to return
/// (potentially null) values at least every _timeout seconds even if no network
/// traffic is present to enable cancelling.
Stream<BoundValue?> valuesFromNetwork(NetworkSettings settings) {
  final splitter = CrlfMessageSplitter(startRegex: RegExp(r'[\$!]'));
  final validator = Nmea0183Validator(settings.requireChecksum);
  final parser = Nmea0183Parser();
  switch (settings.mode) {
    case NetworkMode.tcpConnect:
      return _valuesFromTcpConnect(settings.ipAddress, settings.port, splitter, validator, parser);
    case NetworkMode.udpListen:
      return _valuesFromUdpListen(settings.port, splitter, validator, parser);
  }
}

/// Returns an infinite stream of valid bound values read from the supplied TCP
/// address and port, logging any errors, guaranteed to return (potentially
/// null) values at least every _timeout seconds even if no network traffic is
/// present to enable cancelling.
Stream<BoundValue?> _valuesFromTcpConnect(
  InternetAddress ipAddress,
  int portNum,
  MessageSplitter splitter,
  MessageValidator validator,
  MessageParser parser,
) async* {
  _log.info('Starting TCP stream on $ipAddress:$portNum');
  try {
    while (true) {
      try {
        var socket = await Socket.connect(ipAddress, portNum);
        await for (final value in valuesFromPackets(socket, splitter, validator, parser)) {
          yield value;
        }
        socket.close();
      } on SocketException catch (e) {
        _log.warning(
          'Exception opening TCP stream on $ipAddress:$portNum. '
          'Please check your network settings. ($e)',
        );
        yield null;
        await Future.delayed(_networkErrorRetry);
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
  MessageSplitter splitter,
  MessageValidator validator,
  MessageParser parser,
) async* {
  _log.info('Starting UDP listen stream on $portNum');
  try {
    while (true) {
      try {
        var receiver = await UDP.bind(Endpoint.any(port: Port(portNum)));
        await for (final value in valuesFromPackets(
          receiver.asStream().map((d) => d?.data ?? _emptyPacket),
          splitter,
          validator,
          parser,
        )) {
          yield value;
        }
      } on SocketException catch (e) {
        _log.warning(
          'Exception opening UDP listen on $portNum. '
          'Please check your network settings. ($e)',
        );
        yield null;
        await Future.delayed(_networkErrorRetry);
      }
    }
  } finally {
    _log.info('Closing UDP listen to $portNum');
  }
}

final Uint8List _emptyPacket = Uint8List(0);

/// Returns an empty Uint8List periodically.
Stream<Uint8List> _periodicEmptyPackets() {
  return Stream.periodic(const Duration(seconds: 3), (_) => _emptyPacket);
}

/// Returns a stream of valid values read from the supplied packet stream,
/// logging any errors, guaranteed to return (potentially null) values at
/// least every _timeout seconds even if no network traffic is present to
/// enable cancelling.
@visibleForTesting
Stream<BoundValue?> valuesFromPackets<M, S>(
  Stream<Uint8List> packetStream,
  MessageSplitter<M> splitter,
  MessageValidator<M, S> validator,
  MessageParser<M, S> parser,
) async* {
  await for (final packet in StreamGroup.merge([packetStream, _periodicEmptyPackets()])) {
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
          _log.warning('Error validating ${splitter.loggable(message)}: ${e.message}');
        }
        if (validated == null) {
          continue;
        }
        try {
          for (final value in parser.parse(validated)) {
            yield value;
          }
        } on FormatException catch (e) {
          _log.warning('Error parsing ${splitter.loggable(message)}: ${e.message}');
        }
      }
    }
  }
}
