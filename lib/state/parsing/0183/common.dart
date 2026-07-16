// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/values.dart';

part 'bwr.dart';
part 'dbt.dart';
part 'dpt.dart';
part 'gga.dart';
part 'gll.dart';
part 'hdg.dart';
part 'hdm.dart';
part 'mda.dart';
part 'mtw.dart';
part 'mwd.dart';
part 'mwv.dart';
part 'rmb.dart';
part 'rmc.dart';
part 'rot.dart';
part 'rsa.dart';
part 'vdr.dart';
part 'vhw.dart';
part 'vlw.dart';
part 'vtg.dart';
part 'vwr.dart';
part 'vwt.dart';
part 'xdr.dart';
part 'xte.dart';
part 'zda.dart';

/// The list of message types that are silently ignored.
const _ignoredMessages = {
  // Ignore most things related to waypoints and routes except active waypoint.
  'AAM', 'BOD', 'BWC', 'BRW', 'BWW', 'R00', 'RTE', 'WCV', 'WNC',
  'WPL', 'XTR', 'WDC', 'WDR', 'WFM', 'WNR',
  // Ignore autopilot control messages.
  'APA', 'APB',
  // Ignore detailed satellite information and GPS datum.
  'ALM', 'GBS', 'GSA', 'GSV', 'DTM', 'GRS',
  // Ignore other messages that haven't been explicitly requested.
  'DBK', 'DBS', 'HDT',
};

/// Parses strings into nmea messages, keeping track of the count for each
/// message type.
class Nmea0183Parser extends NmeaParser {
  static final List<SentenceParser> _allParsers = [
    BwrParser(),
    DbtParser(),
    DptParser(),
    GgaParser(),
    GllParser(),
    HdgParser(),
    HdmParser(),
    MdaParser(),
    MtwParser(),
    MwdParser(),
    MwvParser(),
    RmbParser(),
    RmcParser(),
    RotParser(),
    RsaParser(),
    VdrParser(),
    VhwParser(),
    VlwParser(),
    VtgParser(),
    VwrParser(),
    VwtParser(),
    XdrParser(),
    XteParser(),
    ZdaParser(),
  ];

  static final Map<String, SentenceParser> _parserMap = {
    for (final parser in _allParsers) parser.type: parser,
  };

  /// The sentence types this parser supports.
  @visibleForTesting
  static Iterable<String> get supportedTypes => _parserMap.keys;

  final bool _requireChecksum;

  /// Constructs a new parser for NMEA messages
  Nmea0183Parser(this._requireChecksum);

  /// Attempts to parse the supplied string as a NMEA0183 message, returning
  /// one or more bound values if parsing the message contents was successful or
  /// zero values if parsing was unsuccessful but the failure mode should not be
  /// logged (e.g. a benign problem that has already been logged). Throws a
  /// FormatException if parsing errors were encountered and the first time a new
  /// unsupported message or a message with no data is received.
  /// If requireChecksum is true messages without a checksum are rejected.
  List<BoundValue> parseString(String string) {
    if (string.startsWith('!')) {
      // Silently discard the encapsulated (e.g. AIS) sentences which are often
      // on the network.
      return [];
    } else if (!string.startsWith('\$')) {
      // Thow an exception for any other prefix, its potentially a network
      // parsing problem.
      throw const FormatException('Message is not marked with \$');
    }

    // Try to validate a checksum if there is one, throw an error if there
    // isn't a checksum but we require one.
    if (string.length > 3 && string[string.length - 3] == '*') {
      _validateChecksum(
        string.substring(1, string.length - 3),
        string.substring(string.length - 2),
      );
      string = string.substring(0, string.length - 3);
    } else if (_requireChecksum) {
      throw const FormatException('Message did not end in a checksum');
    }

    // Pull out the salient pieces of what is left.
    if (string.length < 7) {
      throw const FormatException('Message is truncated');
    }
    final type = string.substring(3, 6);
    final fields = string.substring(7).split(',');

    // Skip ignored sentence types.
    if (_ignoredMessages.contains(type)) {
      ignoredCounts.increment(type);
      return [];
    }

    final parser = _parserMap[type];
    if (parser == null) {
      // Only cause logging of each unsupported type once per interval.
      if (unsupportedCounts.increment(type) <= 1) {
        throw const FormatException('Unsupported message type');
      }
      return [];
    }

    final values = parser.parse(fields);
    if (values.isEmpty) {
      // Only cause logging of each empty type once per interval.
      if (emptyCounts.increment(type) <= 1) {
        throw const FormatException('No data found');
      }
      return [];
    }

    successCounts.increment(type);
    return values;
  }
}

sealed class SentenceParser {
  /// The three letter sentence type this parser handles.
  String get type;

