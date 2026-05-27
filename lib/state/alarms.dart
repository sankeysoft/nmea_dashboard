// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';

// The different levels of alarm, driving the different ways they are announced.
enum AlarmLevel implements Comparable<AlarmLevel> {
  caution,
  warning;

  @override
  int compareTo(AlarmLevel other) {
    return index.compareTo(other.index);
  }
}

extension AlarmLevelComparison on AlarmLevel {
  bool operator <(AlarmLevel other) => compareTo(other) < 0;
  bool operator <=(AlarmLevel other) => compareTo(other) <= 0;
  bool operator >(AlarmLevel other) => compareTo(other) > 0;
  bool operator >=(AlarmLevel other) => compareTo(other) >= 0;
}

/// The maximum current level of a collection of zero or more alarms, with change notification.
class AlarmState with ChangeNotifier {
  AlarmLevel? _level;

  void set(AlarmLevel? level) {
    bool changed = level != _level;
    _level = level;
    if (changed) {
      notifyListeners();
    }
  }

  AlarmLevel? get level => _level;
}

/// A function used to lookup data element by source and element name.
typedef ElementFinderFunction = DataElement? Function(Source source, String? element);

/// A representation of an alarm on a particular property, capable of testing whether values
/// should trigger the alarm.
class Alarm implements Comparable<Alarm> {
  final Source source;
  final Property property;
  final String elementName;
  final StatsInterval? averagingInterval;
  final AlarmLevel level;
  final NumericFormatter formatter;
  final double? min;
  final double? max;
  // TODO(alarms): Add sound asset

  Alarm({
    required this.source,
    required this.elementName,
    required this.property,
    required this.level,
    required this.formatter,
    this.averagingInterval,
    this.min,
    this.max,
  });

  /// Creates a new alarm from the supplied spec, using the supplied function to find the property.
  /// Throws a format exception if the spec is not valid.
  static Alarm fromSpec(AlarmSpec spec, ElementFinderFunction finder) {
    final source = Source.fromString(spec.source);
    if (source == null) {
      throw FormatException("Invalid alarm source: ${spec.source}");
    }
    final element = finder(source, spec.element);
    if (element == null) {
      throw FormatException("Invalid alarm element: ${spec.element}");
    }
    final formatter = numericFormattersFor(element.property.dimension)[spec.format];
    if (formatter == null) {
      throw FormatException("Invalid alarm format: ${spec.format}");
    }
    final level = AlarmLevel.values.asNameMap()[spec.type];
    if (level == null) {
      throw FormatException("Invalid alarm type: ${spec.type}");
    }
    final averagingInterval = StatsInterval.fromString(spec.averagingInterval);
    if (spec.averagingInterval != null && averagingInterval == null) {
      throw FormatException("Invalid averaging interval: ${spec.averagingInterval}");
    }
    if (spec.min == null && spec.max == null) {
      throw FormatException("Alarm does not include bound: ${spec.element}");
    }
    if (element.property.dimension == Dimension.bearing && (spec.min == null || spec.max == null)) {
      throw FormatException("Bearing alarm does not include both bounds: ${spec.element}");
    }
    return Alarm(
      source: source,
      elementName: element.shortName,
      property: element.property,
      averagingInterval: averagingInterval,
      level: level,
      formatter: formatter,
      min: spec.min,
      max: spec.max,
    );
  }

