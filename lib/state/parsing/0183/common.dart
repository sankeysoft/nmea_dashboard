// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';
import 'dart:math' as math;

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
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

/// A validator for NMEA0183 messages.
class Nmea0183Validator extends MessageValidator<String, String> {
  final bool _requireChecksum;

  /// Constructs a new validator for NMEA messages
  Nmea0183Validator(this._requireChecksum);

  @override
  ValidatedMessage<String, String>? validate(String raw) {
    if (raw.startsWith('!')) {
      // Silently discard encapsulated sentences (e.g. AIS).
      return null;
    } else if (!raw.startsWith('\$')) {
      // Thow an exception for any other prefix.
      throw const FormatException('Does not start with \$');
    }

    // Try to validate and remove a checksum if there is one, throw an error if there
    // isn't a checksum but we require one.
    if (raw.length > 3 && raw[raw.length - 3] == '*') {
      _validateChecksum(raw.substring(1, raw.length - 3), raw.substring(raw.length - 2));
      raw = raw.substring(0, raw.length - 3);
    } else if (_requireChecksum) {
      throw const FormatException('Does not end in a checksum');
    }

    // Check length.
    if (raw.length < 7) {
      throw const FormatException('Message is truncated');
    }
    return ValidatedMessage(raw.substring(3, 6), raw.substring(1, 3), raw.substring(7));
  }

  /// Validates that the supplied content matches the expected ASCII checksum, throwing
  /// a FormatException if not.
  static void _validateChecksum(String content, String checksumString) {
    final int checksumInt = int.parse(checksumString, radix: 16);
    int xor = 0;
    for (final codeUnit in content.codeUnits) {
      xor ^= codeUnit;
    }
    if (xor != checksumInt) {
      throw FormatException(
        'Invalid checksum: expected 0x${checksumInt.toRadixString(16)}, '
        'got 0x${xor.toRadixString(16)}',
      );
    }
  }
}

/// Parses strings into nmea messages, keeping track of the count for each
/// message type.
class Nmea0183Parser extends MessageParser<String, String> {
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

  /// The list of message types that are silently ignored.
  @override
  Set<String> get ignoredTypes => {
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

  static final Map<String, SentenceParser> _parserMap = {
    for (final parser in _allParsers) parser.type: parser,
  };

  static final Set<String> _supportedTypes = _parserMap.keys.toSet();

  @override
  Set<String> get supportedTypes => _supportedTypes;

  @override
  List<BoundValue> parse(ValidatedMessage<String, String> message) {
    // Lookup a parser for this sentence type, the base class should only call us for messages
    // we support so throw an exception if we don't find one.
    final parser = _parserMap[message.type];
    if (parser == null) {
      throw const FormatException('Unsupported message type');
    }

    final fields = message.payload.split(',');
    return parser.parse(fields);
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
  return boundSingleValue(number, property, tier: tier);
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