  /// Attempts to create zero or more value containing NMEA0183 message contents
  /// from the supplied type string and field list, throwing a FormatException
  /// if unsuccessful or an UnsupportedMessageException if the message type is
  /// not recognized.
  List<BoundValue> parse(List<String> fields);
}

/// Validates that the supplied payload matches the expected ASCII checksum, throwing
/// a FormatException if not.
void _validateChecksum(String payload, String checksumString) {
  final int checksum = int.parse(checksumString, radix: 16);
  int xor = 0;
  for (final codeUnit in payload.codeUnits) {
    xor ^= codeUnit;
  }
  if (xor != checksum) {
    throw FormatException(
      'Invalid checksum: expected 0x${checksum.toRadixString(16)}, '
      'got 0x${xor.toRadixString(16)}',
    );
  }
}

// Parse a BoundValue<SingleValue<double>> from the supplied input, returning
// null if the input was empty and throwing a FormatException if it was not a
// valid number. Optionally divides the parsed input by the supplied divisor.
BoundValue<SingleValue<double>>? _parseSingleValue(
  String input,
  Property property, {
  double? divisor,
  int tier = 1,
}) {
  if (input.isEmpty) {
    return null;
  }
  double number = double.parse(input);
  if (divisor != null) {
    number = number / divisor;
  }
  return _boundSingleValue(number, property, tier: tier);
}

// Creates a BoundValue<SingleValue<double>> from the supplied input.
BoundValue<SingleValue<T>> _boundSingleValue<T>(T number, Property property, {int tier = 1}) {
  return BoundValue(Source.network, property, SingleValue(number), tier: tier);
}

// Creates a BoundValue<DoubleValue<double>> from the supplied input.
BoundValue<DoubleValue<double>> _boundDoubleValue(
  double first,
  double second,
  Property property, {
  int tier = 1,
}) {
  return BoundValue(Source.network, property, DoubleValue(first, second), tier: tier);
}

/// Validates fields contains the expected number of entries.
void _validateFieldCount(List<String> fields, int expectedCount) {
  if (fields.length != expectedCount) {
    throw FormatException('Expected $expectedCount fields, found ${fields.length}');
  }
}

/// Validates fields contains one of expected number of entries.
void _validateFieldCounts(List<String> fields, List<int> allowedCounts) {
  for (var count in allowedCounts) {
    if (fields.length == count) {
      return;
    }
  }
  throw FormatException('Expected field count in $allowedCounts fields, found ${fields.length}');
}

/// Validates fields contains at least the expected number of entries.
void _validateMinFieldCount(List<String> fields, int minimumCount) {
  if (fields.length < minimumCount) {
    throw FormatException('Expected at least $minimumCount fields, found ${fields.length}');
  }
}

/// Validates a field contains the supplied value.
void _validateFieldValue(
  List<String> fields, {
  required int index,
  required String expected,
  String? message,
}) {
  if (fields[index] != expected) {
    throw FormatException(message ?? 'Expected $expected in field $index, got ${fields[index]}');
  }
}

/// Validates a validity indicator fields is set to 'A'.
void _validateValidityIndicator(List<String> fields, {required index}) {
  _validateFieldValue(fields, index: index, expected: 'A', message: 'Data marked invalid');
}

/// Parses a decimal encoded latitude and direction indicator.
double _parseLatitude(String valueString, String direction) {
  if (valueString.length < 7) {
    throw const FormatException('Latitude value wrong length');
  }
  final value =
      double.parse(valueString.substring(0, 2)) + (double.parse(valueString.substring(2)) / 60.0);
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
double _parseLongitude(String valueString, String direction) {
  if (valueString.length < 8) {
    throw const FormatException('Longitude value wrong length');
  }
  final value =
      double.parse(valueString.substring(0, 3)) + (double.parse(valueString.substring(3)) / 60.0);
  switch (direction) {
    case 'E':
      return value;
    case 'W':
      return -value;
    default:
      throw FormatException('Invalid longitude direction $direction');
  }
}

/// Parses a decimal encoded latitude and direction indicator.
double _parseCrossTrackError(String valueString, String direction) {
  if (valueString.isEmpty) {
    throw const FormatException('Offset not populated');
  }
  final meters = double.parse(valueString) / metersToNauticalMiles;
  switch (direction) {
    case 'L':
      return -meters;
    case 'R':
      return meters;
    default:
      throw FormatException('Invalid XTE direction $direction');
  }
}

/// Parses a variation magnitude and sign, returning a positive value for West.
double _parseVariation(String valueString, String direction) {
  if (valueString.isEmpty) {
    throw const FormatException('Varation not populated');
  }
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
