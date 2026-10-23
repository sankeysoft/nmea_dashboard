// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:intl/intl.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/values.dart';

const double barToPascals = 100000;
const double litersToUsGallons = 0.264172;
const double metersPerSecondToKnots = 1.94384;
const double metersPerSecondToKmph = 3.6;
const double metersToKilometers = 0.001;
const double metersToNauticalMiles = 0.000539957;
const double metersToFeet = 3.28084;
const double pascalsToInchesMercury = 0.0002953;
const double pascalsToMillibar = 0.01;
const double pascalsToPsi = 0.000145038;
const double radiansToDegrees = 180.0 / pi;
const double secondsToHours = 1.0 / 3600.0;
const double absoluteZeroInCelcius = -273.15;

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
  apparentWindAngle('Apparent wind angle', 'AWA', Dimension.lateralAngle, group: Group.environment),
  anchorRode('Anchor rode deployed', 'Rode', Dimension.depth, group: Group.systems),
  apparentWindSpeed('Apparent wind speed', 'AWS', Dimension.speed, group: Group.environment),
  battery1Voltage('Battery 1 Voltage', 'Batt 1', Dimension.voltage, group: Group.systems),
  battery2Voltage('Battery 2 Voltage', 'Batt 2', Dimension.voltage, group: Group.systems),
  battery1Current('Battery 1 Current', 'Batt 1', Dimension.current, group: Group.systems),
  battery2Current('Battery 2 Current', 'Batt 2', Dimension.current, group: Group.systems),
  battery1Charge('Battery 1 Charge', 'Batt 1', Dimension.percentage, group: Group.systems),
  battery2Charge('Battery 2 Charge', 'Batt 2', Dimension.percentage, group: Group.systems),
  blackWaterLevel('Black Water', 'Waste', Dimension.percentage, group: Group.systems),
  alternator1Voltage('Alternator 1 Voltage', 'Alt 1', Dimension.voltage, group: Group.systems),
  alternator2Voltage('Alternator 2 Voltage', 'Alt 2', Dimension.voltage, group: Group.systems),
  courseOverGround('Course over ground', 'COG', Dimension.bearing),
  crossTrackError('Cross track error', 'XTE', Dimension.crossTrackError, group: Group.navigation),
  currentSet('Set', 'Set', Dimension.bearing, group: Group.environment),
  currentDrift('Drift', 'Drift', Dimension.speed, group: Group.environment),
  depthWithOffset('Depth', 'Depth', Dimension.depth),
  depthUncalibrated('Depth at sensor', 'XDR Depth', Dimension.depth),
  dewPoint('Dew point', 'Dew Pt', Dimension.temperature, group: Group.environment),
  distanceTotal('Total distance', 'Log', Dimension.distance, group: Group.navigation),
  distanceTrip('Trip distance', 'Trip', Dimension.distance, group: Group.navigation),
  engine1Rpm('Engine 1 Speed', 'Eng Speed', Dimension.rotationalSpeed, group: Group.systems),
  engine2Rpm('Engine 2 Speed', 'Eng Speed', Dimension.rotationalSpeed, group: Group.systems),
  engine1OilPressure('Engine 1 Oil Pressure', 'Eng Pres', Dimension.pressure, group: Group.systems),
  engine2OilPressure('Engine 2 Oil Pressure', 'Eng Pres', Dimension.pressure, group: Group.systems),
  engine1Temperature('Engine 1 Coolant Temp', 'Eng Temp', Dimension.temperature, group: _sys),
  engine2Temperature('Engine 2 Coolant Temp', 'Eng Temp', Dimension.temperature, group: _sys),
  engine1Hours('Engine 1 Hours', 'Eng 1', Dimension.duration, group: Group.systems),
  engine2Hours('Engine 2 Hours', 'Eng 2', Dimension.duration, group: Group.systems),
  engine1FuelRate('Engine 1 Fuel Rate', 'Eng 1', Dimension.flowRate, group: Group.systems),
  engine2FuelRate('Engine 2 Fuel Rate', 'Eng 2', Dimension.flowRate, group: Group.systems),
  fuelLevel('Fuel 1 Level', 'Fuel 1', Dimension.percentage, group: Group.systems),
  fuel2Level('Fuel 2 Level', 'Fuel 2', Dimension.percentage, group: Group.systems),
  gpsPosition('GPS position', 'GPS', Dimension.position, group: Group.navigation),
  gpsHdop('GPS HDOP', 'HDOP', Dimension.depth, group: Group.navigation),
  heading('Heading', 'Heading', Dimension.bearing),
  // Sometimes a network message can only generate headings in magnetic so use
  // this property. All data elements work with a true heading internally hence
  // no sources provide this mag heading property.
  headingMag('Mag Heading', 'Mag Hdg', Dimension.bearing, sources: {}),
  localTime('Local datetime', 'Local', Dimension.time, sources: {Source.local}),
  pitch('Pitch angle', 'Pitch', Dimension.angle),
  pressure('Air pressure', 'Pressure', Dimension.pressure, group: Group.environment),
  rateOfTurn('Rate of turn', 'ROT', Dimension.angularRate),
  relativeHumidity('Relative Humidity', 'RH', Dimension.percentage, group: Group.environment),
  roll('Roll angle', 'Roll', Dimension.angle),
  rudderAngle('Rudder angle', 'Rudder', Dimension.lateralAngle),
  speedOverGround('Speed over ground', 'SOG', Dimension.speed),
  speedThroughWater('Speed through water', 'STW', Dimension.speed),
  trimPort('Trim tab - Port', 'Trim P', Dimension.percentage, group: Group.systems),
  trimStarboard('Trim tab - Stbd', 'Trim S', Dimension.percentage, group: Group.systems),
  trueWindAngle('True wind angle', 'TWA', Dimension.lateralAngle, group: Group.environment),
  trueWindDirection('True wind direction', 'TWD', Dimension.bearing, group: Group.environment),
  trueWindSpeed('True wind speed', 'TWS', Dimension.speed, group: Group.environment),
  utcTime('UTC datetime', 'UTC', Dimension.time, sources: {Source.local, Source.network}),
  variation('Magnetic variation', 'MagVar', Dimension.angle, group: Group.navigation),
  vhfChannel('VHF channel', 'VHF', Dimension.integer, group: Group.systems),
  vmgWind('Speed to/from wind', 'VMG Wind', Dimension.speed, sources: {}),
  vmgWaypoint('Speed to waypoint', 'VMG Wpt', Dimension.speed, sources: {}),
  water1Level('Fresh Water 1 Level', 'Water 1', Dimension.percentage, group: Group.systems),
  waterTemperature('Water temperature', 'Water', Dimension.temperature, group: Group.environment),
  water2Level('Fresh Water 2 Level', 'Water 2', Dimension.percentage, group: Group.systems),
  waypointBearing('Bearing to waypoint', 'Wpt Brg', Dimension.bearing, group: Group.navigation),
  waypointRange('Range to waypoint', 'Wpt Rng', Dimension.distance, group: Group.navigation),
  waypointTime('Time to waypoint', 'Wpt Time', Dimension.duration, group: Group.navigation),
  yaw('Yaw angle', 'Yaw', Dimension.angle);

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

  /// The unqualified name of this literal in its enum, e.g. "speedOverGround".
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
  // Derived data is configurable by the user.
  derived('Derived data'),
  // Computer data is similar to derived but defined statically and in
  // a different namespace to avoid user collisions.
  computed('Computed data');

  final String longName;
  final bool selectable;

  const Source(this.longName, {this.selectable = true});

  /// Returns a source from its unqualified name.
  static Source? fromString(String? name) {
    return Source.values.asNameMap()[name];
  }

  /// Returns true if elements within the source use groups.
  bool usesGrouping() {
    return this == Source.network;
  }
}

