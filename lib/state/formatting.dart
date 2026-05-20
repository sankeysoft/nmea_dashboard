// Cmpyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:intl/intl.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/values.dart';

/// A transform to formatting values of a dimension for display.
abstract class Formatter<V> {
  final String longName;
  final String? units;
  final double heightFraction;
  final Type valueType = V;
  final bool isDefault;

  Formatter(this.longName, this.units, {this.heightFraction = 1.0, this.isDefault = false});

  /// Returns the formatted string to display the supplied input.
  String format(V? input);
}

/// A formatter that can also generate a floating point number for each input and attempt to
/// recreate values based on this number, e.g. for graphing or supporting alarm triggering.
/// Some numeric formatters may always return null for `fromNumber`.
abstract class NumericFormatter<V> extends Formatter<V> {
  NumericFormatter(super.longName, super.units, {super.heightFraction, super.isDefault});

  /// Returns a numeric representation of the supplied input in the units
  /// displayed by this formatter.
  double? toNumber(V? input);

  /// Returns a conversion of the supplied input in the units displayed
  /// by this formatter back to the native units for the dimension.
  V? fromNumber(double? input);
}

/// Returns a map of allowable formatters for the supplied dimension.
Map<String, Formatter> formattersFor(Dimension? dimension) {
  return (dimension == null) ? {} : _formatters[dimension]!;
}

/// Returns a map of allowable numeric formatters for the supplied dimension.
Map<String, NumericFormatter> numericFormattersFor(Dimension? dimension) {
  if (dimension == null) return {};
  final ret = <String, NumericFormatter<dynamic>>{};
  for (final f in _formatters[dimension]!.entries) {
    if (f.value is NumericFormatter) {
      ret[f.key] = f.value as NumericFormatter;
    }
  }
  return ret;
}

/// A formatter to format floating point numbers with a fixed number of DPs.
class SimpleSvdFormatter extends NumericFormatter<SingleValue<double>> {
  final String invalid;
  final double scale;
  final int dp;

  SimpleSvdFormatter(
    super.longName,
    super.units,
    this.invalid,
    this.scale,
    this.dp, {
    super.isDefault,
  });

  /// Returns a conversion of the supplied input to the units displayed
  /// by this formatter.
  @override
  double? toNumber(SingleValue<double>? input) {
    return (input == null) ? null : input.data * scale;
  }

  /// Returns a conversion of the supplied input in the units displayed
  /// by this formatter back to the native units for the dimension.
  @override
  SingleValue<double>? fromNumber(double? input) {
    return (input == null) ? null : SingleValue(input / scale);
  }

  @override
  String format(SingleValue<double>? input) {
    final number = toNumber(input);
    return (number == null) ? invalid : number.toStringAsFixed(dp);
  }
}

/// A formatter to format latitude/longitude pairs.
class PositionFormatter extends Formatter<DoubleValue<double>> {
  final bool includeSeconds;

  PositionFormatter(String longName, this.includeSeconds, {super.isDefault}) : super(longName, ' ');

  @override
  String format(DoubleValue<double>? input) {
    return (input == null)
        ? '---- ---\n---- ---'
        : '${_formatComponent(input.first, 'N', 'S')}\n'
              '${_formatComponent(input.second, 'E', 'W')}';
  }

  String _formatComponent(double value, String positiveDir, String negativeDir) {
    final dir = (value >= 0) ? positiveDir : negativeDir;
    final deg = value.abs().floor();
    final min = (value.abs() - deg) * 60.0;
    if (includeSeconds) {
      final sec = (min - min.floor()) * 60.0;
      return '$deg° ${min.floor()}\' ${sec.toStringAsFixed(1)}" $dir';
    } else {
      return '$deg° ${min.toStringAsFixed(3)}\' $dir';
    }
  }
}

/// A formatter based on a custom function.
class CustomFormatter<V> extends Formatter<V> {
  final String Function(V?) function;

  CustomFormatter(
    super.longName,
    super.units,
    this.function, {
    super.heightFraction,
    super.isDefault,
  });

  @override
  String format(V? input) {
    return function(input);
  }
}

/// A numeric formatter based on custom conversion and format functions
class CustomNumericFormatter<V> extends NumericFormatter<V> {
  final double? Function(V?) conversion;
  final V? Function(double?) unconversion;
  final String Function(V?) formatting;

