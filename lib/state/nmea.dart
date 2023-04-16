// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'common.dart';

/// The list of message types that are silently ignored.
const _ignoredMessages = {
  // Ignore everything waypoint related
  'AAM', 'BOD', 'BWC', 'BRW', 'BWW', 'R00', 'RTE',
  'WCV', 'WNC', 'WPL', 'XTE', 'XTR', 'WDC', 'WDR',
  'WFM', 'WNR',
  // Ignore everything autopilot related.
  'APA', 'APB',
  // Ignore detailed satellite information and GPS datum.
  'GSV', 'DTM', 'GRS',
  // Ignore obsolete messages where data is received in other forms.
  'MDA', 'DBK', 'DBS', 'DBT', 'HDM', 'HDT', 'VWT', 'VWR',
};

/// The number of times to throw an exception containing the input for each new
/// unknown type for each logging interval.
const int _logUnsupportedCount = 1;

/// The time between count events.
const Duration _logInterval = Duration(minutes: 5);

/// Tracks the count for some set of message types.
@visibleForTesting
class MessageCounts {
  int _total = 0;
  final _map = SplayTreeMap<String, int>();

  /// Increments the count of the supplied type, returning the new count.
  int increment(String type) {
    _total += 1;
    final count = (_map[type] ?? 0) + 1;
    _map[type] = count;
    return count;
  }

  /// Resets all message counts to zero.
  void clear() {
    _total = 0;
    _map.clear();
  }

  /// Returns true iff no messages have been received.
  bool get isEmpty {
    return _total == 0;
  }

  /// Returns the total count across all types.
  int get total {
    return _total;
  }

  /// Returns a string description of the counts for each type.
  String get summary {
    return _map.entries.map((e) => '${e.key}:${e.value}').join(', ');
  }
}

/// Parses strings into nmea messages, keeping track of the count for each
/// message type.
class NmeaParser {
  static final _log = Logger('NmeaParser');
  @visibleForTesting
  final ignoredCounts = MessageCounts();
  @visibleForTesting
  final unsupportedCounts = MessageCounts();
  @visibleForTesting
  final successCounts = MessageCounts();
  final bool _requireChecksum;
  DateTime _lastLog;

  /// Constructs a new parser for NMEA messages
  NmeaParser(this._requireChecksum) : _lastLog = DateTime.now();

  /// Logs the current message counts then resets them if sufficient time has
  /// passed since the last log.
  void logAndClearIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastLog) > _logInterval) {
      logAndClearCounts();
      _lastLog = now;
    }
  }

  /// Logs the current message counts then resets them.
  void logAndClearCounts() {
    final lastLogString = DateFormat('Hms').format(_lastLog);
    if (successCounts.isEmpty) {
      _log.info('No messages received since $lastLogString');
    } else {
      _log.info(
          'Parsed ${successCounts.total} messages: ${successCounts.summary}');
      successCounts.clear();
    }
    if (!unsupportedCounts.isEmpty) {
      _log.info(
          'Received ${unsupportedCounts.total} unsupported messages: ${unsupportedCounts.summary}');
      unsupportedCounts.clear();
    }
    if (!ignoredCounts.isEmpty) {
      _log.info(
          'Received ${ignoredCounts.total} ignored messages: ${ignoredCounts.summary}');
      ignoredCounts.clear();
    }
  }

  /// Attempts to parse the supplied string as a NMEA0183 message, returning
  /// one or more values if parsing the message contents was successful and
  /// the message type is supported. Throws an exception if parsing errors
  /// were encountered and the first few times a new unsupported message is
  /// received. Returns an empty list for ignored message types.
  /// If requireChecksum is true messages without a checksum are rejected.
  List<Value> parseString(String string) {
    if (string.startsWith('!')) {
      // Silently discard the encapsulated (e.g. AIS) sentences which are often
      // on the network.
      return [];
    } else if (!string.startsWith('\$')) {
      // Thow an exception for anything else, its potentially a network
      // parsing problem.
      throw const FormatException('Message is not marked with \$');
    }

    // Try to validate a checksum if there is one, throw an error if there
    // isn't but we require checksums.
    if (string.length > 3 && string[string.length - 3] == '*') {
      _validateChecksum(string.substring(1, string.length - 3),
          string.substring(string.length - 2));
      string = string.substring(0, string.length - 3);
    } else if (_requireChecksum) {
      throw const FormatException('Message did not end in a checksum');
    }

    // Pull out the salient peices of whats left.
    if (string.length < 7) {
      throw const FormatException('Message is truncated');
    }
    final type = string.substring(3, 6);
    final fields = string.substring(7).split(',');

    // Skip ignored messages, pass everything else to the helper.
    if (_ignoredMessages.contains(type)) {
      ignoredCounts.increment(type);
      return [];
    }

    final values = _createNmeaValues(type, fields);
    if (values == null) {
      final count = unsupportedCounts.increment(type);
      // Only cause logging of unsupported types a few times each.
      if (count <= _logUnsupportedCount) {
        throw const FormatException('Unsupported message type');
      }
      return [];
    }
    successCounts.increment(type);
    return values;
  }
}

