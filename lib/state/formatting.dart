// Copyright Jody M Sankey 2022
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

  Formatter(this.longName, this.units, {this.heightFraction = 1.0});

  /// Returns the formatted string to display the supplied input.
  String format(V? input);
}

/// A formatter that can also generate a scalar number for each input,
/// e.g. for graphing.
abstract class NumericFormatter<V> extends Formatter<V> {
  NumericFormatter(super.longName, super.units, {super.heightFraction});

  /// Returns a numeric representation of the supplied input.
  double? toNumber(V? input);
}

/// Returns a map of allowable formatters for the supplied dimension.
Map<String, Formatter> formattersFor(Dimension? dimension) {
  return (dimension == null) ? {} : _formatters[dimension]!;
}

/// A numeric formatter that is able to reverse conversion toNumber.
abstract class ConvertingFormatter<V> extends NumericFormatter<V> {
  ConvertingFormatter(super.longName, super.units, {super.heightFraction});

  /// Returns a convertion of the supplied input in the units displayed
  /// by this formatter back to the native units for the dimension.
  V? fromNumber(double? input);
}

/// A formatter to format floating point numbers with a fixed number of DPs.
class SimpleFormatter extends ConvertingFormatter<SingleValue<double>> {
  final String invalid;
  final double scale;
  final int dp;

  SimpleFormatter(super.longName, super.units, this.invalid, this.scale, this.dp);

  /// Returns a convertion of the supplied input to the units displayed
  /// by this formatter.
  @override
  double? toNumber(SingleValue<double>? input) {
    return (input == null) ? null : input.data * scale;
  }

  /// Returns a convertion of the supplied input in the units displayed
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

/// A formatted to format integers.
class IntegerFormatter extends Formatter<SingleValue<int>> {
  final String invalid;

  IntegerFormatter(super.longName, super.units, this.invalid);

  @override
  String format(SingleValue<int>? input) {
    return (input == null) ? invalid : input.data.toString();
  }
}

/// A formatter to format latitude/longitude pairs.
class PositionFormatter extends Formatter<DoubleValue<double>> {
  final bool includeSeconds;

  PositionFormatter(String longName, this.includeSeconds) : super(longName, ' ');

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

  CustomFormatter(super.longName, super.units, this.function, {super.heightFraction});

  @override
  String format(V? input) {
    return function(input);
  }
}

/// A formatter based on custom conversion, unconvertion, and format functions
class CustomNumericFormatter<V> extends NumericFormatter<V> {
  final double? Function(V?) conversion;
  final String Function(V?) formatting;

  CustomNumericFormatter(
    super.longName,
    super.units, {
    super.heightFraction,
    required this.conversion,
    required this.formatting,
  });

  @override
  double? toNumber(V? input) {
    return conversion(input);
  }

  @override
  String format(V? input) {
    return formatting(input);
  }
}

/// A formatter based on custom conversion, unconvertion, and format functions
class CustomConvertingFormatter extends ConvertingFormatter<SingleValue<double>> {
  final String invalid;
  final double Function(double) conversion;
  final double Function(double) unconversion;
  final String Function(double) formatting;

  CustomConvertingFormatter(
    super.longName,
    super.units,
    this.invalid, {
    super.heightFraction,
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
  Dimension.angle: {'degrees': SimpleFormatter('Degrees', '°', '--', 1.0, 0)},
  Dimension.angularRate: {'degreesPerSec': SimpleFormatter('deg/sec', '°/s', '--.-', 1.0, 1)},
  Dimension.bearing: {
    'true': CustomNumericFormatter<AugmentedBearing>(
      'true',
      '°T',
      conversion: (value) => value?.bearing,
      formatting: (value) => (value == null) ? '---' : _bearingString(value.bearing, 'T'),
    ),
    'mag': CustomNumericFormatter<AugmentedBearing>(
      'magnetic',
      '°M',
      conversion: (value) =>
          (value?.variation == null) ? null : (value!.bearing + value.variation!) % 360.0,
      formatting: (value) {
        if (value == null) {
          return '---';
        } else if (value.variation == null) {
          return 'no magnetic\nvariation';
        } else {
          return _bearingString((value.bearing + value.variation!) % 360.0, 'M');
        }
      },
    ),
  },
  Dimension.crossTrackError: {
    'meters': CustomNumericFormatter<SingleValue<double>>(
      'meters',
      null,
      conversion: (value) => value?.data,
      formatting: (value) => (value == null) ? '---' : _xteString(value.data, 'm'),
    ),
    'feet': CustomNumericFormatter<SingleValue<double>>(
      'feet',
      null,
      conversion: (value) => (value == null) ? null : value.data * metersToFeet,
      formatting: (value) => (value == null) ? '---' : _xteString(value.data * metersToFeet, 'ft'),
    ),
  },
  Dimension.distance: {
    'km': SimpleFormatter('km', 'km', '---.--', metersToKilometers, 2),
    'nm': SimpleFormatter('nm', 'nm', '---.--', metersToNauticalMiles, 2),
  },
  Dimension.depth: {
    'meters': SimpleFormatter('meters', 'm', '--.-', 1.0, 1),
    'feet': SimpleFormatter('feet', 'ft', '--.-', metersToFeet, 1),
    'fathoms': SimpleFormatter('fathoms', 'f', '-.--', metersToFeet / 6, 2),
  },
  Dimension.integer: {'default': IntegerFormatter('default', null, '-')},
  Dimension.position: {
    'degMin': PositionFormatter('decimal min', false),
    'degMinSec': PositionFormatter('deg min sec', true),
  },
  Dimension.percentage: {'percent': SimpleFormatter('percent', '%', '--.-', 1.0, 1)},
  Dimension.pressure: {
    'millibars': SimpleFormatter('millibar', 'mb', '----.-', pascalsToMillibar, 1),
    'inchHg': SimpleFormatter('inches mercury', 'in.hg', '--.--', pascalsToInchesMercury, 2),
    'psi': SimpleFormatter('pounds per sq.inch', 'psi', '---.-', pascalsToPsi, 1),
  },
  Dimension.rotationalSpeed: {'rpm': SimpleFormatter('rpm', 'rpm', '-.-', 1.0, 1)},
  Dimension.speed: {
    'metersPerSec': SimpleFormatter('m/sec', 'm/s', '-.-', 1.0, 1),
    'knots': SimpleFormatter('knots', 'kt', '-.-', metersPerSecondToKnots, 1),
    'knots2dp': SimpleFormatter('knots (2dp)', 'kt', '-.--', metersPerSecondToKnots, 2),
  },
  Dimension.temperature: {
    'celcius': SimpleFormatter('celcius', '°C', '--.-', 1.0, 1),
    'farenheit': CustomConvertingFormatter(
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
    ),
    'ymdhms': CustomFormatter<SingleValue<DateTime>>(
      'Y-M-D H:M:S',
      'Y-M-D',
      (val) =>
          val == null ? '-------\n--:--:--' : DateFormat('yyyy-MM-dd\nHH:mm:ss').format(val.data),
    ),
  },
  Dimension.voltage: {'volts': SimpleFormatter('volts', 'V', '--.-', 1.0, 1)},
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