  CustomNumericFormatter(
    super.longName,
    super.units, {
    super.heightFraction,
    super.isDefault,
    required this.conversion,
    required this.unconversion,
    required this.formatting,
  });

  @override
  double? toNumber(V? input) {
    return conversion(input);
  }

  @override
  V? fromNumber(double? input) {
    return unconversion(input);
  }

  @override
  String format(V? input) {
    return formatting(input);
  }
}

/// A numeric formatter for `SingleValue<double>` that provides a bit more convenience than the
/// general case.
class CustomSvdFormatter extends NumericFormatter<SingleValue<double>> {
  final String invalid;
  final double Function(double) conversion;
  final double Function(double) unconversion;
  final String Function(double) formatting;

  CustomSvdFormatter(
    super.longName,
    super.units,
    this.invalid, {
    super.heightFraction,
    super.isDefault,
    required this.conversion,
    required this.unconversion,
    required this.formatting,
  });

  @override
  double? toNumber(SingleValue<double>? input) {
    return (input == null) ? null : conversion(input.data);
  }

  @override
  SingleValue<double>? fromNumber(double? input) {
    return (input == null) ? null : SingleValue(unconversion(input));
  }

  @override
  String format(SingleValue<double>? input) {
    return (input == null) ? invalid : formatting(conversion(input.data));
  }
}

