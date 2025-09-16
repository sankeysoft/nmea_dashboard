// Copyright Jody M Sankey 2025
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:fake_async/fake_async.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_stats.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

const String _testDataId = 'test_data_id';
const StatsInterval _testInterval = StatsInterval.oneMin;

void main() {
  test('OptionalStats should begin uninitialized.', () {
    final stats = OptionalStats<SingleValue<double>>(_testInterval, _testDataId);
    expect(stats.inner, isNull);
  });

  test('OptionalStats initialized when listener is added.', () {
    final stats = OptionalStats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() {});
    expect(stats.inner, isNotNull);
  });

  test('OptionalStats should pass through events.', () {
    int eventCount = 0;
    final stats = OptionalStats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() => eventCount++);

    stats.inner!.addValue(SingleValue(2.0));
    expect(eventCount, 1);
    stats.inner!.addValue(SingleValue(3.0));
    expect(eventCount, 2);
  });

  test('Stats should be initialized without data by default', () {
    final stats = Stats<SingleValue<double>>(_testInterval, _testDataId);
    expect(stats.mean, isNull);
    expect(stats.last, isNull);
  });

  test('Stats should accumulate data if expiry is not called', () {
    int eventCount = 0;
    final stats = Stats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() => eventCount++);

    stats.addValue(SingleValue(10.0));
    expect(eventCount, 1);
    expect(stats.mean, ValueMatches(SingleValue(10.0)));
    expect(stats.last, ValueMatches(SingleValue(10.0)));
    stats.addValue(SingleValue(20.0));
    expect(eventCount, 2);
    expect(stats.mean, ValueMatches(SingleValue(15.0)));
    expect(stats.last, ValueMatches(SingleValue(20.0)));
    stats.addValue(SingleValue(30.0));
    expect(eventCount, 3);
    expect(stats.mean, ValueMatches(SingleValue(20.0)));
    expect(stats.last, ValueMatches(SingleValue(30.0)));
  });

  test('Stats should remove data when expired', () {
    int eventCount = 0;
    final tick = Duration(milliseconds: (_testInterval.duration.inMilliseconds / 5.0).toInt());
    final stats = Stats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() => eventCount++);

    fakeAsync((async) {
      stats.addValue(SingleValue(10.0));
      async.elapse(tick);
      stats.addValue(SingleValue(20.0));
      async.elapse(tick);
      stats.addValue(SingleValue(30.0));
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(20.0)));
      expect(eventCount, 3);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(20.0)));
      expect(eventCount, 3);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(25.0)));
      expect(eventCount, 4);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(30.0)));
      expect(stats.last, ValueMatches(SingleValue(30.0)));
      expect(eventCount, 5);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(stats.last, isNull);
      expect(eventCount, 6);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(eventCount, 6);
    });
  });

  test('Stats should batch remove data if timer is late', () {
    int eventCount = 0;
    final tick = Duration(milliseconds: (_testInterval.duration.inMilliseconds / 5.0).toInt());
    final stats = Stats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() => eventCount++);

    fakeAsync((async) {
      stats.addValue(SingleValue(10.0));
      async.elapse(tick);
      stats.addValue(SingleValue(20.0));
      async.elapse(tick);
      stats.addValue(SingleValue(30.0));
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(20.0)));
      expect(eventCount, 3);
      // Jump a block without letting timers fire then let them fire.
      async.elapseBlocking(_testInterval.duration);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(eventCount, 4);
    });
  });

  test('Stats should restart timer after being empty.', () {
    int eventCount = 0;
    final tick = Duration(milliseconds: (_testInterval.duration.inMilliseconds / 4.0).toInt());
    final stats = Stats<SingleValue<double>>(_testInterval, _testDataId);
    stats.addListener(() => eventCount++);

    fakeAsync((async) {
      stats.addValue(SingleValue(10.0));
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(10.0)));
      expect(eventCount, 1);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(10.0)));
      expect(eventCount, 1);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(10.0)));
      expect(eventCount, 1);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(eventCount, 2);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(eventCount, 2);
      stats.addValue(SingleValue(20.0));
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(20.0)));
      expect(eventCount, 3);
      stats.addValue(SingleValue(30.0));
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(25.0)));
      expect(eventCount, 4);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(25.0)));
      expect(eventCount, 4);
      async.elapse(tick);
      expect(stats.mean, ValueMatches(SingleValue(30.0)));
      expect(eventCount, 5);
      async.elapse(tick);
      expect(stats.mean, isNull);
      expect(eventCount, 6);
    });
  });
}
