// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/derived_data.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

final _staleness = Staleness(const Duration(milliseconds: 100));
const _testName = 'Test element';
const _testSource = Source.local;

void main() {
  test('Operation.fromString should return matching value or null', () {
    expect(Operation.fromString('add'), Operation.add);
    expect(Operation.fromString('invalid'), null);
  });

  test('add operation should give correct results', () {
    expect(Operation.add.apply(3, 2), 5);
    expect(Operation.add.reverse(3, 2), 1);
  });

  test('subtract operation should give correct results', () {
    expect(Operation.subtract.apply(3, 2), 1);
    expect(Operation.subtract.reverse(3, 2), 5);
  });

  test('multiply operation should give correct results', () {
    expect(Operation.multiply.apply(3, 2), 6);
    expect(Operation.multiply.reverse(3, 2), 1.5);
  });

  test('derived data element accepts updates', () async {
    final source = ConsistentDataElement<SingleValue<double>>(
      _testSource,
      Property.depthUncalibrated,
      _staleness,
    );
    final formatter = formattersFor(Dimension.depth)['feet'] as NumericFormatter;
    final derived = DerivedDataElement(_testName, source, formatter, Operation.add, 100);

    int eventCount = 0;
    derived.addListener(() => eventCount++);

    // We should echo updates on the source and pass through notifications.
    expect(derived.value, null);
    expect(derived.shortName, _testName);
    expect(derived.longName, _testName);
    expect(derived.name, _testName);
    expect(derived.source, Source.derived);
    source.updateValue(BoundValue(_testSource, Property.depthUncalibrated, SingleValue(5)));
    expect(derived.value, ValueMatches(SingleValue((5 * metersToFeet + 100) / metersToFeet)));
    expect(eventCount, 1);

    // And go stale when our source does.
    await Future.delayed(_staleness.duration * 2);
    expect(source.value, null);
    expect(derived.value, null);
    expect(eventCount, 2);
  });

  group('VmgWindCalculatedDataElement', () {
    late ConsistentDataElement<SingleValue<double>> sog;
    late ConsistentDataElement<SingleValue<double>> twa;
    late VmgWindCalculatedDataElement vmg;

    setUp(() {
      sog = ConsistentDataElement<SingleValue<double>>(
        _testSource,
        Property.speedOverGround,
        _staleness,
      );
      twa = ConsistentDataElement<SingleValue<double>>(
        _testSource,
        Property.trueWindAngle,
        _staleness,
      );
      vmg = VmgWindCalculatedDataElement({
        Property.speedOverGround.name: sog as DataElement<Value, Value>,
        Property.trueWindAngle.name: twa as DataElement<Value, Value>,
      });
    });

    void setSog(double v) =>
        sog.updateValue(BoundValue(_testSource, Property.speedOverGround, SingleValue(v)));
    void setTwa(double v) =>
        twa.updateValue(BoundValue(_testSource, Property.trueWindAngle, SingleValue(v)));

    test('starts null', () {
      expect(vmg.value, null);
    });

    test('stays null when only SOG is set', () {
      setSog(5.0);
      expect(vmg.value, null);
    });

    test('stays null when only TWA is set', () {
      setTwa(45.0);
      expect(vmg.value, null);
    });

    test('calculates correctly heading directly into wind', () {
      setSog(5.0);
      setTwa(0.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0)));
    });

    test('calculates correctly heading at an angle to wind', () {
      setSog(5.0);
      setTwa(60.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0 * cos(60.0 * pi / 180.0))));
    });

    test('calculates correctly heading directly downwind', () {
      setSog(5.0);
      setTwa(180.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0)));
    });

    test('calculates correctly when SOG is set after TWA', () {
      setTwa(60.0);
      setSog(5.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0 * cos(60.0 * pi / 180.0))));
    });

    test('invalidates when SOG goes stale', () async {
      setSog(5.0);
      setTwa(60.0);
      expect(vmg.value, isNotNull);
      await Future.delayed(_staleness.duration * 2);
      expect(vmg.value, null);
    });
  });

  group('VmgWptCalculatedDataElement', () {
    late ConsistentDataElement<SingleValue<double>> sog;
    late BearingDataElement cog;
    late BearingDataElement wptBearing;
    late VmgWptCalculatedDataElement vmg;

    setUp(() {
      final variation = ConsistentDataElement<SingleValue<double>>(
        _testSource,
        Property.variation,
        _staleness,
      );
      sog = ConsistentDataElement<SingleValue<double>>(
        _testSource,
        Property.speedOverGround,
        _staleness,
      );
      cog = BearingDataElement(_testSource, variation, Property.courseOverGround, _staleness);
      wptBearing = BearingDataElement(_testSource, variation, Property.waypointBearing, _staleness);
      vmg = VmgWptCalculatedDataElement({
        Property.speedOverGround.name: sog as DataElement<Value, Value>,
        Property.courseOverGround.name: cog as DataElement<Value, Value>,
        Property.waypointBearing.name: wptBearing as DataElement<Value, Value>,
      });
    });

    void setSog(double v) =>
        sog.updateValue(BoundValue(_testSource, Property.speedOverGround, SingleValue(v)));
    void setCog(double v) =>
        cog.updateValue(BoundValue(_testSource, Property.courseOverGround, SingleValue(v)));
    void setWptBearing(double v) =>
        wptBearing.updateValue(BoundValue(_testSource, Property.waypointBearing, SingleValue(v)));

    test('starts null', () {
      expect(vmg.value, null);
    });

    test('stays null until all three inputs are set', () {
      setSog(5.0);
      expect(vmg.value, null);
      setCog(90.0);
      expect(vmg.value, null);
      setWptBearing(90.0);
      expect(vmg.value, isNotNull);
    });

    test('calculates correctly when heading directly toward waypoint', () {
      setSog(5.0);
      setCog(90.0);
      setWptBearing(90.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0)));
    });

    test('calculates correctly when heading at 90 degrees to waypoint', () {
      setSog(5.0);
      setCog(0.0);
      setWptBearing(90.0);
      expect(vmg.value, ValueMatches(SingleValue(0.0)));
    });

    test('calculates correctly when heading away from waypoint', () {
      setSog(5.0);
      setCog(225.0);
      setWptBearing(45.0);
      expect(vmg.value, ValueMatches(SingleValue(-5.0)));
    });

    test('handles bearing wraparound correctly', () {
      setSog(5.0);
      setCog(10.0);
      setWptBearing(350.0);
      // relAngle = (10 - 350) % 360 = 20
      expect(vmg.value, ValueMatches(SingleValue(5.0 * cos(20.0 * pi / 180.0))));
    });

    test('calculates correctly when COG is set last', () {
      setSog(5.0);
      setWptBearing(240.0);
      setCog(180.0);
      expect(vmg.value, ValueMatches(SingleValue(5.0 * cos(60.0 * pi / 180.0))));
    });

    test('invalidates when inputs go stale', () async {
      setSog(5.0);
      setCog(0.0);
      setWptBearing(0.0);
      expect(vmg.value, isNotNull);
      await Future.delayed(_staleness.duration * 2);
      expect(vmg.value, null);
    });
  });
}