/// A map of all the possible formatters for all dimensions.
final Map<Dimension, Map<String, Formatter>> _formatters = {
  Dimension.angle: {'degrees': SimpleSvdFormatter('degrees', '°', '--', 1.0, 0, isDefault: true)},
  Dimension.angularRate: {
    'degreesPerSec': SimpleSvdFormatter('deg/sec', '°/s', '--.-', 1.0, 1, isDefault: true),
  },
  Dimension.lateralAngle: {
    'degrees': CustomSvdFormatter(
      'degrees',
      '°',
      '---',
      conversion: (value) => _normalizeLateralAngle(value),
      unconversion: (number) => (_normalizeLateralAngle(number)),
      formatting: (value) => _lateralAngleString(value, false),
    ),
    'degreesPS': CustomSvdFormatter(
      'degrees P/S',
      '°',
      '---',
      conversion: (value) => _normalizeLateralAngle(value),
      unconversion: (number) => (_normalizeLateralAngle(number)),
      formatting: (value) => _lateralAngleString(value, true),
      isDefault: true,
    ),
  },
  Dimension.bearing: {
    'true': CustomNumericFormatter<AugmentedBearing>(
      'true',
      '°T',
      conversion: (value) => value?.bearing,
      // Not possible to construct an augmented bearing without adding variation.
      unconversion: (number) => null,
      formatting: (value) => (value == null) ? '---' : _bearingString(value.bearing, 'T'),
    ),
    'mag': CustomNumericFormatter<AugmentedBearing>(
      'magnetic',
      '°M',
      conversion: (value) =>
          (value?.variation == null) ? null : (value!.bearing + value.variation!) % 360.0,
      // Not possible to construct an augmented bearing without adding variation.
      unconversion: (number) => null,
      formatting: (value) {
        if (value == null) {
          return '---';
        } else if (value.variation == null) {
          return 'no magnetic\nvariation';
        } else {
          return _bearingString((value.bearing + value.variation!) % 360.0, 'M');
        }
      },
      isDefault: true,
    ),
  },
  Dimension.crossTrackError: {
    'meters': CustomSvdFormatter(
      'meters',
      null,
      '---',
      conversion: (value) => value,
      unconversion: (value) => value,
      formatting: (value) => _xteString(value, 'm'),
    ),
    'feet': CustomSvdFormatter(
      'feet',
      null,
      '---',
      conversion: (value) => value * metersToFeet,
      unconversion: (value) => value / metersToFeet,
      formatting: (value) => _xteString(value, 'ft'),
      isDefault: true,
    ),
  },
  Dimension.distance: {
    'km': SimpleSvdFormatter('km', 'km', '---.--', metersToKilometers, 2),
    'nm': SimpleSvdFormatter('nm', 'nm', '---.--', metersToNauticalMiles, 2, isDefault: true),
  },
  Dimension.depth: {
    'meters': SimpleSvdFormatter('meters', 'm', '--.-', 1.0, 1),
    'feet': SimpleSvdFormatter('feet', 'ft', '--.-', metersToFeet, 1, isDefault: true),
    'fathoms': SimpleSvdFormatter('fathoms', 'f', '-.--', metersToFeet / 6, 2),
  },
  Dimension.integer: {
    'default': CustomNumericFormatter<SingleValue<int>>(
      'default',
      null,
      conversion: (value) => value?.data.toDouble(),
      unconversion: (number) => (number == null) ? null : SingleValue(number.round()),
      formatting: (value) => (value == null) ? '-' : value.data.toString(),
      isDefault: true,
    ),
  },
  Dimension.position: {
    'degMin': PositionFormatter('decimal min', false, isDefault: true),
    'degMinSec': PositionFormatter('deg min sec', true),
  },
  Dimension.percentage: {
    'percent': SimpleSvdFormatter('percent', '%', '--.-', 1.0, 1, isDefault: true),
  },
  Dimension.pressure: {
    'millibars': SimpleSvdFormatter(
      'millibar',
      'mb',
      '----.-',
      pascalsToMillibar,
      1,
      isDefault: true,
    ),
    'inchHg': SimpleSvdFormatter('inches mercury', 'in.hg', '--.--', pascalsToInchesMercury, 2),
    'psi': SimpleSvdFormatter('pounds per sq.inch', 'psi', '---.-', pascalsToPsi, 1),
  },
  Dimension.rotationalSpeed: {
    'rpm': SimpleSvdFormatter('rpm', 'rpm', '---', 1.0, 0, isDefault: true),
  },
  Dimension.speed: {
    'metersPerSec': SimpleSvdFormatter('m/sec', 'm/s', '-.-', 1.0, 1),
    'knots': SimpleSvdFormatter('knots', 'kt', '-.-', metersPerSecondToKnots, 1, isDefault: true),
    'knots2dp': SimpleSvdFormatter('knots (2dp)', 'kt', '-.--', metersPerSecondToKnots, 2),
  },
  Dimension.temperature: {
    'celcius': SimpleSvdFormatter('celcius', '°C', '--.-', 1.0, 1, isDefault: true),
    'farenheit': CustomSvdFormatter(
      'farenheit',
      '°F',
      '--.-',
      conversion: (cel) => ((cel * 9.0 / 5.0) + 32.0),
      unconversion: (far) => ((far - 32.0) / 9.0 * 5.0),
      formatting: (far) => (far.toStringAsFixed(1)),
    ),
  },
  Dimension.time: {
    // Rendering time without date is very wide, so unlike most other data it
    // would tend to be sized in the cell aspect ratio we're aiming for based
    // on its (variable) width rather than its (fixed) height. This would lead
    // to an annoying scaling that changes every second. Try to prevent that
    // with a heightFraction heuristic although some wide fonts or unusual
    // screen sizes may still run into issues.
    'hms': CustomFormatter<SingleValue<DateTime>>(
      'H:M:S',
      null,
      (val) => val == null ? '--:--:--' : DateFormat('Hms').format(val.data),
      heightFraction: 0.7,
      isDefault: true,
    ),
    'ymdhms': CustomFormatter<SingleValue<DateTime>>(
      'Y-M-D H:M:S',
      'Y-M-D',
      (val) =>
          val == null ? '-------\n--:--:--' : DateFormat('yyyy-MM-dd\nHH:mm:ss').format(val.data),
    ),
  },
  Dimension.voltage: {'volts': SimpleSvdFormatter('volts', 'V', '--.-', 1.0, 1, isDefault: true)},
};

String _bearingString(double number, String suffix) {
  int rounded = number.round() % 360;
  return rounded.toString().padLeft(3, '0') + suffix;
}

String _xteString(double number, String units) {
  // Treat +/- 1 of whatever input we're working in as good enough.
  if (number >= -1 && number <= 1) {
    return 'On Track';
  }
  final guidance = (number < 0) ? 'Steer Left' : 'Steer Right';
  return '${number.round().abs()} $units\n$guidance';
}

double _normalizeLateralAngle(double number) {
  final mod = (number % 360);
  return (mod > 180) ? mod - 360 : mod;
}

String _lateralAngleString(double number, bool includePortStarboard) {
  int base = _normalizeLateralAngle(number).round();
  if (includePortStarboard) {
    if (base == 0) {
      return '0';
    } else if (base < 0) {
      return '${base.abs()}P';
    } else {
      return '${base}S';
    }
  } else {
    return (base >= 0 ? '+' : '') + base.toString();
  }
}