/// The NMEA standards that network data may be received in.
enum NetworkStandard {
  nmea0183('NMEA0183'),
  nmea2000('NMEA2000');

  /// A short name suitable for display.
  final String shortName;

  const NetworkStandard(this.shortName);
}

/// A data element source and optionally a group for sources that use grouping.
class SourceAndGroup {
  final Source source;
  final Group? group;

  SourceAndGroup(this.source, this.group);

  @override
  bool operator ==(Object other) =>
      other is SourceAndGroup && source == other.source && group == other.group;

  @override
  int get hashCode => Object.hash(source, group);

  String get text => source.longName + ((group == null) ? "" : " - ${group!.longName}");

  /// Returns the set of all selectable sources and their groups.
  static Set<SourceAndGroup> set() {
    final Set<SourceAndGroup> ret = {};
    for (final source in Source.values.where((source) => source.selectable)) {
      if (source.usesGrouping()) {
        ret.addAll(Group.values.map((group) => SourceAndGroup(source, group)));
      } else {
        ret.add(SourceAndGroup(source, null));
      }
    }
    return ret;
  }

  /// Returns the SourceAndGroup in the supplied set or null if not found.
  static SourceAndGroup? lookupInSet(Set<SourceAndGroup> set, Source? source, Group? group) {
    if (source == null) return null;
    return set.lookup(SourceAndGroup(source, group));
  }
}

