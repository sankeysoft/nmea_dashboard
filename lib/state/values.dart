// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:collection';

import 'package:nmea_dashboard/state/common.dart';

/// A bound value is a single instance of the input data for some property in some
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
    _verifyInputType(property, V);
  }

  @override
  String toString() {
    return "S=$source($tier), P=$property, V=$value";
  }
}

/// A value is a single instance of the data that may be associated with some
/// property.
abstract class Value {
  const Value();

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

  const SingleValue(this.data);

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

  const AugmentedBearing(this.bearing, this.variation);

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
      return AugmentedBearing(bearing, null);
    }
    final variation = double.tryParse(components[1]);
    if (variation == null) {
      return null;
    }
    return AugmentedBearing(bearing, variation);
  }

  @override
  String toString() {
    return "(Brg=$bearing Var=$variation)";
  }

  @override
  String serialize() {
    final bearingStr = bearing.toStringAsFixed(serializationDp);
    final variationStr = variation == null ? 'null' : variation!.toStringAsFixed(serializationDp);
    return '$bearingStr/$variationStr';
  }
}

/// A class to accumulate values of some type into an average, minimum, and maximum.
abstract class ValueAccumulator<V extends Value> {
  /// Returns the average of the values added into this accumulator.
  V? mean();

  /// Returns the minimum of the values added into this accumulator.
  V? min();

  /// Returns the maximum of the values added into this accumulator.
  V? max();

  /// Returns the most recent value added into this accumulator.
  V? last();

  /// Adds a new value into this accumulator.
  void add(V value);

  /// Removes the first value added to this accumulator.
  void removeFirst();

  /// Clears state to begin additional accumulation.
  void clear();

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
  void add(SingleValue<double> value) {
    num.add(value.data);
  }

  @override
  void removeFirst() {
    num.removeFirst();
  }

  @override
  SingleValue<double>? mean() {
    final d = num.mean();
    return d == null ? null : SingleValue(d);
  }

  @override
  SingleValue<double>? min() {
    final d = num.min();
    return d == null ? null : SingleValue(d);
  }

  @override
  SingleValue<double>? max() {
    final d = num.max();
    return d == null ? null : SingleValue(d);
  }

  @override
  SingleValue<double>? last() {
    final d = num.last();
    return d == null ? null : SingleValue(d);
  }

  @override
  void clear() {
    num.clear();
  }
}

class AugmentedBearingAccumulator extends ValueAccumulator<AugmentedBearing> {
  final NumericAccumulator bearing;
  final NumericAccumulator variation;
  final Queue<bool> variationPresent;

  AugmentedBearingAccumulator()
    : bearing = NumericAccumulator(),
      variation = NumericAccumulator(),
      variationPresent = Queue();

  // Currently mean, min, and max are calculated naively on the bearings,
  // ignoring wraparound at 360 degrees.
  // TODO: Consider improving this.

  @override
  AugmentedBearing? mean() {
    final b = bearing.mean();
    final v = variation.mean();
    return b == null ? null : AugmentedBearing(b, v);
  }

  @override
  AugmentedBearing? min() {
    final b = bearing.min();
    return b == null ? null : AugmentedBearing(b, variation.last());
  }

  @override
  AugmentedBearing? max() {
    final b = bearing.max();
    return b == null ? null : AugmentedBearing(b, variation.last());
  }

  @override
  AugmentedBearing? last() {
    final b = bearing.last();
    // Note we deliberately use the last available variation, even if it isn't from the
    // most recent bearing.
    final v = variation.last();
    return b == null ? null : AugmentedBearing(b, v);
  }

  @override
  add(AugmentedBearing value) {
    bearing.add(value.bearing);
    if (value.variation != null) {
      variationPresent.add(true);
      variation.add(value.variation!);
    } else {
      variationPresent.add(false);
    }
  }

  @override
  void removeFirst() {
    bearing.removeFirst();
    if (variationPresent.removeFirst()) {
      variation.removeFirst();
    }
  }

  @override
  void clear() {
    bearing.clear();
    variation.clear();
    variationPresent.clear();
  }
}

/// A class to accumulate numeric values into an average, minimum, and maximum.
class NumericAccumulator {
  /// All values added into this accumulator.
  final Queue<double> _values;

  /// The sum of _values.
  double _total;

  /// Candidates for the minimum, in non-decreasing order with the current minimum first.
  final Queue<double> _minCandidates;

  /// Candidates for the maximum, in non-increasing order with the current maximum first.
  final Queue<double> _maxCandidates;

  NumericAccumulator()
    : _values = Queue(),
      _total = 0.0,
      _minCandidates = Queue(),
      _maxCandidates = Queue();

  /// Adds a new value into this accumulator.
  void add(double value) {
    _values.add(value);
    _total += value;
    // Earlier values that are beyond the new value can never again be the min or max.
    while (_minCandidates.isNotEmpty && _minCandidates.last > value) {
      _minCandidates.removeLast();
    }
    _minCandidates.add(value);
    while (_maxCandidates.isNotEmpty && _maxCandidates.last < value) {
      _maxCandidates.removeLast();
    }
    _maxCandidates.add(value);
  }

  /// Removes the first value added into this accumulator, if present.
  void removeFirst() {
    if (_values.isNotEmpty) {
      final value = _values.removeFirst();
      _total = _values.isEmpty ? 0.0 : _total - value;
      if (_minCandidates.first == value) {
        _minCandidates.removeFirst();
      }
      if (_maxCandidates.first == value) {
        _maxCandidates.removeFirst();
      }
    }
  }

  /// Returns the minimum of the values added into this accumulator.
  double? min() {
    return _minCandidates.isEmpty ? null : _minCandidates.first;
  }

  /// Returns the maximum of the values added into this accumulator.
  double? max() {
    return _maxCandidates.isEmpty ? null : _maxCandidates.first;
  }

  /// Returns the average of the values added into this accumulator.
  double? mean() {
    return _values.isEmpty ? null : _total / _values.length;
  }

  /// Returns the most recent value added into this accumulator.
  double? last() {
    return _values.isEmpty ? null : _values.last;
  }

  /// Clears all values;
  void clear() {
    _values.clear();
    _total = 0.0;
    _minCandidates.clear();
    _maxCandidates.clear();
  }
}

/// Verifies that the expected type of the supplied property matches
/// the supplied input type, throwing an exception if not.
Property _verifyInputType(Property property, Type input) {
  if (property.dimension.inputType != input) {
    throw InvalidTypeException(
      'Cannot bind $input to $property, expected ${property.dimension.inputType}',
    );
  }
  return property;
}
