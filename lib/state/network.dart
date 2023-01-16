// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:udp/udp.dart';

import 'nmea.dart';
import 'common.dart';

const _networkErrorRetry = Duration(seconds: 15);

final _log = Logger('Network');

/// Returns an infinite stream of valid values read from a port specified in the supplied
/// network settings, logging any errors. Guaranteed to return (potentially null) values
/// at least every _timeout seconds even if no network traffic is present to enable
/// cancelling.
Stream<Value?> valuesFromNetwork(NetworkSettings settings) {
  NmeaParser parser = NmeaParser(settings.requireChecksum);
  switch (settings.mode) {
    case NetworkMode.tcpConnect:
      return _valuesFromTcpConnect(settings.ipAddress, settings.port, parser);
    case NetworkMode.udpListen:
      return _valuesFromUdpListen(settings.port, parser);
  }
}

/// Returns an infinite stream of valid values read from the supplied TCP address and port, logging any errors,
/// guaranteed to return (potentially null) values at least every _timeout seconds even if no network
/// traffic is present to enable cancelling.
Stream<Value?> _valuesFromTcpConnect(
    InternetAddress ipAddress, int portNum, NmeaParser parser) async* {
  _log.info('Starting TCP stream on $ipAddress:$portNum');
  try {
    while (true) {
      try {
        var socket = await Socket.connect(ipAddress, portNum);
        await for (final value in _valuesFromPackets(socket, parser)) {
          yield value;
        }
        socket.close();
      } on SocketException catch (e) {
        _log.warning('Exception opening TCP stream on $ipAddress:$portNum: $e');
        yield null;
        await Future.delayed(_networkErrorRetry);
      }
    }
  } finally {
    _log.info('Closing TCP stream to $ipAddress:$portNum');
  }
}

/// Returns an infinite stream of valid values read from the supplied network port, logging any errors,
/// guaranteed to return (potentially null) values at least every _timeout seconds even if no network
/// traffic is present to enable cancelling.
Stream<Value?> _valuesFromUdpListen(int portNum, NmeaParser parser) async* {
  _log.info('Starting UDP listen stream on $portNum');
  try {
    while (true) {
      try {
        var receiver = await UDP.bind(Endpoint.any(port: Port(portNum)));
        await for (final value in _valuesFromPackets(
            receiver.asStream().map((d) => d?.data ?? _emptyPacket), parser)) {
          yield value;
        }
      } on SocketException catch (e) {
        _log.warning('Exception opening UDP listed on $portNum: $e');
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

/// Returns an stream of valid values read from the supplied packet stream,
/// logging any errors, guaranteed to return (potentially null) values at
/// least every _timeout seconds even if no network traffic is present to
/// enable cancelling.
Stream<Value?> _valuesFromPackets(
    Stream<Uint8List> packetStream, NmeaParser parser) async* {
  var remaining = '';
  await for (final packet
      in StreamGroup.merge([packetStream, _periodicEmptyPackets()])) {
    parser.logAndClearIfNeeded();
    if (packet.isEmpty) {
      // Empty packets are included in the stream even if no traffic is
      // present so we can return empty values that let a subscriber cancel
      // the stream.
      yield null;
    } else {
      // Process whatever we left over plus the new packet.
      remaining += String.fromCharCodes(packet);

      // Keep going while the string contains terminators or a .
      var nextSplit = _findSplit(remaining);
      while (nextSplit >= 0) {
        final potentialMessage = remaining.substring(0, nextSplit).trim();
        remaining = remaining.substring(nextSplit).trim();
        nextSplit = _findSplit(remaining);

        if (potentialMessage.isNotEmpty) {
          try {
            for (final value in parser.parseString(potentialMessage)) {
              yield value;
            }
          } on FormatException catch (e) {
            _log.warning('Error parsing $potentialMessage ${e.message}');
          }
        }
      }
    }
  }
}

/// Returns the best location to split remaing data based on the first CR LF,
/// or message start indicator, or -1 if there is none. This is needed because
/// annoyingly some networks don't CRLF terminate all messages correctly.
int _findSplit(remainingData) {
  if (remainingData.length < 2) {
    return -1;
  }
  final nextEnd = remainingData.indexOf(RegExp(r'[\n\r]'));
  final nextStart = remainingData.indexOf(RegExp(r'[\$!]'), 1);
  if (nextEnd >= 0 && (nextStart <= 0 || nextEnd < nextStart)) {
    return nextEnd;
  } else if (nextStart > 0) {
    return nextStart;
  }
  return -1;
}