/// The various types of dimension used across data elements.
enum Dimension {
  angle(type: SingleValue<double>, nativeUnits: 'degrees', derivationFriendly: true),
  angularRate(type: SingleValue<double>, nativeUnits: 'degrees/sec'),
  bearing(
    type: AugmentedBearing,
    inputType: SingleValue<double>,
    nativeUnits: 'degrees true',
    minValue: AugmentedBearing(0.0, 0.0),
    maxValue: AugmentedBearing(359.9, 0.0),
  ),
  crossTrackError(type: SingleValue<double>, nativeUnits: 'meters'),
  current(type: SingleValue<double>, nativeUnits: 'amps', derivationFriendly: true),
  distance(
    type: SingleValue<double>,
    nativeUnits: 'meters',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  depth(type: SingleValue<double>, nativeUnits: 'meters', derivationFriendly: true),
  duration(type: SingleValue<double>, nativeUnits: 'seconds', minValue: SingleValue(0.0)),
  flowRate(
    type: SingleValue<double>,
    nativeUnits: 'liters/hour',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  integer(type: SingleValue<int>, nativeUnits: 'N/A'),
  lateralAngle(
    type: SingleValue<double>,
    nativeUnits: 'degrees',
    derivationFriendly: true,
    minValue: SingleValue(-179.0),
    maxValue: SingleValue(179.0),
  ),
  percentage(
    type: SingleValue<double>,
    nativeUnits: 'N/A',
    minValue: SingleValue(0.0),
    maxValue: SingleValue(100.0),
  ),
  position(type: DoubleValue<double>, nativeUnits: 'lat/long degrees'),
  pressure(
    type: SingleValue<double>,
    nativeUnits: 'pascals',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  rotationalSpeed(
    type: SingleValue<double>,
    nativeUnits: 'rpm',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  speed(
    type: SingleValue<double>,
    nativeUnits: 'meters/sec',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  temperature(
    type: SingleValue<double>,
    nativeUnits: 'degrees celcius',
    minValue: SingleValue(-273.15),
  ),
  time(type: SingleValue<DateTime>, nativeUnits: 'datetime'),
  voltage(
    type: SingleValue<double>,
    nativeUnits: 'volts',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  ),
  volume(
    type: SingleValue<double>,
    nativeUnits: 'liters',
    derivationFriendly: true,
    minValue: SingleValue(0.0),
  );

  final Type storageType;
  // TODO: I do have doubts about whether the dimension should be coupled into the implementation
  // of the data element like this. The alternative would be to delay the type check on a bound
  // value from on creation to when its passed to the DataElement.
  final Type inputType;
  final String nativeUnits;
  final bool derivationFriendly;

  final Value? minValue;
  final Value? maxValue;

  const Dimension({
    required Type type,
    required this.nativeUnits,
    Type? inputType,
    this.minValue,
    this.maxValue,
    this.derivationFriendly = false,
  }) : storageType = type,
       inputType = inputType ?? type;

  /// Returns a derivation operation from its unqualified name.
  static Dimension? fromString(String? name) {
    return Dimension.values.asNameMap()[name];
  }
}

/// The various sources types of data cell that can be defined.
enum CellType {
  current('Current Value'),
  average('Average Value'),
  minimum('Minimum Value', 'Min'),
  maximum('Maximum Value', 'Max'),
  history('History Graph');

  final String longName;

  /// A prefix applied to the element name in cells of this type, if any.
  final String? prefix;

  const CellType(this.longName, [this.prefix]);

  /// Returns true if this cell type displays a statistic over a StatsInterval.
  bool get usesStats => this == average || this == minimum || this == maximum;

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
  sixHours('6 hours', '6hr', Duration(minutes: 3), 120, Duration(hours: 2), 'HH:mm'),
  twelveHours('12 hours', '12hr', Duration(minutes: 6), 120, Duration(hours: 3), 'HH:mm'),
  twentyFourHours('24 hours', '24hr', Duration(minutes: 15), 96, Duration(hours: 6), 'HH:mm'),
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
  fiveSec('5 seconds', '5s', Duration(seconds: 5)),
  fifteenSec('15 seconds', '15s', Duration(seconds: 15)),
  oneMin('1 minute', '1m', Duration(minutes: 1)),
  fiveMin('5 minutes', '5m', Duration(minutes: 5));

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

  /// Returns the short name for a cell of the supplied type showing this interval for a property.
  String shortCellName(DataElement element, CellType type) {
    final prefix = type.prefix == null ? '' : '${type.prefix} ';
    return '$prefix${element.shortName} ($short)';
  }
}
