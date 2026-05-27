// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

// Finder that maps (source, element name) to a DataElement by looking up the property by name.
DataElement? _elementByName(Source source, String? element) {
  if (element == null) return null;
  final property = Property.values.asNameMap()[element];
  if (property == null) return null;
  return ConsistentDataElement<SingleValue<double>>(source, property, null);
}

NumericFormatter _formatter(Dimension dimension, String name) {
  return numericFormattersFor(dimension)[name]!;
}

Alarm _testDepthAlarm({double? min, double? max, AlarmLevel level = AlarmLevel.caution}) {
  return Alarm(
    source: Source.network,
    elementName: Property.depthWithOffset.shortName,
    property: Property.depthWithOffset,
    level: level,
    formatter: _formatter(Dimension.depth, 'feet'),
    min: min,
    max: max,
  );
}

Alarm _testBearingAlarm({required double min, required double max}) {
  return Alarm(
    source: Source.network,
    elementName: Property.heading.shortName,
    property: Property.heading,
    level: AlarmLevel.caution,
    formatter: _formatter(Dimension.bearing, 'true'),
    min: min,
    max: max,
  );
}

void main() {
  group('AlarmLevel comparison', () {
    test('caution is less than warning', () {
      expect(AlarmLevel.caution < AlarmLevel.warning, isTrue);
      expect(AlarmLevel.caution <= AlarmLevel.warning, isTrue);
      expect(AlarmLevel.caution > AlarmLevel.warning, isFalse);
      expect(AlarmLevel.caution >= AlarmLevel.warning, isFalse);
    });

    test('warning is greater than caution', () {
      expect(AlarmLevel.warning > AlarmLevel.caution, isTrue);
      expect(AlarmLevel.warning >= AlarmLevel.caution, isTrue);
      expect(AlarmLevel.warning < AlarmLevel.caution, isFalse);
      expect(AlarmLevel.warning <= AlarmLevel.caution, isFalse);
    });

    test('equal values are <= and >= but not < or >', () {
      expect(AlarmLevel.caution <= AlarmLevel.caution, isTrue);
      expect(AlarmLevel.caution >= AlarmLevel.caution, isTrue);
      expect(AlarmLevel.caution < AlarmLevel.caution, isFalse);
      expect(AlarmLevel.caution > AlarmLevel.caution, isFalse);
    });
  });

  group('AlarmState', () {
    test('set updates level', () {
      final state = AlarmState();
      expect(state.level, isNull);
      state.set(AlarmLevel.caution);
      expect(state.level, AlarmLevel.caution);
    });

    test('set notifies listeners when level changes', () {
      final state = AlarmState();
      int count = 0;
      state.addListener(() => count++);
      state.set(AlarmLevel.caution);
      state.set(AlarmLevel.caution);
      expect(count, 1);
      state.set(AlarmLevel.warning);
      expect(count, 2);
    });

    test('set(null) clears a previously set level and notifies', () {
      final state = AlarmState();
      state.set(AlarmLevel.caution);
      int count = 0;
      state.addListener(() => count++);
      state.set(null);
      expect(state.level, isNull);
      expect(count, 1);
    });
  });

  group('Alarm.fromSpec valid', () {
    test('min-only spec creates alarm with null max', () {
      final spec = AlarmSpec('network', 'depthWithOffset', 'caution', 'feet', min: 10.0);
      final alarm = Alarm.fromSpec(spec, _elementByName);
      expect(alarm.source, Source.network);
      expect(alarm.property, Property.depthWithOffset);
      expect(alarm.level, AlarmLevel.caution);
      expect(alarm.min, 10.0);
      expect(alarm.max, isNull);
      expect(alarm.averagingInterval, isNull);
    });

    test('max-only spec creates alarm with null min', () {
      final spec = AlarmSpec('network', 'depthWithOffset', 'warning', 'feet', max: 100.0);
      final alarm = Alarm.fromSpec(spec, _elementByName);
      expect(alarm.level, AlarmLevel.warning);
      expect(alarm.min, isNull);
      expect(alarm.max, 100.0);
    });

    test('spec with both min and max creates alarm with both', () {
      final spec = AlarmSpec('network', 'trueWindSpeed', 'caution', 'knots', min: 5.0, max: 30.0);
      final alarm = Alarm.fromSpec(spec, _elementByName);
      expect(alarm.min, 5.0);
      expect(alarm.max, 30.0);
    });

    test('spec with averagingInterval is parsed to StatsInterval', () {
      final spec = AlarmSpec(
        'network',
        'depthWithOffset',
        'caution',
        'feet',
        averagingInterval: 'fiveMin',
        min: 10.0,
      );
      final alarm = Alarm.fromSpec(spec, _elementByName);
      expect(alarm.averagingInterval, StatsInterval.fiveMin);
    });

    test('bearing property with both bounds is accepted', () {
      final spec = AlarmSpec('network', 'heading', 'caution', 'true', min: 340.0, max: 20.0);
      final alarm = Alarm.fromSpec(spec, _elementByName);
      expect(alarm.property, Property.heading);
      expect(alarm.min, 340.0);
      expect(alarm.max, 020.0);
    });
  });

  group('Alarm.fromSpec invalid', () {
    test('throws on invalid source string', () {
      final spec = AlarmSpec('notASource', 'depthWithOffset', 'caution', 'feet', min: 10.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws when finder returns null', () {
      final spec = AlarmSpec('network', 'noSuchElement', 'caution', 'feet', min: 10.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws on format that is not valid for the dimension', () {
      final spec = AlarmSpec('network', 'depthWithOffset', 'caution', 'knots', min: 10.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws on invalid type string', () {
      final spec = AlarmSpec('network', 'depthWithOffset', 'urgent', 'feet', min: 10.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws on invalid averagingInterval string', () {
      final spec = AlarmSpec(
        'network',
        'depthWithOffset',
        'caution',
        'feet',
        averagingInterval: 'nope',
        min: 10.0,
      );
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws when neither min nor max is provided', () {
      final spec = AlarmSpec('network', 'depthWithOffset', 'caution', 'feet');
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws on bearing dimension with only min', () {
      final spec = AlarmSpec('network', 'heading', 'caution', 'true', min: 10.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });

    test('throws on bearing dimension with only max', () {
      final spec = AlarmSpec('network', 'heading', 'caution', 'true', max: 350.0);
      expect(() => Alarm.fromSpec(spec, _elementByName), throwsFormatException);
    });
  });

  group('Alarm.isTriggered numeric (depth in feet)', () {
    BoundValue<SingleValue<double>> feet(double feet) {
      return BoundValue(Source.network, Property.depthWithOffset, SingleValue(feet / metersToFeet));
    }

    test('value below min triggers', () {
      final alarm = _testDepthAlarm(min: 10.0, max: 100.0);
      expect(alarm.isTriggered(feet(5.0).value), isTrue);
    });

    test('value above max triggers', () {
      final alarm = _testDepthAlarm(min: 10.0, max: 100.0);
      expect(alarm.isTriggered(feet(150.0).value), isTrue);
    });

    test('value within range does not trigger', () {
      final alarm = _testDepthAlarm(min: 10.0, max: 100.0);
      expect(alarm.isTriggered(feet(50.0).value), isFalse);
    });

    test('min-only alarm: above triggers false, below triggers true', () {
      final alarm = _testDepthAlarm(min: 10.0);
      expect(alarm.isTriggered(feet(50.0).value), isFalse);
      expect(alarm.isTriggered(feet(5.0).value), isTrue);
    });

    test('max-only alarm: below triggers false, above triggers true', () {
      final alarm = _testDepthAlarm(max: 100.0);
      expect(alarm.isTriggered(feet(50.0).value), isFalse);
      expect(alarm.isTriggered(feet(150.0).value), isTrue);
    });
  });

  group('Alarm.isTriggered bearing', () {
    test('range that does not cross 0: value inside range does not trigger', () {
      final alarm = _testBearingAlarm(min: 10.0, max: 350.0);
      expect(alarm.isTriggered(const AugmentedBearing(180.0, 0.0)), isFalse);
    });

    test('range that does not cross 0: value below min triggers', () {
      final alarm = _testBearingAlarm(min: 10.0, max: 350.0);
      expect(alarm.isTriggered(const AugmentedBearing(5.0, 0.0)), isTrue);
    });

    test('range that does not cross 0: value above max triggers', () {
      final alarm = _testBearingAlarm(min: 10.0, max: 350.0);
      expect(alarm.isTriggered(const AugmentedBearing(355.0, 0.0)), isTrue);
    });

    test('range that crosses 0: values around 0 do not trigger', () {
      final alarm = _testBearingAlarm(min: 350.0, max: 10.0);
      expect(alarm.isTriggered(const AugmentedBearing(0.0, 0.0)), isFalse);
      expect(alarm.isTriggered(const AugmentedBearing(355.0, 0.0)), isFalse);
      expect(alarm.isTriggered(const AugmentedBearing(5.0, 0.0)), isFalse);
    });

    test('range that crosses 0: value in dead zone triggers', () {
      final alarm = _testBearingAlarm(min: 350.0, max: 10.0);
      expect(alarm.isTriggered(const AugmentedBearing(180.0, 0.0)), isTrue);
    });

    test('dont change state when when formatter.toNumber returns null', () {
      // The 'mag' formatter returns null when variation is null, so the alarm
      // should claim is it either set or clear.
      final alarm = Alarm(
        source: Source.network,
        elementName: Property.heading.shortName,
        property: Property.heading,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.bearing, 'mag'),
        min: 10.0,
        max: 350.0,
      );
      expect(alarm.isTriggered(const AugmentedBearing(180.0, null)), isNull);
    });
  });

  group('Alarm.toString', () {
    test('min only renders as <X with units', () {
      final alarm = _testDepthAlarm(min: 10.0);
      expect(alarm.toString(), 'Depth <10.0 ft');
    });

    test('max only renders as >X with units', () {
      final alarm = _testDepthAlarm(max: 100.0);
      expect(alarm.toString(), 'Depth >100.0 ft');
    });

    test('both bounds render as not X-Y with units', () {
      final alarm = _testDepthAlarm(min: 10.0, max: 100.0);
      expect(alarm.toString(), 'Depth not 10.0-100.0 ft');
    });

    test('averagingInterval is shown in parentheses after the element name', () {
      final alarm = Alarm(
        source: Source.network,
        elementName: Property.depthWithOffset.shortName,
        property: Property.depthWithOffset,
        averagingInterval: StatsInterval.fiveMin,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.depth, 'feet'),
        min: 10.0,
      );
      expect(alarm.toString(), 'Depth (5m) <10.0 ft');
    });

    test('bearing dimension omits trailing units', () {
      final alarm = _testBearingAlarm(min: 10.0, max: 350.0);
      // The bearing formatter already encodes 'T' in its formatted output,
      // so no extra units suffix should appear.
      final str = alarm.toString();
      expect(str.startsWith('Heading not '), isTrue);
      expect(str.endsWith('°T'), isFalse, reason: 'should not be suffixed: $str');
    });
  });

  group('Alarm.compareTo', () {
    test('warning ranks above caution regardless of other fields', () {
      final warning = _testDepthAlarm(min: 10.0, level: AlarmLevel.warning);
      final caution = _testDepthAlarm(min: 10.0, level: AlarmLevel.caution);
      expect(warning.compareTo(caution) > 0, isTrue);
      expect(caution.compareTo(warning) < 0, isTrue);
    });

    test('alarm with averagingInterval ranks above alarm without', () {
      final withAvg = Alarm(
        source: Source.network,
        elementName: Property.depthWithOffset.shortName,
        property: Property.depthWithOffset,
        averagingInterval: StatsInterval.oneMin,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.depth, 'feet'),
        min: 10.0,
      );
      final without = _testDepthAlarm(min: 10.0);
      expect(withAvg.compareTo(without) > 0, isTrue);
      expect(without.compareTo(withAvg) < 0, isTrue);
    });

    test('longer averaging duration ranks above shorter', () {
      Alarm make(StatsInterval interval) => Alarm(
        source: Source.network,
        elementName: Property.depthWithOffset.shortName,
        property: Property.depthWithOffset,
        averagingInterval: interval,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.depth, 'feet'),
        min: 10.0,
      );
      final shortAvg = make(StatsInterval.oneMin);
      final longAvg = make(StatsInterval.fiveMin);
      expect(longAvg.compareTo(shortAvg) > 0, isTrue);
      expect(shortAvg.compareTo(longAvg) < 0, isTrue);
    });

    test('equal level+interval ordered by property longName', () {
      // 'Depth' < 'True wind speed' alphabetically.
      final depth = _testDepthAlarm(min: 10.0);
      final tws = Alarm(
        source: Source.network,
        elementName: Property.trueWindSpeed.shortName,
        property: Property.trueWindSpeed,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.speed, 'knots'),
        min: 10.0,
      );
      expect(depth.compareTo(tws) < 0, isTrue);
      expect(tws.compareTo(depth) > 0, isTrue);
    });

    test('equal property ordered by source longName', () {
      // Use a property that exists on both network and local sources.
      // utcTime has both Source.local and Source.network as valid sources.
      // But utcTime is in Dimension.time which has no numeric formatters; instead
      // use a percentage property and construct alarms directly.
      final networkAlarm = Alarm(
        source: Source.network,
        elementName: Property.fuelLevel.shortName,
        property: Property.fuelLevel,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.percentage, 'percent'),
        min: 10.0,
      );
      final localAlarm = Alarm(
        source: Source.local,
        elementName: Property.fuelLevel.shortName,
        property: Property.fuelLevel,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.percentage, 'percent'),
        min: 10.0,
      );
      // 'Local device' < 'Network' alphabetically.
      expect(localAlarm.compareTo(networkAlarm) < 0, isTrue);
      expect(networkAlarm.compareTo(localAlarm) > 0, isTrue);
    });

    test('equal property+source ordered by formatter longName', () {
      // depth has formatters 'meters', 'feet', 'fathoms' with longNames matching the keys.
      // Alphabetical: 'fathoms' < 'feet' < 'meters'.
      Alarm make(String fmt) => Alarm(
        source: Source.network,
        elementName: Property.depthWithOffset.shortName,
        property: Property.depthWithOffset,
        level: AlarmLevel.caution,
        formatter: _formatter(Dimension.depth, fmt),
        min: 10.0,
      );
      final fathoms = make('fathoms');
      final feet = make('feet');
      expect(fathoms.compareTo(feet) < 0, isTrue);
      expect(feet.compareTo(fathoms) > 0, isTrue);
    });

    test('final tiebreak: higher max ranks higher', () {
      final lowMax = _testDepthAlarm(max: 50.0);
      final highMax = _testDepthAlarm(max: 100.0);
      expect(highMax.compareTo(lowMax) > 0, isTrue);
      expect(lowMax.compareTo(highMax) < 0, isTrue);
    });

    test('final tiebreak: lower min ranks higher when max equal', () {
      final lowMin = _testDepthAlarm(min: 5.0, max: 100.0);
      final highMin = _testDepthAlarm(min: 20.0, max: 100.0);
      expect(lowMin.compareTo(highMin) > 0, isTrue);
      expect(highMin.compareTo(lowMin) < 0, isTrue);
    });

    test('identical alarms compare equal', () {
      final a = _testDepthAlarm(min: 10.0, max: 100.0);
      final b = _testDepthAlarm(min: 10.0, max: 100.0);
      expect(a.compareTo(b), 0);
    });
  });

  group('AlarmSet', () {
    late AlarmSet set;
    late Alarm a;
    late Alarm b;

    setUp(() {
      set = AlarmSet();
      a = _testDepthAlarm(min: 10.0);
      b = _testDepthAlarm(max: 100.0);
    });

    test('starts empty', () {
      expect(set.isEmpty, isTrue);
      expect(set.isNotEmpty, isFalse);
      expect(set.length, 0);
      expect(set.alarms, isEmpty);
    });

    test('add returns true on new alarm and notifies', () {
      int count = 0;
      set.addListener(() => count++);
      expect(set.add(a), isTrue);
      expect(set.contains(a), isTrue);
      expect(set.length, 1);
      expect(set.isNotEmpty, isTrue);
      expect(count, 1);
    });

    test('add returns false on duplicate and does not notify', () {
      set.add(a);
      int count = 0;
      set.addListener(() => count++);
      expect(set.add(a), isFalse);
      expect(set.length, 1);
      expect(count, 0);
    });

    test('remove returns true on present alarm and notifies', () {
      set.add(a);
      int count = 0;
      set.addListener(() => count++);
      expect(set.remove(a), isTrue);
      expect(set.contains(a), isFalse);
      expect(set.isEmpty, isTrue);
      expect(count, 1);
    });

    test('remove returns false on absent alarm and does not notify', () {
      int count = 0;
      set.addListener(() => count++);
      expect(set.remove(a), isFalse);
      expect(count, 0);
    });

    test('clear returns true when non-empty and notifies', () {
      set.add(a);
      set.add(b);
      int count = 0;
      set.addListener(() => count++);
      expect(set.clear(), isTrue);
      expect(set.isEmpty, isTrue);
      expect(count, 1);
    });

    test('clear returns false when empty and does not notify', () {
      int count = 0;
      set.addListener(() => count++);
      expect(set.clear(), isFalse);
      expect(count, 0);
    });

    test('alarms preserves insertion order', () {
      set.add(b);
      set.add(a);
      expect(set.alarms.toList(), [b, a]);
    });
  });

  group('AlarmManager', () {
    late AlarmManager manager;
    late Alarm caution;
    late Alarm otherCaution;
    late Alarm warning;

    setUp(() {
      manager = AlarmManager();
      caution = _testDepthAlarm(min: 10.0, level: AlarmLevel.caution);
      otherCaution = _testDepthAlarm(max: 100.0, level: AlarmLevel.caution);
      warning = _testDepthAlarm(min: 5.0, level: AlarmLevel.warning);
    });

    test('starts with empty active alarms and unacknowledged warnings', () {
      expect(manager.activeAlarms.isEmpty, isTrue);
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
    });

    test('setAlarm adds caution to active alarms only and notifies', () {
      int activeCount = 0;
      int warnCount = 0;
      manager.activeAlarms.addListener(() => activeCount++);
      manager.unacknowledgedWarnings.addListener(() => warnCount++);
      expect(manager.setAlarm(caution), isTrue);
      expect(manager.activeAlarms.contains(caution), isTrue);
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
      expect(activeCount, 1);
      expect(warnCount, 0);
    });

    test('setAlarm adds warning to both active alarms and unacknowledged warnings', () {
      int activeCount = 0;
      int warnCount = 0;
      manager.activeAlarms.addListener(() => activeCount++);
      manager.unacknowledgedWarnings.addListener(() => warnCount++);
      expect(manager.setAlarm(warning), isTrue);
      expect(manager.activeAlarms.contains(warning), isTrue);
      expect(manager.unacknowledgedWarnings.contains(warning), isTrue);
      expect(activeCount, 1);
      expect(warnCount, 1);
    });

    test('setAlarm on already-active alarm returns false and does not notify', () {
      manager.setAlarm(warning);
      int activeCount = 0;
      int warnCount = 0;
      manager.activeAlarms.addListener(() => activeCount++);
      manager.unacknowledgedWarnings.addListener(() => warnCount++);
      expect(manager.setAlarm(warning), isFalse);
      expect(activeCount, 0);
      expect(warnCount, 0);
    });

    test('clearAlarm removes from both sets and notifies', () {
      manager.setAlarm(warning);
      int activeCount = 0;
      int warnCount = 0;
      manager.activeAlarms.addListener(() => activeCount++);
      manager.unacknowledgedWarnings.addListener(() => warnCount++);
      expect(manager.clearAlarm(warning), isTrue);
      expect(manager.activeAlarms.contains(warning), isFalse);
      expect(manager.unacknowledgedWarnings.contains(warning), isFalse);
      expect(activeCount, 1);
      expect(warnCount, 1);
    });

    test('clearAlarm on previously-acknowledged warning still clears active', () {
      manager.setAlarm(warning);
      manager.acknowledgeWarnings();
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
      expect(manager.clearAlarm(warning), isTrue);
      expect(manager.activeAlarms.contains(warning), isFalse);
    });

    test('clearAlarm on inactive alarm returns false and does not notify', () {
      int activeCount = 0;
      manager.activeAlarms.addListener(() => activeCount++);
      expect(manager.clearAlarm(caution), isFalse);
      expect(activeCount, 0);
    });

    test('clearAllAlarms empties both sets when non-empty', () {
      manager.setAlarm(caution);
      manager.setAlarm(warning);
      expect(manager.activeAlarms.length, 2);
      expect(manager.unacknowledgedWarnings.length, 1);
      manager.clearAllAlarms();
      expect(manager.activeAlarms.isEmpty, isTrue);
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
    });

    test('clearAllAlarms is a no-op when empty', () {
      expect(() => manager.clearAllAlarms(), returnsNormally);
      expect(manager.activeAlarms.isEmpty, isTrue);
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
    });

    test('acknowledgeWarnings clears unacknowledged but not active', () {
      manager.setAlarm(caution);
      manager.setAlarm(warning);
      manager.acknowledgeWarnings();
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
      expect(manager.activeAlarms.contains(caution), isTrue);
      expect(manager.activeAlarms.contains(warning), isTrue);
    });

    test('acknowledgeWarnings is a no-op when no unacknowledged warnings', () {
      manager.setAlarm(caution);
      expect(() => manager.acknowledgeWarnings(), returnsNormally);
      expect(manager.activeAlarms.contains(caution), isTrue);
    });

    test('activeAlarms preserves insertion order', () {
      manager.setAlarm(otherCaution);
      manager.setAlarm(caution);
      expect(manager.activeAlarms.alarms.toList(), [otherCaution, caution]);
    });
  });
}
