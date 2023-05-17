// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:intl/intl.dart';
import 'package:nmea_dashboard/state/common.dart';

/// A transform to formatting values of a dimension for display.
abstract class Formatter<V> {
  final String longName;
  final String? units;
  final double heightFraction;
  final String invalid;
  final Type valueType = V;

  Formatter(this.longName, this.units, this.invalid,
      {this.heightFraction = 1.0});

  /// Returns the formatted string to display the supplied input.
  String format(V input);
}

/// Returns a map of allowable formatters for the supplied dimension.
Map<String, Formatter> formattersFor(Dimension? dimension) {
  return (dimension == null) ? {} : _formatters[dimension]!;
}

/// A formatter that is able to convert numbers to and from a target range.
abstract class ConvertingFormatter<V> extends Formatter<V> {
  ConvertingFormatter(super.longName, super.units, super.invalid,
      {super.heightFraction});

  /// Returns a convertion of the supplied input to the units displayed
  /// by this formatter.
  double convert(double input);

  /// Returns a convertion of the supplied input in the units displayed
  /// by this formatter back to the native units for the dimension.
  double unconvert(double input);
}

/// A formatter to format floating point numbers with a fixed number of DPs.
class SimpleFormatter extends ConvertingFormatter<SingleValue<double>> {
  final double scale;
  final int dp;

  SimpleFormatter(
      super.longName, super.units, super.invalid, this.scale, this.dp);

  /// Returns a convertion of the supplied input to the units displayed
  /// by this formatter.
  @override
  double convert(double input) {
    return input * scale;
  }

  /// Returns a convertion of the supplied input in the units displayed
  /// by this formatter back to the native units for the dimension.
  @override
  double unconvert(double input) {
    return input / scale;
  }

  @override
  String format(SingleValue<double> input) {
    return convert(input.value).toStringAsFixed(dp);
  }
}

/// A formatted to format integers.
class IntegerFormatter extends Formatter<SingleValue<int>> {
  IntegerFormatter(super.longName, super.units, super.invalid);

  @override
  String format(SingleValue input) {
    return input.value.toString();
  }
}

/// A formatter to format latitude/longitude pairs.
class PositionFormatter extends Formatter<DoubleValue<double>> {
  final bool includeSeconds;

  PositionFormatter(longName, this.includeSeconds)
      : super(longName, ' ', '---- ---\n---- ---');

  @override
  String format(DoubleValue<double> input) {
    return '${_formatComponent(input.first, 'N', 'S')}\n'
        '${_formatComponent(input.second, 'E', 'W')}';
  }

