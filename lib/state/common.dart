// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:intl/intl.dart';

import 'data_element.dart';

const double barToPascals = 10000;
const double metersPerSecondToKnots = 1.94384;
const double metersToKilometers = 0.001;
const double metersToNauticalMiles = 0.000539957;
const double metersToFeet = 3.28084;
const double pascalsToInchesMercury = 0.0002953;

const int serializationDp = 4;

/// A custom exception thrown for all cases of type incompatibility,
/// which should always mean an internal consistency bug of some
/// form.
class InvalidTypeException implements Exception {
  String cause;
  InvalidTypeException(this.cause);

  @override
  String toString() {
    return 'InvalidTypeException: $cause';
  }
}

const Set<Source> _networkOnly = {Source.network};

/// The various types of data that can be displayed, including the
/// sources we expect to find it on.
enum Property {
  airTemperature('Air temperature', 'Air', Dimension.temperature),
  apparentWindAngle('Apparent wind angle', 'AWA', Dimension.angle),
  apparentWindSpeed('Apparent wind speed', 'AWS', Dimension.speed),
  courseOverGround('Course over ground', 'COG', Dimension.bearing),
  currentSet('Set', 'Set', Dimension.bearing),
  currentDrift('Drift', 'Drift', Dimension.speed),
  depthWithOffset('Depth', 'Depth', Dimension.depth),
  depthUncalibrated('Depth at sensor', 'XDR Depth', Dimension.depth),
  dewPoint('Dew point', 'DewPt', Dimension.temperature),
  distanceTotal('Total distance', 'Log', Dimension.distance),
  distanceTrip('Trip distance', 'Trip', Dimension.distance),
  gpsPosition('GPS position', 'GPS', Dimension.position),
  gpsHdop('GPS HDOP', 'HDOP', Dimension.depth),
  heading('Heading', 'Heading', Dimension.bearing),
  // Sometimes a network message can only generate headings in magnetic so use
  // this property. All data elements work with a true heading internally hence
  // no sources provide this mag heading property.
  headingMag('Mag Heading', 'Mag Hdg', Dimension.bearing, sources: {}),
  pitch('Pitch angle', 'Pitch', Dimension.angle),
  pressure('Air pressure', 'Pressure', Dimension.pressure),
  rateOfTurn('Rate of turn', 'ROT', Dimension.angularRate),
  relativeHumidity('Relative Humidity', 'RH', Dimension.percentage),
  roll('Roll angle', 'Roll', Dimension.angle),
  rudderAngle('Rudder angle', 'Rudder', Dimension.angle),
  speedOverGround('Speed over ground', 'SOG', Dimension.speed),
  speedThroughWater('Speed through water', 'STW', Dimension.speed),
  trueWindDirection('True wind direction', 'TWD', Dimension.bearing),
  trueWindSpeed('True wind speed', 'TWS', Dimension.speed),
  utcTime('UTC datetime', 'UTC', Dimension.time,
      sources: {Source.local, Source.network}),
  localTime('Local datetime', 'Local', Dimension.time, sources: {Source.local}),
  variation('Magnetic variation', 'MagVar', Dimension.angle),
  waterTemperature('Water temperature', 'Water', Dimension.temperature),
  waypointBearing('Bearing to waypoint', 'Wpt Brg', Dimension.bearing),
  waypointRange('Range to waypoint', 'Wpt Rng', Dimension.distance),
  crossTrackError('Cross track error', 'XTE', Dimension.crossTrackError);

  /// A long name suitable for use during selection, e.g. "Speed over ground".
  final String longName;

  /// A short name suitable for use as a heading, e.g. "SOG".
  final String shortName;

  /// The dimension measured by this property.
  final Dimension dimension;

  /// The sources that supply this property.
  final Set<Source> sources;

  const Property(this.longName, this.shortName, this.dimension,
      {this.sources = _networkOnly});