/// Validates that the supplied payload matches the expected ASCII checksum, throwing
/// a FormatException if not.
void _validateChecksum(payload, checksumString) {
  final int checksum = int.parse(checksumString, radix: 16);
  int xor = 0;
  for (final codeUnit in payload.codeUnits) {
    xor ^= codeUnit;
  }
  if (xor != checksum) {
    throw FormatException('Invalid checksum: expected $checksum, got $xor');
  }
}

/// Attempts to create zero or more value containing NMEA0183 message contents
/// from the supplied type string and field list, throwing a FormatException
/// if unsuccessful or null if the type is not recognized.
List<Value>? _createNmeaValues(type, fields) {
  switch (type) {
    case 'DPT':
      _validateMinFieldCount(fields, 2);
      final depth = double.parse(fields[0]);
      final offset = fields[1] == '' ? 0.0 : double.parse(fields[1]);
      return [
        SingleValue(depth + offset, Source.network, Property.depthWithOffset),
        SingleValue(depth, Source.network, Property.depthUncalibrated),
      ];
    case 'HDG':
      _validateFieldCount(fields, 5);
      // Only accept heading messages with deviation and store in true until
      // we support user supplied deviation, then we'll need a different
      // solution.
      final magHdg = double.parse(fields[0]);
      final variation = _parseVariation(fields[3], fields[4]);
      final trueHdg = (magHdg - variation) % 360.0;
      return [
        SingleValue(variation, Source.network, Property.variation),
        SingleValue(trueHdg, Source.network, Property.heading),
      ];
    case 'GGA':
      _validateFieldCount(fields, 14);
      final lat = _parseLatitude(fields[1], fields[2]);
      final long = _parseLongitude(fields[3], fields[4]);
      var ret = <Value>[
        DoubleValue(lat, long, Source.network, Property.gpsPosition)
      ];
      if (!fields[7].isEmpty) {
        ret.add(SingleValue(
            double.parse(fields[7]), Source.network, Property.gpsHdop));
      }
      return ret;
    case 'GLL':
      _validateMinFieldCount(fields, 6);
      _validateValidityIndicator(fields, index: 5);
      final lat = _parseLatitude(fields[0], fields[1]);
      final long = _parseLongitude(fields[2], fields[3]);
      return [DoubleValue(lat, long, Source.network, Property.gpsPosition)];
    case 'MWV':
      _validateFieldCount(fields, 5);
      _validateValidityIndicator(fields, index: 4);
      final relative = (fields[1] == 'R');
      final angle = double.parse(fields[0]);
      final speed = double.parse(fields[2]) /
          (fields[3] == 'K' ? metersPerSecondToKnots : 1.0);
      return [
        SingleValue(angle, Source.network,
            relative ? Property.apparentWindAngle : Property.trueWindDirection),
        SingleValue(speed, Source.network,
            relative ? Property.apparentWindSpeed : Property.trueWindSpeed),
      ];
    case 'MTW':
      _validateFieldCount(fields, 2);
      _validateFieldValue(fields, index: 1, expected: 'C');
      return [
        SingleValue(
            double.parse(fields[0]), Source.network, Property.waterTemperature)
      ];
    case 'ROT':
      _validateFieldCount(fields, 2);
      _validateValidityIndicator(fields, index: 1);
      return [
        SingleValue(
            double.parse(fields[0]) / 60, Source.network, Property.rateOfTurn)
      ];
    case 'RSA':
      _validateFieldCount(fields, 4);
      _validateValidityIndicator(fields, index: 1);
      return [
        SingleValue(
            double.parse(fields[0]), Source.network, Property.rudderAngle)
      ];
    case 'VDR':
      _validateFieldCount(fields, 6);
      _validateFieldValue(fields, index: 1, expected: 'T');
      _validateFieldValue(fields, index: 5, expected: 'N');
      final set = double.parse(fields[0]);
      final drift = double.parse(fields[4]) / metersPerSecondToKnots;
      return [
        SingleValue(set, Source.network, Property.currentSet),
        SingleValue(drift, Source.network, Property.currentDrift)
      ];
    case 'VHW':
      _validateMinFieldCount(fields, 8);
      _validateFieldValue(fields, index: 7, expected: 'K');
      final speed = double.parse(fields[6]) / 3.6; // Convert from kmph (sigh)
      return [SingleValue(speed, Source.network, Property.speedThroughWater)];
    case 'VLW':
      _validateMinFieldCount(fields, 4);
      _validateFieldValue(fields, index: 1, expected: 'N');
      _validateFieldValue(fields, index: 3, expected: 'N');
      final total = double.parse(fields[0]) / metersToNauticalMiles;
      final trip = double.parse(fields[2]) / metersToNauticalMiles;
      return [
        SingleValue(total, Source.network, Property.distanceTotal),
        SingleValue(trip, Source.network, Property.distanceTrip)
      ];
    case 'VTG':
      _validateMinFieldCount(fields, 8);
      _validateFieldValue(fields, index: 1, expected: 'T');
      _validateFieldValue(fields, index: 7, expected: 'K');
      final course = double.parse(fields[0]);
      final speed = double.parse(fields[6]) / 3.6; // Convert from kmph (sigh)
      return [
        SingleValue(course, Source.network, Property.courseOverGround),
        SingleValue(speed, Source.network, Property.speedOverGround)
      ];
    case 'XDR':
      _validateMinFieldCount(fields, 4);
      final List<Value> values = [];
      for (int i = 0; i < fields.length - 3; i += 4) {
        values.addAll(_parseXdrMeasurement(fields, i));
      }
      if (values.isEmpty) {
        throw const FormatException(
            'No recognised measurements found in XDR message');
      }
      return values;
    case 'ZDA':
      _validateFieldCount(fields, 6);
      if (fields[0].length < 6) {
        throw FormatException('Time field too short: ${fields[0]}');
      }
      final hour = int.parse(fields[0].substring(0, 2));
      final minute = int.parse(fields[0].substring(2, 4));
      final second = int.parse(fields[0].substring(4, 6));
      final day = int.parse(fields[1]);
      final month = int.parse(fields[2]);
      final year = int.parse(fields[3]);
      final dt = DateTime.utc(year, month, day, hour, minute, second);
      return [SingleValue(dt, Source.network, Property.utcTime)];
    default:
      return null;
  }
}