  /// Returns true if the supplied value is outside this alarm's configured bounds. Returns null
  /// if the value cannot be converted to a number (e.g. bearing to mag without variation).
  bool? isTriggered(Value value) {
    double? num = formatter.toNumber(value);
    // Shouldn't be possible to get a failure if the data element is for the correct property,
    // but report an alarm anyway to be conservative.
    if (num == null) {
      return null;
    }
    if (property.dimension == Dimension.bearing) {
      if (max! > min!) {
        // The valid-range-doesn't-pass-through-000 case.
        return num < min! || num > max!;
      } else {
        // The valid-range-does-pass-through-000 case.
        return num > max! && num < min!;
      }
    } else {
      if (min != null && num < min!) {
        return true;
      } else if (max != null && num > max!) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer
      ..write(elementName)
      ..write(" ");
    if (averagingInterval != null) {
      buffer
        ..write("(")
        ..write(averagingInterval!.short)
        ..write(") ");
    }
    if (min != null && max != null) {
      buffer
        ..write("not ")
        ..write(formatter.formatNumber(min!))
        ..write("-")
        ..write(formatter.formatNumber(max!));
    } else if (min != null) {
      buffer
        ..write("<")
        ..write(formatter.formatNumber(min!));
    } else if (max != null) {
      buffer
        ..write(">")
        ..write(formatter.formatNumber(max!));
    }
    if (property.dimension != Dimension.bearing && formatter.units != null) {
      // Nitty special case because bearings strings already contain M/T.
      buffer
        ..write(" ")
        ..write(formatter.units);
    }
    return buffer.toString();
  }

  @override
  int compareTo(Alarm other) {
    // Warnings take priority over cautions
    if (level == AlarmLevel.warning && other.level == AlarmLevel.caution) {
      return 1;
    } else if (level == AlarmLevel.caution && other.level == AlarmLevel.warning) {
      return -1;
    }
    // Alarms based on a longer average are usually high confidence so take priority.
    if (averagingInterval != other.averagingInterval) {
      if (averagingInterval != null && other.averagingInterval == null) {
        return 1;
      } else if (averagingInterval == null && other.averagingInterval != null) {
        return -1;
      }
      return averagingInterval!.duration.inSeconds - other.averagingInterval!.duration.inSeconds;
    }
    // Order somewhat arbitrarily by property, source, and format name
    if (property != other.property) {
      return property.longName.compareTo(other.property.longName);
    }
    if (source != other.source) {
      return source.longName.compareTo(other.source.longName);
    }
    if (formatter.longName != other.formatter.longName) {
      return formatter.longName.compareTo(other.formatter.longName);
    }
    // Then highest maximum or lowest minimum.
    if (max != other.max) {
      return (max ?? 0.0).compareTo(other.max ?? 0.0);
    }
    if (min != other.min) {
      return -(min ?? 0.0).compareTo(other.min ?? 0.0);
    }
    return 0;
  }
}

/// An ordered set of alarms, with change notication.
class AlarmSet with ChangeNotifier {
  final LinkedHashSet<Alarm> _set = LinkedHashSet<Alarm>();

  /// Returns an iterator over the alarms.
  Iterable<Alarm> get alarms => _set;

  /// Adds an alarm to the set, returning true iff the alarm was not previously present.
  bool add(Alarm alarm) {
    if (_set.contains(alarm)) {
      return false;
    }
    _set.add(alarm);
    notifyListeners();
    return true;
  }

  /// Removes an alarm from the set, returning true iff the alarm was previously present.
  bool remove(Alarm alarm) {
    if (!_set.contains(alarm)) {
      return false;
    }
    _set.remove(alarm);
    notifyListeners();
    return true;
  }

  /// Remove all alarms, returning true iff any alarms were present.
  bool clear() {
    if (_set.isEmpty) {
      return false;
    }
    _set.clear();
    notifyListeners();
    return true;
  }

  /// Returns true if the set contains the specified alarm.
  bool contains(Alarm alarm) {
    return _set.contains(alarm);
  }

  /// Returns the number of alarms in the set.
  int get length => _set.length;

  /// Returns true if the set contains no alarms.
  bool get isEmpty => _set.isEmpty;

  /// Returns true if the set contains at least one alarm.
  bool get isNotEmpty => _set.isNotEmpty;
}

/// A manager to set and access the complete set of all active alarms across all properties.
///
/// DataElements ask the manager to set and clear the alarms they maintain, and this class has
/// no inherant knowledge of alarms outside of these calls.
class AlarmManager {
  /// This class's logger.
  static final _log = Logger('AlarmManager');

  /// The set of currently active alarms, ordered by decreasing age.
  final AlarmSet activeAlarms = AlarmSet();

  /// The set of not-yet acknowledged warnings, ordered by decreasing age.
  final AlarmSet unacknowledgedWarnings = AlarmSet();

  /// Marks an alarm as active, returning true iff the alarm was not previously active.
  bool setAlarm(Alarm alarm) {
    final changed = activeAlarms.add(alarm);
    if (changed) {
      // TODO(alarms): name not property
      _log.info("Setting ${alarm.level.name} on ${alarm.property.shortName}");
      if (alarm.level == AlarmLevel.warning) {
        unacknowledgedWarnings.add(alarm);
      }
    }
    return changed;
  }

  /// Marks an alarm as inactive, returning true iff the alarm was previously active.
  bool clearAlarm(Alarm alarm) {
    final changed = activeAlarms.remove(alarm);
    if (changed) {
      // TODO(alarms): name not property
      _log.info("Clearing ${alarm.level.name} on ${alarm.property.shortName}");
      unacknowledgedWarnings.remove(alarm);
    }
    return changed;
  }

  /// Clears all active alarms, for example before recreating from settings.
  void clearAllAlarms() {
    if (activeAlarms.isNotEmpty) {
      _log.info("Clearing ${activeAlarms.length} active alarms");
    }
    activeAlarms.clear();
    unacknowledgedWarnings.clear();
  }

  /// Acknowledges all previously unacknowledged warnings.
  void acknowledgeWarnings() {
    if (unacknowledgedWarnings.isNotEmpty) {
      _log.info("Acknowledging ${unacknowledgedWarnings.length} warnings");
      unacknowledgedWarnings.clear();
    }
  }
}