  /// The uniqualified name of this literal in its enum, e.g. "speedOverGround".
  String get name => toString().split('.').last;
}

/// The various sources that can provide data.
enum Source {
  unset('Not Yet Set', selectable: false),
  network('Network'),
  local('Local device'),
  derived('Derived data');

  final String longName;
  final bool selectable;

  const Source(this.longName, {this.selectable = true});

  /// Returns a derivation operation from its unqualified name.
  static Source? fromString(String? name) {
    return Source.values.asNameMap()[name];
  }
}

/// The various types of dimension used across data elements.
enum Dimension {
  angle(
      type: SingleValue<double>,
      nativeUnits: 'degrees',
      derivationFriendly: true),
  angularRate(type: SingleValue<double>, nativeUnits: 'degrees/sec'),
  bearing(type: SingleValue<double>, nativeUnits: 'degrees true'),
  crossTrackError(type: SingleValue<double>, nativeUnits: 'meters'),
  distance(
      type: SingleValue<double>,
      nativeUnits: 'meters',
      derivationFriendly: true),
  depth(
      type: SingleValue<double>,
      nativeUnits: 'meters',
      derivationFriendly: true),
  integer(type: SingleValue<int>, nativeUnits: 'N/A'),
  percentage(type: SingleValue<double>, nativeUnits: 'N/A'),
  position(type: DoubleValue<double>, nativeUnits: 'lat/long degrees'),
  pressure(
      type: SingleValue<double>,
      nativeUnits: 'pascals',
      derivationFriendly: true),
  speed(
      type: SingleValue<double>,
      nativeUnits: 'meters/sec',
      derivationFriendly: true),
  temperature(type: SingleValue<double>, nativeUnits: 'degrees celcius'),
  time(type: SingleValue<DateTime>, nativeUnits: 'datetime');

  final Type type;
  final String nativeUnits;
  final bool derivationFriendly;

  const Dimension(
      {required this.type,
      required this.nativeUnits,
      this.derivationFriendly = false});

  /// Returns a derivation operation from its unqualified name.
  static Dimension? fromString(String? name) {
    return Dimension.values.asNameMap()[name];
  }
}

/// An operation that may be performed on one data element to derive another.
enum Operation {
  add('+'),
  subtract('-'),
  multiply('*');

  /// The string to display.
  final String display;

  const Operation(this.display);

  /// Applies this operation to the supplied input.
  double apply(double input, double operand) {
    switch (this) {
      case Operation.add:
        return input + operand;
      case Operation.subtract:
        return input - operand;
      case Operation.multiply:
        return input * operand;
    }
  }

  /// Applies the inverse of this operation to the supplied input.
  double reverse(double input, double operand) {
    switch (this) {
      case Operation.add:
        return input - operand;
      case Operation.subtract:
        return input + operand;
      case Operation.multiply:
        return input / operand;
    }
  }

  /// Returns an operation from its unqualified name.
  static Operation? fromString(String? name) {
    return Operation.values.asNameMap()[name];
  }
}

/// The various sources types of data cell that can be defined.
enum CellType {
  current('Current Value'),
  history('History Graph');

  final String longName;

  const CellType(this.longName);

  /// Returns a cell type from its unqualified name.
  static CellType? fromString(String? name) {
    return CellType.values.asNameMap()[name];
  }
}

/// A time interval over which historical data may be tracked.
enum HistoryInterval {
  fifteenMin('15 minutes', '15min', Duration(seconds: 10), 90,
      Duration(minutes: 5), 'HH:mm'),
  twoHours(
      '2 hours', '2hr', Duration(minutes: 1), 120, Duration(hours: 1), 'HH:mm'),
  twelveHours('12 hours', '12hr', Duration(minutes: 6), 120, Duration(hours: 3),
      'HH:mm'),
  fortyEightHours('48 hours', '48hr', Duration(minutes: 30), 96,
      Duration(days: 1), 'MMM d');

