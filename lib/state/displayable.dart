// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/widgets.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/common.dart';

import 'data_element.dart';
import 'formatting.dart';

/// A single peice of displayable information, capable of potentially
/// displaying a value string along with heading and unit strings.
abstract class Displayable with ChangeNotifier {
  /// The spec that was used to create this displayable
  final KeyedDataCellSpec spec;

  Displayable(this.spec);

  /// Returns the main string to display.
  String? get value;

  /// Returns the heading to display.
  String? get heading => null;

  /// Returns the units to display.
  String? get units => null;

  /// Returns the fraction of the available height the
  /// displayable should consume.
  double get heightFraction => 1.0;
}

/// An element to display a spec that could not be resolved.
class NotFoundDisplay extends Displayable {
  NotFoundDisplay(super.spec);

  @override
  String? get value => 'Not Found';
}

/// An element to display a spec that has not yet been set.
class UnsetDisplay extends Displayable {
  UnsetDisplay(super.spec);

  @override
  String? get value => 'Hold here to select\ndata to display';
}

/// A element that formats the current value of a DataElement
class DataElementDisplay extends Displayable {
  /// The data element we exist to format.
  final DataElement data;

  /// The formatter we apply to values.
  final Formatter formatter;

  DataElementDisplay(this.data, this.formatter, super.spec) {
    if (data.storedType != formatter.valueType) {
      throw InvalidTypeException('Cannot create DataElementDisplay, ${formatter.valueType} incompatible with ${data.storedType}');
    }
    data.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    data.removeListener(() {
      notifyListeners();
    });
    super.dispose();
  }

  @override
  String? get value {
    final value = data.value;
    if (value == null) {
      return formatter.invalid;
    } else {
      return formatter.format(value);
    }
  }

  @override
  String? get heading {
    if (spec.name != null) {
      return spec.name;
    } else {
      return data.shortName;
    }
  }

  @override
  String? get units => formatter.units;

  @override
  double get heightFraction => formatter.heightFraction;
}
