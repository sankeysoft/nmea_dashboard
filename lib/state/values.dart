// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'common.dart';

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