  /// The string to display.
  final String display;

  /// A short string to display.
  final String short;

  /// The length of each segment in the interval.
  final Duration segment;

  /// The length between tickmarks on a graph of the interval.
  final Duration tick;

  /// The total number of segments to track.
  final int count;

  /// The string used to format times inside this interval.
  final String _format;

  const HistoryInterval(this.display, this.short, this.segment, this.count,
      this.tick, this._format);

  /// Returns a history interval from its unqualified name.
  static HistoryInterval? fromString(String? name) {
    return HistoryInterval.values.asNameMap()[name];
  }

  /// Returns the short name for a cell showing this interval for a property.
  String shortCellName(DataElement element) {
    return '${element.shortName} ($short)';
  }

  /// Returns the short name for a cell showing this interval for a property.
  String formatTime(DateTime time) {
    // Unfortunately dateformat is not const constructor so can't make earlier.
    return DateFormat(_format).format(time);
  }
}

/// A bound value is a single instance of the data for some property in some
/// source.
class BoundValue<V extends Value> {
  /// The high level source that the datum came from (e.g. network).
  final Source source;

  /// The quality/preference of the data source, where 1 represents the best
  /// quality/most preferred source for this property and higher numbers
  /// represent lower preferences.
  final int tier;

  /// The property that this datum applies to.
  final Property property;

  /// The actual data.
  final V value;

  BoundValue(this.source, this.property, this.value, {this.tier = 1}) {
    _verifyType(property, V);
  }

  @override
  String toString() {
    return "S=$source($tier), P=$property, V=$value";
  }
}

/// A value is a single instance of the data that may be associated with some
/// property.
abstract class Value {
  /// Serializes this value to a string.
  String serialize();

  /// Deserializes the supplied string as the supplied concrete type.
  static V? deserialize<V extends Value>(String input) {
    if (V == SingleValue<double>) {
      return SingleValue.deserialize(input) as V?;
    } else if (V == DoubleValue<double>) {
      return DoubleValue.deserialize(input) as V?;
    } else if (V == AugmentedBearing) {
      return AugmentedBearing.deserialize(input) as V?;
    }
    throw InvalidTypeException('Deserialize for type $V not known');
  }
}

/// A value containing a single primitive.
class SingleValue<T> extends Value {
  final T data;

  SingleValue(this.data);

  /// Deserialized the supplied string (created by calling serialize) back to
  /// the original value, returning null if the input was not valid.
  static SingleValue<double>? deserialize(String input) {
    final num = double.tryParse(input);
    return num == null ? null : SingleValue(num);
  }

  @override
  String toString() {
    return data.toString();
  }

  @override
  String serialize() {
    if (T == double) {
      return (data as double).toStringAsFixed(serializationDp);
    }
    return data.toString();
  }
}

/// A value containing two primitives.
class DoubleValue<T> extends Value {
  final T first;
  final T second;

  DoubleValue(this.first, this.second);

  /// Deserialized the supplied string (created by calling serialize) back to
  /// the original value, returning null if the input was not valid.
  static DoubleValue<double>? deserialize(String input) {
    final components = input.split('/');
    if (components.length != 2) {
      return null;
    }
    final first = double.tryParse(components[0]);
    final second = double.tryParse(components[1]);
    if (first == null || second == null) {
      return null;
    }
    return DoubleValue(first, second);
  }

  @override
  String toString() {
    return "$first/$second";
  }

  @override
  String serialize() {
    if (T == double) {
      final firstStr = (first as double).toStringAsFixed(serializationDp);
      final secondStr = (second as double).toStringAsFixed(serializationDp);
      return '$firstStr/$secondStr';
    }
    return '$first/$second';
  }
}

/// A special value that augments a bearing with an optional variation needed
/// to display it with conversion between magnetic and true.
class AugmentedBearing extends Value {
  final double bearing;
  final double? variation;

