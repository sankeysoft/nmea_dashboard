// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/values.dart';

const double _floatTolerance = 0.0001;

class ValueMatches extends Matcher {
  ValueMatches(Value? expected) : _expected = expected;

  final Value? _expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item == null && _expected == null) {
      return true;
    } else if (item.runtimeType != _expected.runtimeType) {
      return false;
    } else if (_expected is SingleValue<double>) {
      final e = _expected; // Using type implied by type check.
      final a = item as SingleValue<double>;
      return ((a.data - e.data).abs() < _floatTolerance);
    } else if (_expected is SingleValue<DateTime>) {
      final e = _expected; // Using type implied by type check.
      final a = item as SingleValue<DateTime>;
      return (a.data == e.data);
    } else if (_expected is DoubleValue<double>) {
      final e = _expected; // Using type implied by type check.
      final a = item as DoubleValue<double>;
      return ((a.first - e.first).abs() < _floatTolerance &&
          (a.second - e.second).abs() < _floatTolerance);
    } else if (_expected is AugmentedBearing) {
      final e = _expected; // Using type implied by type check.
      final a = item as AugmentedBearing;
      if ((a.bearing - e.bearing).abs() > _floatTolerance) {
        return false;
      }
      if (a.variation == null && e.variation == null) {
        return true;
      }
      return (a.variation != null &&
          e.variation != null &&
          (a.variation! - e.variation!).abs() < _floatTolerance);
    } else {
      throw UnimplementedError(
          'No matcher for value type: ${_expected.runtimeType}');
    }
  }

  @override
  Description describe(Description description) {
    return description.add('Value matches ${_expected.runtimeType}:$_expected');
  }
}

class ValueListMatches extends Matcher {
  ValueListMatches(List<Value?> expected) : _expected = expected;

  final List<Value?> _expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final actual = item as List<Value?>;
    if (actual.length != _expected.length) {
      return false;
    }
    for (int i = 0; i < _expected.length; i++) {
      if (!ValueMatches(_expected[i]).matches(actual[i], matchState)) {
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    final formatted = _expected.map((e) => '  ${e.runtimeType}:$e');
    return description.add('Value list matches [\n${formatted.join("\n")}\n]');
  }
}

class BoundValueListMatches extends Matcher {
  BoundValueListMatches(List<BoundValue> expected) : _expected = expected;

  final List<BoundValue> _expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final actual = item as List<BoundValue>;
    if (actual.length != _expected.length) {
      return false;
    }
    for (int i = 0; i < _expected.length; i++) {
      final e = _expected[i];
      final a = actual[i];
      if (a.source != e.source ||
          a.property != e.property ||
          a.tier != e.tier) {
        return false;
      }
      if (!ValueMatches(e.value).matches(a.value, matchState)) {
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    final formatted = _expected.map((e) => '  ${e.runtimeType}:$e');
    return description
        .add('BoundValue list matches [\n${formatted.join("\n")}\n]');
  }
}