/// Validates fields contains the expected number of entries.
void _validateFieldCount(fields, expectedCount) {
  if (fields.length != expectedCount) {
    throw FormatException(
        'Expected $expectedCount fields, found ${fields.length}');
  }
}

/// Validates fields contains at least the expected number of entries.
void _validateMinFieldCount(fields, minimumCount) {
  if (fields.length < minimumCount) {
    throw FormatException(
        'Expected at least $minimumCount fields, found ${fields.length}');
  }
}

/// Validates a field contains the supplied value.
void _validateFieldValue(fields, {required index, required expected, message}) {
  if (fields[index] != expected) {
    throw FormatException(
        message ?? 'Expected $expected in field $index, got ${fields[index]}');
  }
}

/// Validates a validity indicator fields is set to 'A'.
void _validateValidityIndicator(fields, {required index}) {
  _validateFieldValue(fields,
      index: index, expected: 'A', message: 'Data marked invalid');
}

/// Parses a decimal encoded latitude and direction indicator.
double _parseLatitude(valueString, direction) {
  if (valueString.length < 7) {
    throw const FormatException('Latitude value wrong length');
  }
  final value = double.parse(valueString.substring(0, 2)) +
      (double.parse(valueString.substring(2)) / 60.0);
  switch (direction) {
    case 'N':
      return value;
    case 'S':
      return -value;
    default:
      throw FormatException('Invalid longitude direction $direction');
  }
}

/// Parses a decimal encoded latitude and direction indicator.
double _parseLongitude(valueString, direction) {
  if (valueString.length < 8) {
    throw const FormatException('Longitude value wrong length');
  }
  final value = double.parse(valueString.substring(0, 3)) +
      (double.parse(valueString.substring(3)) / 60.0);
  switch (direction) {
    case 'E':
      return value;
    case 'W':
      return -value;
    default:
      throw FormatException('Invalid longitude direction $direction');
  }
}

/// Parses a variation magniture and sign, returning a positive value for West.
double _parseVariation(valueString, direction) {
  final value = double.parse(valueString);
  switch (direction) {
    case 'E':
      return -value;
    case 'W':
      return value;
    default:
      throw FormatException('Invalid varation direction $direction');
  }
}

/// Parses a variation magniture and sign, returning a positive value for West.
List<Value> _parseXdrMeasurement(List<String> fields, int startIndex) {
  switch (fields[startIndex + 3].toLowerCase()) {
    case 'pitch':
      _validateFieldValue(fields, index: startIndex + 2, expected: 'D');
      final value = double.parse(fields[startIndex + 1]);
      return [SingleValue(value, Source.network, Property.pitch)];
    case 'roll':
      _validateFieldValue(fields, index: startIndex + 2, expected: 'D');
      final value = double.parse(fields[startIndex + 1]);
      return [SingleValue(value, Source.network, Property.roll)];
    case 'baro':
      _validateFieldValue(fields, index: startIndex + 2, expected: 'P');
      final value = double.parse(fields[startIndex + 1]);
      return [SingleValue(value, Source.network, Property.pressure)];
    default:
      return [];
  }
}