  AugmentedBearing(SingleValue<double> bearing, SingleValue<double>? variation)
      : bearing = bearing.data,
        variation = variation?.data;

  /// Convenience method to create an AugmentedBearing with doubles rather
  /// than SingleValue<double>s.
  static AugmentedBearing fromNumbers(double bearing, double? variation) {
    return AugmentedBearing(SingleValue(bearing),
        variation == null ? null : SingleValue(variation));
  }

  /// Deserialized the supplied string (created by calling serialize) back to
  /// the original value, returning null if the input was not valid.
  static AugmentedBearing? deserialize(String input) {
    final components = input.split('/');
    if (components.length != 2) {
      return null;
    }
    final bearing = double.tryParse(components[0]);
    if (bearing == null) {
      return null;
    }
    if (components[1] == 'null') {
      return AugmentedBearing(SingleValue(bearing), null);
    }
    final variation = double.tryParse(components[1]);
    if (variation == null) {
      return null;
    }
    return AugmentedBearing(SingleValue(bearing), SingleValue(variation));
  }

  @override
  String toString() {
    return "(Brg=$bearing Var=$variation)";
  }

  @override
  String serialize() {
    final bearingStr = bearing.toStringAsFixed(serializationDp);
    final variationStr = variation == null
        ? 'null'
        : variation!.toStringAsFixed(serializationDp);
    return '$bearingStr/$variationStr';
  }
}

/// A class to accumulate values of some type into an average.
abstract class ValueAccumulator<V extends Value> {
  /// Adds a new value into this accumulator.
  add(V value);

  /// Returns the average of the values added into this accumulator and clears
  /// state to begin additional accumulation.
  V? getAndClear();

  /// Returns a value accumulator suitable for accumulating the supplied type.
  static ValueAccumulator<dynamic> forType(Type type) {
    if (type == SingleValue<double>) {
      return SingleValueAccumulator();
    } else if (type == AugmentedBearing) {
      return AugmentedBearingAccumulator();
    }
    throw InvalidTypeException('ValueAccumulator for type $type not known');
  }
}

class SingleValueAccumulator extends ValueAccumulator<SingleValue<double>> {
  NumericAccumulator num;

  SingleValueAccumulator() : num = NumericAccumulator();

  @override
  add(SingleValue<double> value) {
    num.add(value.data);
  }

  @override
  SingleValue<double>? getAndClear() {
    final d = num.getAndClear();
    return d == null ? null : SingleValue(d);
  }
}

class AugmentedBearingAccumulator extends ValueAccumulator<AugmentedBearing> {
  NumericAccumulator bearing;
  NumericAccumulator variation;

  AugmentedBearingAccumulator()
      : bearing = NumericAccumulator(),
        variation = NumericAccumulator();

  @override
  add(AugmentedBearing value) {
    bearing.add(value.bearing);
    if (value.variation != null) {
      variation.add(value.variation!);
    }
  }

  @override
  AugmentedBearing? getAndClear() {
    final b = bearing.getAndClear();
    final v = variation.getAndClear();
    return b == null ? null : AugmentedBearing.fromNumbers(b, v);
  }
}

/// A class to accumulate values of some type into an average.
class NumericAccumulator {
  int count;
  double? total;

  NumericAccumulator() : count = 0;

  // Adds a new value into this accumulator.
  add(double value) {
    count += 1;
    total = (total == null) ? value : total! + value;
  }

  /// Returns the average of the values added into this accumulator.
  double? getAndClear() {
    final average = (total == null) ? null : total! / count;
    count = 0;
    total = null;
    return average;
  }
}

/// Verifies that the expected type of the supplied property matches
/// the supplied storage type, throwing an exception if not.
Property _verifyType(Property property, Type storage) {
  if (property.dimension.type != storage) {
    throw InvalidTypeException(
        'Cannot bind $storage to $property, expected ${property.dimension.type}');
  }
  return property;
}
