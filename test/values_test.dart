// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/values.dart';

import 'utils.dart';

void main() {
  // TODO: A test that all property value types can be deserialized would be
  // nice but can think of a good way to do it since the deserialize is a
  // generic which must be specified at compile time, maybe statically define
  // types and then verify they cover everything in the property?

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
    expect(acc.getAndClear(), null);
    acc.add(2.0);
    expect(acc.getAndClear(), 2.0);
    acc.add(10.0);
    acc.add(11.0);
    acc.add(12.0);
    expect(acc.getAndClear(), 11.0);
    expect(acc.getAndClear(), null);
  });

  test('SingleValueAccumulator should give correct results.', () {
    final acc = ValueAccumulator.forType(SingleValue<double>);
    expect(acc.getAndClear(), null);
    acc.add(SingleValue(2.0));
    expect(acc.getAndClear(), ValueMatches(SingleValue(2.0)));
    acc.add(SingleValue(10.0));
    acc.add(SingleValue(11.0));
    acc.add(SingleValue(12.0));
    expect(acc.getAndClear(), ValueMatches(SingleValue(11.0)));
    expect(acc.getAndClear(), null);
  });

  test('AugmentedBearingAccumulator should give correct results.', () {
    final acc = ValueAccumulator.forType(AugmentedBearing);
    expect(acc.getAndClear(), null);
    acc.add(AugmentedBearing.fromNumbers(200.0, 5.0));
    expect(acc.getAndClear(), ValueMatches(AugmentedBearing.fromNumbers(200.0, 5.0)));
    acc.add(AugmentedBearing.fromNumbers(100.0, null));
    acc.add(AugmentedBearing.fromNumbers(150.0, null));
    expect(acc.getAndClear(), ValueMatches(AugmentedBearing.fromNumbers(125.0, null)));
    acc.add(AugmentedBearing.fromNumbers(200.0, 5.0));
    acc.add(AugmentedBearing.fromNumbers(210.0, 10.0));
    acc.add(AugmentedBearing.fromNumbers(220.0, null));
    expect(acc.getAndClear(), ValueMatches(AugmentedBearing.fromNumbers(210.0, 7.5)));
    expect(acc.getAndClear(), null);
  });
}
