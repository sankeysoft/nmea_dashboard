// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

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

/// A DataElement whose value is derived from some other value.
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
