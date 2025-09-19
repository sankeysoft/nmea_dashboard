// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:intl/intl.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/values.dart';

const double barToPascals = 100000;
const double metersPerSecondToKnots = 1.94384;
const double metersPerSecondToKmph = 3.6;
const double metersToKilometers = 0.001;
const double metersToNauticalMiles = 0.000539957;
const double metersToFeet = 3.28084;
const double pascalsToInchesMercury = 0.0002953;
const double pascalsToMillibar = 0.01;
const double pascalsToPsi = 0.000145038;

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
// Hack to stop some properties annoyingly wrapping.
const Group _sys = Group.systems;

/// The various types of data that can be displayed, including the
/// sources we expect to find each on.
enum Property {
  airTemperature('Air temperature', 'Air', Dimension.temperature, group: Group.environment),
  apparentWindAngle('Apparent wind angle', 'AWA', Dimension.angle, group: Group.environment),
  apparentWindSpeed('Apparent wind speed', 'AWS', Dimension.speed, group: Group.environment),
  battery1Voltage('Battery 1 Voltage', 'Batt 1', Dimension.voltage, group: Group.systems),
  battery2Voltage('Battery 2 Voltage', 'Batt 2', Dimension.voltage, group: Group.systems),
  alternator1Voltage('Alternator 1 Voltage', 'Alt 1', Dimension.voltage, group: Group.systems),
  alternator2Voltage('Alternator 2 Voltage', 'Alt 2', Dimension.voltage, group: Group.systems),
  courseOverGround('Course over ground', 'COG', Dimension.bearing),
  currentSet('Set', 'Set', Dimension.bearing, group: Group.environment),
  currentDrift('Drift', 'Drift', Dimension.speed, group: Group.environment),
  depthWithOffset('Depth', 'Depth', Dimension.depth),
  depthUncalibrated('Depth at sensor', 'XDR Depth', Dimension.depth),
  dewPoint('Dew point', 'Dew Pt', Dimension.temperature, group: Group.environment),
  distanceTotal('Total distance', 'Log', Dimension.distance, group: Group.navigation),
  distanceTrip('Trip distance', 'Trip', Dimension.distance, group: Group.navigation),
  engine1Rpm('Engine 1 Speed', 'Eng Speed', Dimension.rotationalSpeed, group: Group.systems),
  engine2Rpm('Engine 1 Speed', 'Eng Speed', Dimension.rotationalSpeed, group: Group.systems),
  engine1OilPressure('Engine 1 Oil Pressure', 'Eng Pres', Dimension.pressure, group: Group.systems),
  engine2OilPressure('Engine 2 Oil Pressure', 'Eng Pres', Dimension.pressure, group: Group.systems),
  engine1Temperature('Engine 1 Coolant Temp', 'Eng Temp', Dimension.temperature, group: _sys),
  engine2Temperature('Engine 2 Coolant Temp', 'Eng Temp', Dimension.temperature, group: _sys),
  fuelLevel('Fuel Level', 'Fuel', Dimension.percentage, group: Group.systems),
  water1Level('Fresh Water 1 Level', 'Water 1', Dimension.percentage, group: Group.systems),
  water2Level('Fresh Water 2 Level', 'Water 2', Dimension.percentage, group: Group.systems),
  gpsPosition('GPS position', 'GPS', Dimension.position, group: Group.navigation),
  gpsHdop('GPS HDOP', 'HDOP', Dimension.depth, group: Group.navigation),
  heading('Heading', 'Heading', Dimension.bearing),
  // Sometimes a network message can only generate headings in magnetic so use
  // this property. All data elements work with a true heading internally hence
  // no sources provide this mag heading property.
  headingMag('Mag Heading', 'Mag Hdg', Dimension.bearing, sources: {}),
  pitch('Pitch angle', 'Pitch', Dimension.angle),
  pressure('Air pressure', 'Pressure', Dimension.pressure, group: Group.environment),
  rateOfTurn('Rate of turn', 'ROT', Dimension.angularRate),
  relativeHumidity('Relative Humidity', 'RH', Dimension.percentage, group: Group.environment),
  roll('Roll angle', 'Roll', Dimension.angle),
  rudderAngle('Rudder angle', 'Rudder', Dimension.angle),
  speedOverGround('Speed over ground', 'SOG', Dimension.speed),
  speedThroughWater('Speed through water', 'STW', Dimension.speed),
  trueWindAngle('True wind angle', 'TWA', Dimension.angle, group: Group.environment),
  trueWindDirection('True wind direction', 'TWD', Dimension.bearing, group: Group.environment),
  trueWindSpeed('True wind speed', 'TWS', Dimension.speed, group: Group.environment),
  utcTime('UTC datetime', 'UTC', Dimension.time, sources: {Source.local, Source.network}),
  localTime('Local datetime', 'Local', Dimension.time, sources: {Source.local}),
  variation('Magnetic variation', 'MagVar', Dimension.angle, group: Group.navigation),
  waterTemperature('Water temperature', 'Water', Dimension.temperature, group: Group.environment),
  waypointBearing('Bearing to waypoint', 'Wpt Brg', Dimension.bearing, group: Group.navigation),
  waypointRange('Range to waypoint', 'Wpt Rng', Dimension.distance, group: Group.navigation),
  crossTrackError('Cross track error', 'XTE', Dimension.crossTrackError, group: Group.navigation);

