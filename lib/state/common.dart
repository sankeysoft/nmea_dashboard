// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

const double metersPerSecondToKnots = 1.94384;
const double metersToKilometers = 0.001;
const double metersToNauticalMiles = 0.000539957;
const double metersToFeet = 3.28084;
const double pascalsToInchesMercury = 0.0002953;

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
  apparentWindAngle('Apparent wind angle', 'AWA', Dimension.angle),
  apparentWindSpeed('Apparent wind speed', 'AWS', Dimension.speed),
  courseOverGround('Course over ground', 'COG', Dimension.bearing),
  currentSet('Set', 'Set', Dimension.bearing),
  currentDrift('Drift', 'Drift', Dimension.speed),
  depthWithOffset('Depth', 'Depth', Dimension.depth),
  depthUncalibrated('Depth at sensor', 'XDR Depth', Dimension.depth),
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

/// A value is a single instance of the data for some property.
abstract class Value {
  /// The high level source that the datum came from (e.g. network)
  final Source source;

  /// The quality/preference of the data source, where 1 represents the best
  /// quality/most preferred source for this property and higher numbers
  /// represent lower preferences.
  final int tier;

  /// The property that this datum applies to.
  final Property property;

  Value(this.source, this.property, this.tier);
}

/// A value containing a single primitive.
class SingleValue<T> extends Value {
  final T value;

  SingleValue(this.value, source, property, {tier = 1})
      : super(source, _verifyType(property, SingleValue<T>), tier);

  @override
  String toString() {
    return "S=$source($tier), P=$property, V=$value";
  }
}

/// A value containing two primitives.
class DoubleValue<T> extends Value {
  final T first;
  final T second;

  DoubleValue(this.first, this.second, source, property, {tier = 1})
      : super(source, _verifyType(property, DoubleValue<T>), tier);

  @override
  String toString() {
    return "S=$source($tier), P=$property, V=$first,$second";
  }
}

/// A special value that augments a bearing with an optional variation needed
/// to display it with conversion between magnetic and true.
class AugmentedBearing extends Value {
  final double bearing;
  final double? variation;

  AugmentedBearing(SingleValue<double> bearing, SingleValue<double>? variation,
      {tier = 1})
      : bearing = bearing.value,
        variation = variation?.value,
        super(bearing.source, bearing.property, tier) {
    if (variation != null && variation.property != Property.variation) {
      throw InvalidTypeException(
          'Cannot contruct AugmentedBearing with varation of $variation.property');
    }
    if (bearing.property.dimension != Dimension.bearing) {
      throw InvalidTypeException(
          'Cannot contruct AugmentedBearing with bearing of $bearing.property');
    }
  }

  @override
  String toString() {
    return "S=$source($tier), P=$property, Brg=$bearing Var=$variation";
  }
}

/// Verifies that the expected type of the supplied property matches
/// the supplied storage type, throwing an exception if not.
Property _verifyType(Property property, Type storage) {
  if (property.dimension.type != storage) {
    throw InvalidTypeException('Cannot store $property in $storage');
  }
  return property;
}
