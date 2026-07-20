// Copyright Jody M Sankey and Grigory Morozov 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/foundation.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:nmea_dashboard/state/values.dart';

part '127245.dart';
part '127250.dart';
part '127251.dart';
part '127258.dart';
part '127505.dart';
part '128259.dart';
part '128267.dart';
part '128275.dart';
part '129025.dart';
part '129026.dart';
part '129029.dart';
part '129033.dart';
part '129283.dart';
part '129284.dart';
part '129291.dart';
part '130306.dart';
part '130310.dart';
part '130313.dart';
part '130314.dart';
part '130316.dart';

/// A validator for assembled NMEA2000 messages with a 16 byte header.
class ForkValidator extends MessageValidator<ByteData, int> {
  static const int _headerLength = 16;

  @override
  ValidatedMessage<ByteData, int>? validate(ByteData raw) {
    if (raw.lengthInBytes < _headerLength) {
      throw const FormatException('Shorter than $_headerLength bytes');
    }

    final pgn = raw.getUint32(11, Endian.little);
    final source = raw.getUint8(8);

    final payloadLength = raw.getUint8(15);
    if (payloadLength < 1) {
      throw const FormatException('Payload length was zero');
    }

    final expectedLength = payloadLength + _headerLength;
    if (raw.lengthInBytes != expectedLength) {
      throw FormatException(
        'Invalid packet length, expected $expectedLength, got ${raw.lengthInBytes}',
      );
    }

    return ValidatedMessage(pgn, source, ByteData.sublistView(raw, _headerLength));
  }
}

/// Parses strings into nmea 2000 messages, keeping track of the count for each
/// message type.
class Nmea2000Parser extends MessageParser<ByteData, int> {
  static final List<PacketParser> _allParsers = [
    Parser127245(),
    Parser127250(),
    Parser127251(),
    Parser127258(),
    Parser127505(),
    Parser128259(),
    Parser128267(),
    Parser128275(),
    Parser129025(),
    Parser129026(),
    Parser129029(),
    Parser129033(),
    Parser129283(),
    Parser129284(),
    Parser129291(),
    Parser130306(),
    Parser130310(),
    Parser130313(),
    Parser130314(),
    Parser130316(),
  ];

  static final Map<int, PacketParser> _parserMap = {
    for (final parser in _allParsers) parser.pgn: parser,
  };

  /// The sentence types this parser supports.
  @visibleForTesting
  static Iterable<int> get supportedPgns => _parserMap.keys;

  @override
  List<BoundValue> parse(ValidatedMessage<ByteData, int> message) {
    final pgnString = message.type.toString();

    final parser = _parserMap[message.type];
    if (parser == null) {
      // Only cause logging of each unsupported PGN once per interval.
      if (unsupportedCounts.increment(pgnString) <= 1) {
        throw FormatException('Unsupported PGN $pgnString');
      }
      return [];
    }

    final values = parser.parse(message.payload);
    if (values.isEmpty) {
      // Only cause logging of each empty PGN once per interval.
      if (emptyCounts.increment(pgnString) <= 1) {
        throw FormatException('No data found in PGN $pgnString');
      }
      return [];
    }

    successCounts.increment(pgnString);
    return values;
  }
}

sealed class PacketParser {
  /// The parameter group number this parser handles.
  int get pgn;

  /// Attempts to create zero or more value containing NMEA message contents from the supplied
  /// NMEA 2000 payload, throwing a FormatException if unsuccessful.
  List<BoundValue> parse(ByteData payload);

  /// Validates the supplied payload matches the supplied length.
  void _validatePayloadLength(ByteData payload, int length) {
    if (payload.lengthInBytes != length) {
      throw FormatException(
        'PGN $pgn expected $length bytes payload, found ${payload.lengthInBytes}',
      );
    }
  }

  /// Validates the supplied payload is as least the supplied length.
  void _validateMinPayloadLength(ByteData payload, int length) {
    if (payload.lengthInBytes < length) {
      throw FormatException(
        'PGN $pgn payload length ${payload.lengthInBytes} less than minimum of $length',
      );
    }
  }

  /// Validates the supplied value is inside the expected range.
  void _validateInRange(double value, double min, double max) {
    if (value < min) {
      throw FormatException('PGN $pgn value $value below minimum of $min}');
    } else if (value > max) {
      throw FormatException('PGN $pgn value $value above maximum of $max}');
    }
  }
}

/// Reads a Uint16 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readUint16(ByteData payload, int offset) {
  final value = payload.getUint16(offset, Endian.little);
  return (value == 0xFFFF) ? null : value;
}

/// Reads an Int16 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readInt16(ByteData payload, int offset) {
  final value = payload.getInt16(offset, Endian.little);
  return (value >= 0x7FFD) ? null : value;
}

/// Reads a Uint24 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readUint24(ByteData payload, int offset) {
  int value = 0;
  for (int i = 0; i < 3; i++) {
    value |= payload.getUint8(offset + i) << (8 * i);
  }
  return (value == 0xFFFFFF) ? null : value;
}

/// Reads a Uint32 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readUint32(ByteData payload, int offset) {
  final value = payload.getUint32(offset, Endian.little);
  return (value == 0xFFFFFFFF) ? null : value;
}

/// Reads an Int32 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readInt32(ByteData payload, int offset) {
  final value = payload.getInt32(offset, Endian.little);
  return (value >= 0x7FFFFFFD) ? null : value;
}

/// Reads an Int64 from the supplied offset in payload, returning null if the content matches
/// the NMEA2000 "data not available" sentinel.
int? _readInt64(ByteData payload, int offset) {
  final value = payload.getInt64(offset, Endian.little);
  return (value >= 0x7FFFFFFFFFFFFFFD) ? null : value;
}

double? _scaleIfNotNull(int? value, double scale) {
  if (value == null) {
    return null;
  }
  return value * scale;
}

double? _scaleOffsetIfNotNull(int? value, double scale, double offset) {
  if (value == null) {
    return null;
  }
  return (value * scale) + offset;
}

int? _multiplyIfNotNull(int? value, int factor) {
  if (value == null) {
    return null;
  }
  return value * factor;
}
