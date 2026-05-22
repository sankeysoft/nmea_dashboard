// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';

// The different levels of alarm, driving the different ways they are announced.
enum AlarmType { caution, warning }

/// A function used to lookup property by source and element name.
typedef PropertyFinderFunction = Property? Function(Source source, String? element);

/// A representation of an alarm on a particular property, capable of testing whether values
/// should trigger the alarm.
class Alarm {
  final Source source;
  final Property property;
  final StatsInterval? averagingInterval;
  final AlarmType type;
  final NumericFormatter formatter;
  final double? min;
  final double? max;
  // TODO(alarms): Add sound asset

  Alarm(
    this.source,
    this.property,
    this.averagingInterval,
    this.type,
    this.formatter,
    this.min,
    this.max,
  );

  /// Creates a new alarm from the supplied spec, using the supplied function to find the property.
  /// Throws a format exception if the spec is not valid.
  static Alarm fromSpec(AlarmSpec spec, PropertyFinderFunction finder) {
    final source = Source.fromString(spec.source);
    if (source == null) {
      throw FormatException("Invalid alarm source: ${spec.source}");
    }
    final property = finder(source, spec.element);
    if (property == null) {
      throw FormatException("Invalid alarm element: ${spec.element}");
    }
    final formatter = numericFormattersFor(property.dimension)[spec.format];
    if (formatter == null) {
      throw FormatException("Invalid alarm format: ${spec.format}");
    }
    final type = AlarmType.values.asNameMap()[spec.type];
    if (type == null) {
      throw FormatException("Invalid alarm type: ${spec.type}");
    }
    final averagingInterval = StatsInterval.fromString(spec.averagingInterval);
    if (spec.averagingInterval != null && averagingInterval == null) {
      throw FormatException("Invalid averaging interval: ${spec.averagingInterval}");
    }
    if (spec.min == null && spec.max == null) {
      throw FormatException("Alarm does not include bound: $property");
    }
    if (property.dimension == Dimension.bearing && (spec.min == null || spec.max == null)) {
      throw FormatException("Bearing alarm does not include both bounds: $property");
    }
    return Alarm(source, property, averagingInterval, type, formatter, spec.min, spec.max);
  }

  /// Returns true if the supplied value is outside this alarms configured bounds.
  bool isTriggered(Value value) {
    double? num = formatter.toNumber(value);
    // Shouldn't be possible to get a failure if the data element is for the correct property,
    // but report an alarm anyway to be conservative.
    if (num == null) {
      return true;
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
    if (averagingInterval != null) {
      buffer
        ..write(averagingInterval!.short)
        ..write(" ");
    }
    buffer
      ..write(property.shortName)
      ..write(" ");
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
}