  String _formatComponent(value, positiveDir, negativeDir) {
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
  final Function function;

  CustomFormatter(super.longName, super.units, super.invalid, this.function,
      {super.heightFraction});

  @override
  String format(V input) {
    return function(input);
  }
}

/// A formatter based on custom conversion, unconvertion, and format functions
class CustomConvertingFormatter
    extends ConvertingFormatter<SingleValue<double>> {
  final double Function(double) conversion;
  final double Function(double) unconversion;
  final String Function(double) formatting;

  CustomConvertingFormatter(super.longName, super.units, super.invalid,
      {super.heightFraction,
      required this.conversion,
      required this.unconversion,
      required this.formatting});

  @override
  double convert(double input) {
    return conversion(input);
  }

  @override
  double unconvert(double input) {
    return unconversion(input);
  }

  @override
  String format(SingleValue<double> input) {
    return formatting(convert(input.value));
  }
}

/// A map of all the possible formatters for all dimensions.
final Map<Dimension, Map<String, Formatter>> _formatters = {
  Dimension.angle: {
    'degrees': SimpleFormatter('Degrees', '°', '--', 1.0, 0),
  },
  Dimension.angularRate: {
    'degreesPerSec': SimpleFormatter('deg/sec', '°/s', '--.-', 1.0, 1),
  },
  Dimension.bearing: {
    'true': CustomFormatter<AugmentedBearing>(
        'true', '°T', '---', (value) => _bearingString(value.bearing, 'T')),
    'mag': CustomFormatter<AugmentedBearing>('magnetic', '°M', '---', (value) {
      if (value.variation == null) {
        return 'no magnetic\nvariation';
      }
      return _bearingString((value.bearing + value.variation) % 360.0, 'M');
    }),
  },
  Dimension.crossTrackError: {
    'meters':
        CustomFormatter<SingleValue<double>>('meters', null, '---', (value) {
      return _xteString(value.value, 1.0, 'm');
    }),
    'feet': CustomFormatter<SingleValue<double>>('feet', null, '---', (value) {
      return _xteString(value.value, metersToFeet, 'ft');
    }),
  },
  Dimension.distance: {
    'km': SimpleFormatter('km', 'km', '---.--', metersToKilometers, 2),
    'nm': SimpleFormatter('nm', 'nm', '---.--', metersToNauticalMiles, 2),
  },
  Dimension.depth: {
    'meters': SimpleFormatter('meters', 'm', '--.-', 1.0, 1),
    'feet': SimpleFormatter('feet', 'ft', '--.-', metersToFeet, 1),
    'fathoms': SimpleFormatter('fathoms', 'f', '-.--', metersToFeet / 6, 2)
  },
  Dimension.integer: {'default': IntegerFormatter('default', null, '-')},
  Dimension.position: {
    'degMin': PositionFormatter('decimal min', false),
    'degMinSec': PositionFormatter('deg min sec', true),
  },
  Dimension.pressure: {
    'millibars': SimpleFormatter('millibar', 'mb', '----.-', 1 / 100.0, 1),
    'inchHg': SimpleFormatter(
        'inches mercury', 'in.hg', '--.--', pascalsToInchesMercury, 2)
  },
  Dimension.speed: {
    'metersPerSec': SimpleFormatter('m/sec', 'm/s', '-.-', 1.0, 1),
    'knots': SimpleFormatter('knots', 'kt', '-.-', metersPerSecondToKnots, 1),
    'knots2dp':
        SimpleFormatter('knots (2dp)', 'kt', '-.--', metersPerSecondToKnots, 2)
  },
  Dimension.temperature: {
    'celcius': SimpleFormatter('celcius', '°C', '--.-', 1.0, 1),
    'farenheit': CustomConvertingFormatter('farenheit', '°F', '--.-',
        conversion: (cel) => ((cel * 9.0 / 5.0) + 32.0),
        unconversion: (far) => ((far - 32.0) / 9.0 * 5.0),
        formatting: (far) => (far.toStringAsFixed(1)))
  },
  Dimension.time: {
    // Rendering time without date is very wide, so unlike most other data it
    // would tend to be sized in the cell aspect ratio we're aiming for based
    // on its (variable) width rather than its (fixed) height. This would lead
    // to an annoying scaling that changes every second. Try to prevent that
    // with a heightFraction heuristic although some wide fonts or unusual
    // screen sizes may still run into issues.
    'hms': CustomFormatter<SingleValue<DateTime>>('H:M:S', null, '--:--:--',
        (data) => DateFormat('Hms').format(data.value),
        heightFraction: 0.7),
    'ymdhms': CustomFormatter<SingleValue<DateTime>>(
        'Y-M-D H:M:S',
        'Y-M-D',
        '-------\n--:--:--',
        (data) => DateFormat('yyyy-MM-dd\nHH:mm:ss').format(data.value)),
  },
};

String _bearingString(double number, String suffix) {
  int rounded = number.round() % 360;
  return rounded.toString().padLeft(3, '0') + suffix;
}

String _xteString(double value, double conversion, String units) {
  // Treat +/- 1 meter as good enough.
  if (value >= -1 && value <= 1) {
    return 'On Track';
  }
  final converted = (value * conversion).round().abs();
  final guidance = (value < 0) ? 'Steer Left' : 'Steer Right';
  return '$converted $units\n$guidance';
}
