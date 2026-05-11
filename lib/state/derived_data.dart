// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';
import 'dart:math' as math;

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/values.dart';

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

/// A DataElement whose value is derived from some other value via a user-specified operation
/// and operand.
class DerivedDataElement extends DataElement<SingleValue<double>, SingleValue<double>>
    with WithHistory, WithStats {
  final String _name;
  final DataElement<SingleValue<double>, Value> _sourceElement;
  final ConvertingFormatter _formatter;
  final Operation _operation;
  final double _operand;

  DerivedDataElement(
    this._name,
    this._sourceElement,
    this._formatter,
    this._operation,
    this._operand,
  ) : super(
        '${_name}_from_${_sourceElement.id}',
        _sourceElement.property,
        /* No staleness, source will notify on invalid */ null,
      ) {
    // Update self when the sourceElement sends a notification.
    _sourceElement.addListener(() {
      final sourceValue = _sourceElement.value;
      final sourceConverted = _formatter.toNumber(sourceValue);
      // Convert the source value to the target units and check its not null
      if (sourceConverted == null) {
        invalidateValue();
      } else {
        // Apply the operation then convert back to the native units for its
        // dimension.
        final derivedConverted = _operation.apply(sourceConverted, _operand);
        updateValue(
          BoundValue(
            Source.derived,
            _sourceElement.property,
            _formatter.fromNumber(derivedConverted),
          ),
        );
      }
    });
  }

  @override
  bool updateValue(final BoundValue<SingleValue<double>> newValue) {
    final accepted = super.updateValue(newValue);
    if (accepted && value != null) {
      addStatsValue(value!);
      addHistoryValue(value!);
    }
    return accepted;
  }

  @override
  SingleValue<double> convertValue(SingleValue<double> newValue) {
    return newValue;
  }

  @override
  String get shortName => _name;

  @override
  String get longName => _name;
}

/// A DataElement for VMG to wind, calculated from SOG and TWA.
/// TODO: If we get more of these consider moving the calculations into a different file and
/// defining a common base class.
class VmgWindCalculatedDataElement extends SingleValueDoubleConsistentDataElement {
  final DataElement<SingleValue<double>, Value> _sog;
  final DataElement<SingleValue<double>, Value> _twa;

  VmgWindCalculatedDataElement(Map<String, DataElement<Value, Value>> network)
    : _sog = network[Property.speedOverGround.name]! as DataElement<SingleValue<double>, Value>,
      _twa = network[Property.trueWindAngle.name]! as DataElement<SingleValue<double>, Value>,
      super(
        Source.computed,
        Property.vmgWind,
        /* No staleness, source will notify on invalid */ null,
      ) {
    // Update self when either sourceElement sends a notification.
    for (final element in [_sog, _twa]) {
      element.addListener(() {
        final value = _calculateValue();
        if (value == null) {
          invalidateValue();
        } else {
          updateValue(BoundValue(Source.derived, Property.vmgWind, value));
        }
      });
    }
  }

  SingleValue<double>? _calculateValue() {
    final sog = _sog.value?.data;
    final twaDeg = _twa.value?.data;
    if (sog == null || twaDeg == null) {
      return null;
    }
    final twaRad = twaDeg * math.pi / 180.0;
    // Always display VMG for wind as positive; we assume if you're headed downwind then
    // your objective is to head downwind.
    return SingleValue<double>((sog * cos(twaRad)).abs());
  }
}

/// A DataElement for VMG to waypoint, calculated from SOG, COG, and waypoint bearing.
class VmgWptCalculatedDataElement extends SingleValueDoubleConsistentDataElement {
  final DataElement<SingleValue<double>, Value> _sog;
  final BearingDataElement _cog;
  final BearingDataElement _wptBearing;

  VmgWptCalculatedDataElement(Map<String, DataElement<Value, Value>> network)
    : _sog = network[Property.speedOverGround.name]! as DataElement<SingleValue<double>, Value>,
      _cog = network[Property.courseOverGround.name]! as BearingDataElement,
      _wptBearing = network[Property.waypointBearing.name]! as BearingDataElement,
      super(
        Source.computed,
        Property.vmgWaypoint,
        /* No staleness, source will notify on invalid */ null,
      ) {
    // Update self when either sourceElement sends a notification.
    for (final element in [_sog, _cog, _wptBearing]) {
      element.addListener(() {
        final value = _calculateValue();
        if (value == null) {
          invalidateValue();
        } else {
          updateValue(BoundValue(Source.computed, Property.vmgWaypoint, value));
        }
      });
    }
  }

  SingleValue<double>? _calculateValue() {
    final sog = _sog.value?.data;
    final cog = _cog.value?.bearing;
    final wptBearing = _wptBearing.value?.bearing;
    if (sog == null || cog == null || wptBearing == null) {
      return null;
    }
    var relAngle = (cog - wptBearing) % 360.0;
    if (relAngle > 180.0) {
      relAngle = 360.0 - relAngle;
    }
    return SingleValue<double>(sog * cos(relAngle * math.pi / 180.0));
  }
}
