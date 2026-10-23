// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/values.dart';

import 'utils.dart';

void main() {
  test('All dimensions should be serializable', () {
    final testValues = [
      SingleValue<double>(123.0),
      SingleValue<int>(456),
      DoubleValue<double>(-23.4, 45.6),
      SingleValue<DateTime>(DateTime(2026, 4, 24, 1, 2, 3)),
      AugmentedBearing(90.0, 5.0),
    ];
    final knownTypes = testValues.map((e) => e.runtimeType);

    // Verify this test will cover all the types used in all dimensions.
    for (final dim in Dimension.values) {
      expect(knownTypes, contains(dim.storageType));
    }

    // Serialize is the only abstract method so verify its been implemented.
    for (final val in testValues) {
      expect(val.serialize(), isNotEmpty);
    }
  });

  test('SingleValue should serialize and deserialize.', () {
    final original = SingleValue<double>(123.0);
    expect(original.toString(), '123.0');
    var serialized = original.serialize();
    expect(serialized, '123.0000');
    expect(SingleValue.deserialize(serialized), ValueMatches(original));

    expect(SingleValue.deserialize('sfleij'), null);
    expect(SingleValue.deserialize('1.234/3'), null);
  });

  test('DoubleValue should serialize and deserialize.', () {
    final original = DoubleValue<double>(123.0, 456.0);
    expect(original.toString(), '123.0/456.0');
    var serialized = original.serialize();
    expect(serialized, '123.0000/456.0000');
    expect(DoubleValue.deserialize(serialized), ValueMatches(original));

    expect(DoubleValue.deserialize('sfleij'), null);
    expect(DoubleValue.deserialize('1.234'), null);
    expect(DoubleValue.deserialize('1/2/3'), null);
    expect(DoubleValue.deserialize('1.0/null'), null);
  });

  test('AugmentedBearing with variation should serialize and deserialize.', () {
    final original = AugmentedBearing(123.0, 10.0);
    expect(original.toString(), '(Brg=123.0 Var=10.0)');
    var serialized = original.serialize();
    expect(serialized, '123.0000/10.0000');
    expect(AugmentedBearing.deserialize(serialized), ValueMatches(original));

    expect(DoubleValue.deserialize('sfleij'), null);
    expect(DoubleValue.deserialize('1.234'), null);
    expect(DoubleValue.deserialize('1/2/3'), null);
    expect(DoubleValue.deserialize('ext/2.9'), null);
  });

  test('AugmentedBearing without variation should serialize and deserialize.', () {
    final original = AugmentedBearing(321.0, null);
    expect(original.toString(), '(Brg=321.0 Var=null)');
    var serialized = original.serialize();
    expect(serialized, '321.0000/null');
    expect(AugmentedBearing.deserialize(serialized), ValueMatches(original));
  });

  test('NumericAccumulator should give correct results.', () {
    final acc = NumericAccumulator();
    expect(acc.mean(), null);
    acc.add(2.0);
    expect(acc.mean(), 2.0);
    expect(acc.mean(), 2.0);
    acc.clear();
    expect(acc.mean(), null);
    acc.add(10.0);
    acc.add(11.0);
    acc.add(12.0);
    expect(acc.mean(), 11.0);
    acc.removeFirst();
    expect(acc.mean(), 11.5);
    acc.removeFirst();
    expect(acc.mean(), 12.0);
    acc.removeFirst();
    expect(acc.mean(), null);
    acc.removeFirst();
    expect(acc.mean(), null);
  });

  test('NumericAccumulator should track min and max.', () {
    final acc = NumericAccumulator();
    expect(acc.min(), null);
    expect(acc.max(), null);
    for (final v in [5.0, 3.0, 8.0, 3.0, 6.0, 1.0, 8.0]) {
      acc.add(v);
    }
    expect(acc.min(), 1.0);
    expect(acc.max(), 8.0);
    // Remaining after each removal, checking repeated values are handled.
    final expected = [
      (1.0, 8.0), // 3, 8, 3, 6, 1, 8
      (1.0, 8.0), // 8, 3, 6, 1, 8
      (1.0, 8.0), // 3, 6, 1, 8
      (1.0, 8.0), // 6, 1, 8
      (1.0, 8.0), // 1, 8
      (8.0, 8.0), // 8
    ];
    for (final (min, max) in expected) {
      acc.removeFirst();
      expect(acc.min(), min);
      expect(acc.max(), max);
    }
    acc.removeFirst();
    expect(acc.min(), null);
    expect(acc.max(), null);
    acc.add(4.0);
    acc.add(2.0);
    acc.clear();
    expect(acc.min(), null);
    expect(acc.max(), null);
    acc.add(7.0);
    expect(acc.min(), 7.0);
    expect(acc.max(), 7.0);
  });

  test('NumericAccumulator min and max should follow a sliding window.', () {
    final acc = NumericAccumulator();
    acc.add(9.0);
    acc.add(2.0);
    acc.add(5.0);
    expect((acc.min(), acc.max()), (2.0, 9.0));
    acc.removeFirst();
    expect((acc.min(), acc.max()), (2.0, 5.0));
    acc.add(4.0);
    acc.removeFirst();
    expect((acc.min(), acc.max()), (4.0, 5.0));
    acc.add(7.0);
    expect((acc.min(), acc.max()), (4.0, 7.0));
  });

  test('NumericAccumulator min and max should handle a repeated value.', () {
    final acc = NumericAccumulator();
    for (var i = 0; i < 3; i++) {
      acc.add(4.0);
    }
    expect((acc.min(), acc.max()), (4.0, 4.0));
    acc.removeFirst();
    expect((acc.min(), acc.max()), (4.0, 4.0));
    acc.removeFirst();
    expect((acc.min(), acc.max()), (4.0, 4.0));
    acc.removeFirst();
    expect((acc.min(), acc.max()), (null, null));
  });

  test('NumericAccumulator min and max should handle repeats of the extremes.', () {
    final acc = NumericAccumulator();
    for (final v in [1.0, 1.0, 9.0, 9.0, 5.0, 1.0, 9.0, 5.0]) {
      acc.add(v);
    }
    // Remaining after each removal. The extremes should only change once every copy has gone.
    final expected = [
      (1.0, 9.0), // 1, 9, 9, 5, 1, 9, 5
      (1.0, 9.0), // 9, 9, 5, 1, 9, 5
      (1.0, 9.0), // 9, 5, 1, 9, 5
      (1.0, 9.0), // 5, 1, 9, 5
      (1.0, 9.0), // 1, 9, 5
      (5.0, 9.0), // 9, 5
      (5.0, 5.0), // 5
    ];
    for (final (min, max) in expected) {
      acc.removeFirst();
      expect((acc.min(), acc.max()), (min, max));
    }
    acc.removeFirst();
    expect((acc.min(), acc.max()), (null, null));
  });

  test('SingleValueAccumulator should give correct min and max.', () {
    final acc = ValueAccumulator.forType(SingleValue<double>);
    expect(acc.min(), null);
    expect(acc.max(), null);
    acc.add(SingleValue(10.0));
    acc.add(SingleValue(30.0));
    acc.add(SingleValue(20.0));
    expect(acc.min(), ValueMatches(SingleValue(10.0)));
    expect(acc.max(), ValueMatches(SingleValue(30.0)));
    acc.removeFirst();
    expect(acc.min(), ValueMatches(SingleValue(20.0)));
    expect(acc.max(), ValueMatches(SingleValue(30.0)));
    acc.clear();
    acc.add(SingleValue(15.0));
    acc.add(SingleValue(15.0));
    expect(acc.min(), ValueMatches(SingleValue(15.0)));
    expect(acc.max(), ValueMatches(SingleValue(15.0)));
    acc.removeFirst();
    expect(acc.min(), ValueMatches(SingleValue(15.0)));
    expect(acc.max(), ValueMatches(SingleValue(15.0)));
    acc.removeFirst();
    expect(acc.min(), null);
    expect(acc.max(), null);
  });

  test('AugmentedBearingAccumulator min/max should handle wraparound and use last variation', () {
    final acc = ValueAccumulator.forType(AugmentedBearing);
    expect(acc.min(), null);
    expect(acc.max(), null);
    acc.add(AugmentedBearing(350.0, 5.0));
    acc.add(AugmentedBearing(10.0, 6.0));
    acc.add(AugmentedBearing(180.0, null));
    // Stored as 350, 370, 540.
    expect(acc.min(), ValueMatches(AugmentedBearing(350.0, 6.0)));
    expect(acc.max(), ValueMatches(AugmentedBearing(180.0, 6.0)));
    acc.removeFirst();
    expect(acc.min(), ValueMatches(AugmentedBearing(10.0, 6.0)));
    expect(acc.max(), ValueMatches(AugmentedBearing(180.0, 6.0)));
    acc.removeFirst();
    expect(acc.min(), ValueMatches(AugmentedBearing(180.0, null)));
    expect(acc.max(), ValueMatches(AugmentedBearing(180.0, null)));
    acc.clear();
    expect(acc.min(), null);
    expect(acc.max(), null);
    acc.add(AugmentedBearing(90.0, 2.0));
    acc.add(AugmentedBearing(90.0, 3.0));
    expect(acc.min(), ValueMatches(AugmentedBearing(90.0, 3.0)));
    expect(acc.max(), ValueMatches(AugmentedBearing(90.0, 3.0)));
    acc.removeFirst();
    expect(acc.min(), ValueMatches(AugmentedBearing(90.0, 3.0)));
    expect(acc.max(), ValueMatches(AugmentedBearing(90.0, 3.0)));
    acc.removeFirst();
    expect(acc.min(), null);
    expect(acc.max(), null);
  });

  test('SingleValueAccumulator should give correct results.', () {
    final acc = ValueAccumulator.forType(SingleValue<double>);
    expect(acc.mean(), null);
    expect(acc.last(), null);
    acc.add(SingleValue(2.0));
    expect(acc.mean(), ValueMatches(SingleValue(2.0)));
    expect(acc.last(), ValueMatches(SingleValue(2.0)));
    acc.clear();
    expect(acc.mean(), null);
    acc.add(SingleValue(10.0));
    acc.add(SingleValue(11.0));
    acc.add(SingleValue(12.0));
    expect(acc.mean(), ValueMatches(SingleValue(11.0)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(SingleValue(11.5)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(SingleValue(12.0)));
    acc.removeFirst();
    expect(acc.mean(), null);
    acc.removeFirst();
    expect(acc.mean(), null);
  });

  test('AugmentedBearingAccumulator should give correct results.', () {
    final acc = ValueAccumulator.forType(AugmentedBearing);
    expect(acc.mean(), null);
    acc.add(AugmentedBearing(200.0, 5.0));
    expect(acc.mean(), ValueMatches(AugmentedBearing(200.0, 5.0)));
    expect(acc.mean(), ValueMatches(AugmentedBearing(200.0, 5.0)));
    acc.clear();
    acc.add(AugmentedBearing(100.0, null));
    acc.add(AugmentedBearing(150.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing(125.0, null)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing(150.0, null)));
    acc.removeFirst();
    expect(acc.mean(), null);
    acc.clear();
    acc.add(AugmentedBearing(200.0, 5.0));
    acc.add(AugmentedBearing(210.0, null));
    acc.add(AugmentedBearing(220.0, 10.0));
    acc.add(AugmentedBearing(230.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing(215.0, 7.5)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing(220.0, 10.0)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing(225.0, 10.0)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing(230.0, null)));
    acc.removeFirst();
    expect(acc.mean(), null);
  });

  test('AugmentedBearingAccumulator should handle wraparound in both directions', () {
    final acc = ValueAccumulator.forType(AugmentedBearing);
    // Increasing through north.
    for (final b in [358.0, 359.0, 0.0, 1.0]) {
      acc.add(AugmentedBearing(b, null));
    }
    expect(acc.mean(), ValueMatches(AugmentedBearing(359.5, null)));
    expect(acc.min(), ValueMatches(AugmentedBearing(358.0, null)));
    expect(acc.max(), ValueMatches(AugmentedBearing(1.0, null)));
    expect(acc.last(), ValueMatches(AugmentedBearing(1.0, null)));
    acc.clear();
    // Decreasing through north.
    for (final b in [2.0, 1.0, 359.0, 356.0]) {
      acc.add(AugmentedBearing(b, null));
    }
    expect(acc.mean(), ValueMatches(AugmentedBearing(359.5, null)));
    expect(acc.min(), ValueMatches(AugmentedBearing(356.0, null)));
    expect(acc.max(), ValueMatches(AugmentedBearing(2.0, null)));
    expect(acc.last(), ValueMatches(AugmentedBearing(356.0, null)));
    acc.clear();
    // Crossing south should not be treated as a wrap.
    acc.add(AugmentedBearing(170.0, null));
    acc.add(AugmentedBearing(190.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing(180.0, null)));
    expect(acc.min(), ValueMatches(AugmentedBearing(170.0, null)));
    expect(acc.max(), ValueMatches(AugmentedBearing(190.0, null)));
  });

  test('AugmentedBearingAccumulator should restart unwrapping once emptied', () {
    final acc = ValueAccumulator.forType(AugmentedBearing);
    acc.add(AugmentedBearing(350.0, null));
    acc.add(AugmentedBearing(10.0, null));
    acc.removeFirst();
    acc.removeFirst();
    acc.add(AugmentedBearing(20.0, null));
    acc.add(AugmentedBearing(30.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing(25.0, null)));
    expect(acc.min(), ValueMatches(AugmentedBearing(20.0, null)));
    expect(acc.max(), ValueMatches(AugmentedBearing(30.0, null)));
  });

  test('BoundValue toString should include source, tier, property, and value', () {
    final bv = BoundValue(Source.network, Property.rateOfTurn, SingleValue(2.5), tier: 2);
    expect(bv.toString(), 'S=Source.network(2), P=Property.rateOfTurn, V=2.5');
  });

  test('Value.deserialize should dispatch to the correct type', () {
    expect(Value.deserialize<SingleValue<double>>('1.2345'), ValueMatches(SingleValue(1.2345)));
    expect(
      Value.deserialize<DoubleValue<double>>('1.0000/2.0000'),
      ValueMatches(DoubleValue(1.0, 2.0)),
    );
    expect(
      Value.deserialize<AugmentedBearing>('90.0000/5.0000'),
      ValueMatches(AugmentedBearing(90.0, 5.0)),
    );
    expect(() => Value.deserialize<SingleValue<String>>('x'), throwsA(isA<InvalidTypeException>()));
  });

  test('SingleValue serialize for non-double type should call toString', () {
    final dt = DateTime.utc(2024, 1, 15);
    expect(SingleValue<DateTime>(dt).serialize(), dt.toString());
  });

  test('DoubleValue serialize for non-double type should use slash separator', () {
    expect(DoubleValue<String>('hello', 'world').serialize(), 'hello/world');
  });

  test('ValueAccumulator.forType should throw for unknown type', () {
    expect(
      () => ValueAccumulator.forType(DoubleValue<double>),
      throwsA(isA<InvalidTypeException>()),
    );
  });

  test('AugmentedBearingAccumulator last should return the most recent value', () {
    final acc = ValueAccumulator.forType(AugmentedBearing) as AugmentedBearingAccumulator;
    expect(acc.last(), null);
    acc.add(AugmentedBearing(100.0, 5.0));
    expect(acc.last(), ValueMatches(AugmentedBearing(100.0, 5.0)));
    acc.add(AugmentedBearing(110.0, 6.0));
    expect(acc.last(), ValueMatches(AugmentedBearing(110.0, 6.0)));
    acc.add(AugmentedBearing(120.0, null));
    expect(acc.last(), ValueMatches(AugmentedBearing(120.0, 6.0)));
  });

  test('BoundValue should throw on property type mismatch', () {
    expect(
      () => BoundValue<SingleValue<double>>(Source.network, Property.gpsPosition, SingleValue(1.0)),
      throwsA(isA<InvalidTypeException>()),
    );
  });
}
