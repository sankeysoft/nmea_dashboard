// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/values.dart';

import '../utils.dart';

void main() {
  test('All dimensions should be serializable', () {
    final testValues = [
      SingleValue<double>(123.0),
      SingleValue<int>(456),
      DoubleValue<double>(-23.4, 45.6),
      SingleValue<DateTime>(DateTime(2026, 4, 24, 1, 2, 3)),
    ];
    final knownTypes = testValues.map((e) => e.runtimeType);

    // Verify this test will cover all the types used in all dimensions.
    for (final dim in Dimension.values) {
      expect(knownTypes, contains(dim.type));
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
    final original = AugmentedBearing.fromNumbers(123.0, 10.0);
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
    final original = AugmentedBearing.fromNumbers(321.0, null);
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
    acc.add(AugmentedBearing.fromNumbers(200.0, 5.0));
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(200.0, 5.0)));
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(200.0, 5.0)));
    acc.clear();
    acc.add(AugmentedBearing.fromNumbers(100.0, null));
    acc.add(AugmentedBearing.fromNumbers(150.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(125.0, null)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(150.0, null)));
    acc.removeFirst();
    expect(acc.mean(), null);
    acc.clear();
    acc.add(AugmentedBearing.fromNumbers(200.0, 5.0));
    acc.add(AugmentedBearing.fromNumbers(210.0, null));
    acc.add(AugmentedBearing.fromNumbers(220.0, 10.0));
    acc.add(AugmentedBearing.fromNumbers(230.0, null));
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(215.0, 7.5)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(220.0, 10.0)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(225.0, 10.0)));
    acc.removeFirst();
    expect(acc.mean(), ValueMatches(AugmentedBearing.fromNumbers(230.0, null)));
    acc.removeFirst();
    expect(acc.mean(), null);
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
      ValueMatches(AugmentedBearing.fromNumbers(90.0, 5.0)),
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
    acc.add(AugmentedBearing.fromNumbers(100.0, 5.0));
    expect(acc.last(), ValueMatches(AugmentedBearing.fromNumbers(100.0, 5.0)));
    acc.add(AugmentedBearing.fromNumbers(110.0, 6.0));
    expect(acc.last(), ValueMatches(AugmentedBearing.fromNumbers(110.0, 6.0)));
    acc.add(AugmentedBearing.fromNumbers(120.0, null));
    expect(acc.last(), ValueMatches(AugmentedBearing.fromNumbers(120.0, 6.0)));
  });

  test('BoundValue should throw on property type mismatch', () {
    expect(
      () => BoundValue<SingleValue<double>>(Source.network, Property.gpsPosition, SingleValue(1.0)),
      throwsA(isA<InvalidTypeException>()),
    );
  });
}
