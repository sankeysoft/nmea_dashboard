// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

final _staleness = Staleness(const Duration(milliseconds: 100));
const _testName = 'Test element';
const _testSource = Source.local;
const _testProperty = Property.dewPoint;

BoundValue<SingleValue<T>> _boundSingleValue<T>(T value, {int tier = 1}) {
  return BoundValue(_testSource, _testProperty, SingleValue<T>(value),
      tier: tier);
}

BoundValue<SingleValue<double>> _boundVariation(double value) {
  return BoundValue(_testSource, Property.variation, SingleValue(value));
}

BoundValue<SingleValue<double>> _boundTrueHeading(double value) {
  return BoundValue(_testSource, Property.heading, SingleValue(value));
}

BoundValue<SingleValue<double>> _boundMagHeading(double value) {
  return BoundValue(_testSource, Property.headingMag, SingleValue(value));
}

void main() {
  test('data element should inialize with correct values', () {
    final element = ConsistentDataElement<SingleValue<double>>(
        Source.local, Property.dewPoint, _staleness);
    expect(element.id, 'local_dewPoint');
    expect(element.property, Property.dewPoint);
    expect(element.storedType, SingleValue<double>);
    expect(element.inputType, SingleValue<double>);
    expect(element.staleness, _staleness);
    expect(element.stalenessTimer, null);
    expect(element.value, null);
    expect(element.tier, null);
  });

  test('data element should accept values and remove when stale', () async {
    final element =
        ConsistentDataElement(_testSource, _testProperty, _staleness);

    expect(element.updateValue(_boundSingleValue(1.0)), true);
    expect(element.value, ValueMatches(SingleValue(1.0)));
    await Future.delayed(_staleness.duration * 2);
    expect(element.value, null);
  });

  test('data element should notify listeners, except for fast updates',
      () async {
    // Use a staleness high enough to not trigger by our freshness delays.
    final element = ConsistentDataElement(
        _testSource, _testProperty, Staleness(const Duration(seconds: 3)));
    int eventCount = 0;
    element.addListener(() => eventCount++);

    element.updateValue(_boundSingleValue(1.0));
    expect(element.value, ValueMatches(SingleValue(1.0)));
    expect(eventCount, 1);

    await Future.delayed(const Duration(milliseconds: 300));
    element.updateValue(_boundSingleValue(2.0));
    expect(element.value, ValueMatches(SingleValue(2.0)));
    expect(eventCount, 1);

    // Wait so the sum of the two delays is over freshnessLimit
    await Future.delayed(const Duration(milliseconds: 600));
    element.updateValue(_boundSingleValue(3.0));
    expect(eventCount, 2);
  });

  test('data element should reject lower tier values if not stale', () {
    final element =
        ConsistentDataElement(_testSource, _testProperty, _staleness);

    element.updateValue(_boundSingleValue(1.0, tier: 3));
    expect(element.value, ValueMatches(SingleValue(1.0)));
    element.updateValue(_boundSingleValue(2.0, tier: 2));
    expect(element.value, ValueMatches(SingleValue(2.0)));
    element.updateValue(_boundSingleValue(3.0, tier: 2));
    expect(element.value, ValueMatches(SingleValue(3.0)));
    element.updateValue(_boundSingleValue(4.0, tier: 1));
    expect(element.value, ValueMatches(SingleValue(4.0)));
    element.updateValue(_boundSingleValue(5.0, tier: 2));
    expect(element.value, ValueMatches(SingleValue(4.0)));
  });

  test('data element should accept lower tier values if stale', () async {
    final element =
        ConsistentDataElement(_testSource, _testProperty, _staleness);

    element.updateValue(_boundSingleValue(1.0, tier: 1));
    expect(element.value, ValueMatches(SingleValue(1.0)));
    element.updateValue(_boundSingleValue(2.0, tier: 2));
    expect(element.value, ValueMatches(SingleValue(1.0)));
    expect(element.tier, 1);

    await Future.delayed(_staleness.duration * 2);
    expect(element.value, null);
    element.updateValue(_boundSingleValue(3.0, tier: 2));
    expect(element.value, ValueMatches(SingleValue(3.0)));
    expect(element.tier, 2);
  });

  test('bearing data element should accept magnetic inputs', () {
    final variation = ConsistentDataElement<SingleValue<double>>(
        _testSource, Property.variation, _staleness);
    final bearing = BearingDataElement(
        _testSource, variation, Property.heading, _staleness);

    // If variation is null, we will reject mag inputs.
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundMagHeading(45)), false);
    expect(bearing.value, null);

    // Once variation is set we accept them.
    variation.updateValue(_boundVariation(10.0));
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundMagHeading(45)), true);
    expect(bearing.value,
        ValueMatches(AugmentedBearing(SingleValue(35.0), SingleValue(10.0))));
    expect(bearing.updateValue(_boundMagHeading(1)), true);
    expect(bearing.value,
        ValueMatches(AugmentedBearing(SingleValue(351.0), SingleValue(10.0))));
  });

  test('bearing data element should accept true inputs', () {
    final variation = ConsistentDataElement<SingleValue<double>>(
        _testSource, Property.variation, _staleness);
    final bearing = BearingDataElement(
        _testSource, variation, Property.heading, _staleness);

    // If variation is null, we accept true inputs.
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundTrueHeading(45)), true);
    expect(
        bearing.value, ValueMatches(AugmentedBearing(SingleValue(45.0), null)));

    // Once variation is set we still accept them.
    variation.updateValue(_boundVariation(10.0));
    expect(bearing.updateValue(_boundTrueHeading(55)), true);
    expect(bearing.value,
        ValueMatches(AugmentedBearing(SingleValue(55.0), SingleValue(10.0))));
  });

  test('derived data element accepts updates', () async {
    final source = ConsistentDataElement<SingleValue<double>>(
        _testSource, Property.depthUncalibrated, _staleness);
    final formatter =
        formattersFor(Dimension.depth)['feet'] as ConvertingFormatter;
    final derived =
        DerivedDataElement(_testName, source, formatter, Operation.add, 100);

    int eventCount = 0;
    derived.addListener(() => eventCount++);

    // We should echo updated on the source and pass through notification.
    expect(derived.value, null);
    source.updateValue(
        BoundValue(_testSource, Property.depthUncalibrated, SingleValue(5)));
    expect(derived.value,
        ValueMatches(SingleValue((5 * metersToFeet + 100) / metersToFeet)));
    expect(eventCount, 1);

    // And go stale when our souce does.
    await Future.delayed(_staleness.duration * 2);
    expect(source.value, null);
    expect(derived.value, null);
    expect(eventCount, 2);
  });

  test('WithHistory elements should accumulate.', () {
    // TODO: If we get a DataSet inintializable in a test, would be better to
    // run this test on that.
    final staleness = Staleness(const Duration(seconds: 1));
    final variation = ConsistentDataElement<SingleValue<double>>(
        Source.network, Property.variation, staleness);

    for (final property in Property.values) {
      final DataElement element;
      if (property.dimension == Dimension.bearing) {
        element =
            BearingDataElement(Source.network, variation, property, staleness);
      } else {
        element = ConsistentDataElement.newForProperty(
            Source.network, property, staleness);
      }
      if (element is WithHistory) {
        ValueAccumulator.forType(element.storedType);
      }
    }
  });
}
