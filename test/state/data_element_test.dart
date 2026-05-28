// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

final _staleness = Staleness(const Duration(milliseconds: 100));
const _testSource = Source.local;
const _testProperty = Property.dewPoint;

BoundValue<SingleValue<T>> _boundSingleValue<T>(T value, {int tier = 1}) {
  return BoundValue(_testSource, _testProperty, SingleValue<T>(value), tier: tier);
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
      Source.local,
      Property.dewPoint,
      _staleness,
    );
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
    final element = ConsistentDataElement(_testSource, _testProperty, _staleness);

    expect(element.updateValue(_boundSingleValue(1.0)), true);
    expect(element.value, ValueMatches(SingleValue(1.0)));
    await Future.delayed(_staleness.duration * 2);
    expect(element.value, null);
  });

  test('data element should notify listeners, except for fast updates', () async {
    // Use a staleness high enough to not trigger by our freshness delays.
    final element = ConsistentDataElement(
      _testSource,
      _testProperty,
      Staleness(const Duration(seconds: 3)),
    );
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
    final element = ConsistentDataElement(_testSource, _testProperty, _staleness);

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
    final element = ConsistentDataElement(_testSource, _testProperty, _staleness);

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
      _testSource,
      Property.variation,
      _staleness,
    );
    final bearing = BearingDataElement(_testSource, variation, Property.heading, _staleness);

    // If variation is null, we will reject mag inputs.
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundMagHeading(45)), false);
    expect(bearing.value, null);

    // Once variation is set we accept them.
    variation.updateValue(_boundVariation(10.0));
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundMagHeading(45)), true);
    expect(bearing.value, ValueMatches(AugmentedBearing(35.0, 10.0)));
    expect(bearing.updateValue(_boundMagHeading(1)), true);
    expect(bearing.value, ValueMatches(AugmentedBearing(351.0, 10.0)));
  });

  test('bearing data element should accept true inputs', () {
    final variation = ConsistentDataElement<SingleValue<double>>(
      _testSource,
      Property.variation,
      _staleness,
    );
    final bearing = BearingDataElement(_testSource, variation, Property.heading, _staleness);

    // If variation is null, we accept true inputs.
    expect(bearing.value, null);
    expect(bearing.updateValue(_boundTrueHeading(45)), true);
    expect(bearing.value, ValueMatches(AugmentedBearing(45.0, null)));

    // Once variation is set we still accept them.
    variation.updateValue(_boundVariation(10.0));
    expect(bearing.updateValue(_boundTrueHeading(55)), true);
    expect(bearing.value, ValueMatches(AugmentedBearing(55.0, 10.0)));
  });

  test('data element long and short names come from property', () {
    final element = ConsistentDataElement<SingleValue<double>>(
      Source.local,
      Property.dewPoint,
      _staleness,
    );
    expect(element.shortName, Property.dewPoint.shortName);
    expect(element.longName, Property.dewPoint.longName);
  });

  test('data element should throw when updated with wrong property', () {
    final element = ConsistentDataElement<SingleValue<double>>(
      _testSource,
      _testProperty,
      _staleness,
    );
    expect(
      () => element.updateValue(BoundValue(_testSource, Property.airTemperature, SingleValue(1.0))),
      throwsA(isA<InvalidTypeException>()),
    );
  });

  test('newForProperty element should update value and add to history and stats', () {
    final element =
        ConsistentDataElement.newForProperty(_testSource, _testProperty, _staleness)
            as SingleValueDoubleConsistentDataElement;
    expect(element.updateValue(BoundValue(_testSource, _testProperty, SingleValue(5.0))), true);
    expect(element.value, ValueMatches(SingleValue(5.0)));
    expect(element.history(HistoryInterval.fifteenMin), isNotNull);
    expect(element.history(HistoryInterval.twoHours), isNotNull);
    expect(element.stats(StatsInterval.fifteenSec), isNotNull);
    expect(element.stats(StatsInterval.oneMin), isNotNull);
  });

  test('WithHistory elements should accumulate.', () {
    // TODO: If we get a DataSet initializable in a test, would be better to
    // run this test on that.
    final staleness = Staleness(const Duration(seconds: 1));
    final variation = ConsistentDataElement<SingleValue<double>>(
      Source.network,
      Property.variation,
      staleness,
    );

    for (final property in Property.values) {
      final DataElement element;
      if (property.dimension == Dimension.bearing) {
        element = BearingDataElement(Source.network, variation, property, staleness);
      } else {
        element = ConsistentDataElement.newForProperty(Source.network, property, staleness);
      }
      if (element is WithHistory) {
        ValueAccumulator.forType(element.storedType);
      }
    }
  });

  group('WithAlarms', () {
    late AlarmManager manager;
    late SingleValueDoubleConsistentDataElement element;

    setUp(() {
      manager = AlarmManager();
      element =
          ConsistentDataElement.newForProperty(
                Source.network,
                Property.depthWithOffset,
                Staleness(const Duration(seconds: 10)),
              )
              as SingleValueDoubleConsistentDataElement;
      element.registerAlarmManager(manager);
    });

    Alarm depthAlarm({
      double? min,
      double? max,
      AlarmLevel level = AlarmLevel.caution,
      StatsInterval? averagingInterval,
    }) {
      return Alarm(
        source: Source.network,
        elementName: "test depth",
        property: Property.depthWithOffset,
        averagingInterval: averagingInterval,
        level: level,
        formatter: numericFormattersFor(Dimension.depth)['feet']!,
        min: min,
        max: max,
      );
    }

    BoundValue<SingleValue<double>> depthValueFt(double feet) {
      return BoundValue(Source.network, Property.depthWithOffset, SingleValue(feet / metersToFeet));
    }

    test('replaceAlarms silently drops alarm on property mismatch', () {
      final wrongProperty = Alarm(
        source: Source.network,
        elementName: "test TWS",
        property: Property.trueWindSpeed,
        level: AlarmLevel.caution,
        formatter: numericFormattersFor(Dimension.speed)['knots']!,
        min: 10.0,
      );
      element.replaceAlarms({wrongProperty});
      element.updateValue(depthValueFt(5.0));
      expect(manager.activeAlarms, isEmpty);
    });

    test('replaceAlarms silently drops alarm on formatter type mismatch', () {
      // Property matches the element but the formatter's valueType
      // (AugmentedBearing) does not match the element's stored type.
      final wrongType = Alarm(
        source: Source.network,
        elementName: "test depth",
        property: Property.depthWithOffset,
        level: AlarmLevel.caution,
        formatter: numericFormattersFor(Dimension.bearing)['true']!,
        min: 10.0,
      );
      element.replaceAlarms({wrongType});
      element.updateValue(depthValueFt(5.0));
      expect(manager.activeAlarms, isEmpty);
    });

    test('current-value alarm sets and clears as value crosses bounds', () {
      final alarm = depthAlarm(min: 10.0, max: 100.0);
      element.replaceAlarms({alarm});
      expect(manager.activeAlarms, isEmpty);
      expect(element.alarmState.level, isNull);

      element.updateValue(depthValueFt(5.0));
      expect(manager.activeAlarms.contains(alarm), isTrue);
      expect(element.alarmState.level, AlarmLevel.caution);

      element.updateValue(depthValueFt(50.0));
      expect(manager.activeAlarms.contains(alarm), isFalse);
      expect(element.alarmState.level, isNull);
    });

    test('replaceAlarms with empty set removes all alarms from manager and resets alarmState', () {
      final alarm = depthAlarm(min: 10.0, max: 100.0);
      element.replaceAlarms({alarm});
      element.updateValue(depthValueFt(5.0));
      expect(manager.activeAlarms, isNotEmpty);
      expect(element.alarmState.level, isNotNull);

      element.replaceAlarms({});
      expect(manager.activeAlarms, isEmpty);
      expect(element.alarmState.level, isNull);
    });

    test('alarmState reflects highest level among multiple active alarms', () {
      final caution = depthAlarm(min: 10.0, level: AlarmLevel.caution);
      final warning = depthAlarm(min: 5.0, level: AlarmLevel.warning);
      element.replaceAlarms({caution, warning});

      element.updateValue(depthValueFt(3.0));
      expect(manager.activeAlarms.contains(caution), isTrue);
      expect(manager.activeAlarms.contains(warning), isTrue);
      expect(element.alarmState.level, AlarmLevel.warning);

      element.updateValue(depthValueFt(7.0));
      expect(manager.activeAlarms.contains(caution), isTrue);
      expect(manager.activeAlarms.contains(warning), isFalse);
      expect(element.alarmState.level, AlarmLevel.caution);
    });

    test('replaceAlarms with same alarm keeps stats listener active', () {
      // Verifies that re-supplying an existing alarm via replaceAlarms preserves the stats
      // subscription so the alarm still fires on averaging-interval updates.
      Alarm makeAlarm() => depthAlarm(max: 100.0, averagingInterval: StatsInterval.fifteenSec);
      final alarm = makeAlarm();

      element.replaceAlarms({alarm});
      element.replaceAlarms({alarm});

      element.updateValue(depthValueFt(200.0));
      expect(manager.activeAlarms, hasLength(1));
      expect(element.alarmState.level, AlarmLevel.caution);
    });
  });
}