  /// A long name suitable for use during selection, e.g. "Speed over ground".
  final String longName;

  /// A short name suitable for use as a heading, e.g. "SOG".
  final String shortName;

  /// The dimension measured by this property.
  final Dimension dimension;

  /// The UI group for this property.
  final Group group;

  /// The sources that supply this property.
  final Set<Source> sources;

  const Property(
    this.longName,
    this.shortName,
    this.dimension, {
    this.sources = _networkOnly,
    this.group = Group.general,
  });

  /// The uniqualified name of this literal in its enum, e.g. "speedOverGround".
  String get name => toString().split('.').last;
}

/// High level groupings of properties to collect together in the UI.
enum Group {
  general('General'),
  navigation('Navigation'),
  environment('Environment'),
  systems('Systems');

  final String longName;

  const Group(this.longName);
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

  /// Returns a source from its unqualified name.
  static Source? fromString(String? name) {
    return Source.values.asNameMap()[name];
  }
}

/// The various types of dimension used across data elements.
enum Dimension {
  angle(type: SingleValue<double>, nativeUnits: 'degrees', derivationFriendly: true),
  angularRate(type: SingleValue<double>, nativeUnits: 'degrees/sec'),
  bearing(type: SingleValue<double>, nativeUnits: 'degrees true'),
  crossTrackError(type: SingleValue<double>, nativeUnits: 'meters'),
  distance(type: SingleValue<double>, nativeUnits: 'meters', derivationFriendly: true),
  depth(type: SingleValue<double>, nativeUnits: 'meters', derivationFriendly: true),
  integer(type: SingleValue<int>, nativeUnits: 'N/A'),
  percentage(type: SingleValue<double>, nativeUnits: 'N/A'),
  position(type: DoubleValue<double>, nativeUnits: 'lat/long degrees'),
  pressure(type: SingleValue<double>, nativeUnits: 'pascals', derivationFriendly: true),
  rotationalSpeed(type: SingleValue<double>, nativeUnits: 'rpm', derivationFriendly: true),
  speed(type: SingleValue<double>, nativeUnits: 'meters/sec', derivationFriendly: true),
  temperature(type: SingleValue<double>, nativeUnits: 'degrees celcius'),
  time(type: SingleValue<DateTime>, nativeUnits: 'datetime'),
  voltage(type: SingleValue<double>, nativeUnits: 'volts', derivationFriendly: true);

  final Type type;
  final String nativeUnits;
  final bool derivationFriendly;

  const Dimension({required this.type, required this.nativeUnits, this.derivationFriendly = false});

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
  average('Average Value'),
  history('History Graph');

  final String longName;

  const CellType(this.longName);

  /// Returns a cell type from its unqualified name.
  static CellType? fromString(String? name) {
    return CellType.values.asNameMap()[name];
  }
}

/// A time interval over which historical data may be tracked.
/// Declarations are clunky and repeated because we need the constructor to be
/// constant hence can't use non-const functions.
enum HistoryInterval {
  fifteenMin('15 minutes', '15min', Duration(seconds: 10), 90, Duration(minutes: 5), 'HH:mm'),
  twoHours('2 hours', '2hr', Duration(minutes: 1), 120, Duration(hours: 1), 'HH:mm'),
  twelveHours('12 hours', '12hr', Duration(minutes: 6), 120, Duration(hours: 3), 'HH:mm'),
  fortyEightHours('48 hours', '48hr', Duration(minutes: 30), 96, Duration(days: 1), 'MMM d');

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

  const HistoryInterval(
    this.display,
    this.short,
    this.segment,
    this.count,
    this.tick,
    this._format,
  );

  /// Returns a history interval from its unqualified name.
  static HistoryInterval? fromString(String? name) {
    return HistoryInterval.values.asNameMap()[name];
  }

  /// Returns the short name for a cell showing this interval for a property.
  String shortCellName(DataElement element) {
    return '${element.shortName} ($short)';
  }

  /// Returns the string used to format times in a cell showing this interval.
  String formatTime(DateTime time) {
    // Unfortunately dateformat is not const constructor so can't make earlier.
    return DateFormat(_format).format(time);
  }
}

/// A time interval over which statistics data may be calculated.
enum StatsInterval {
  fifteenSec('15 seconds', '15sec', Duration(seconds: 15)),
  oneMin('1 minute', '1min', Duration(minutes: 1)),
  fiveMin('5 minutes', '5min', Duration(minutes: 5));

  /// The string to display.
  final String display;

  /// A short string to display.
  final String short;

  /// The length of the interval.
  final Duration duration;

  const StatsInterval(this.display, this.short, this.duration);

  /// Returns a stats interval from its unqualified name.
  static StatsInterval? fromString(String? name) {
    return StatsInterval.values.asNameMap()[name];
  }

  /// Returns the short name for a cell showing this interval for a property.
  String shortCellName(DataElement element) {
    return '${element.shortName} ($short)';
  }
}
