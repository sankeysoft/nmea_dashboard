// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/history.dart';
import 'package:test/test.dart';

const String _testDataId = 'test_data_id';
const HistoryInterval _testInterval = HistoryInterval.fifteenMin;

// Super inconvenient to take the real HistoryManager with the asynchronous
// and global state problems of SharedPrefs.

class FakeHistoryManager extends HistoryManager {
  DateTime? lastEventTime;
  History? lastEventHistory;

  late final History restorableHistory;

  FakeHistoryManager() {
    restorableHistory = History(_testInterval, _testDataId, this);
  }

  @override
  void registerEvent(DateTime time, History history) {
    lastEventTime = time;
    lastEventHistory = history;
  }

  @override
  History restoreHistory(HistoryInterval interval, String dataId) {
    assert(interval == restorableHistory.interval);
    assert(dataId == restorableHistory.dataId);
    return restorableHistory;
  }

  @override
  void save(String dataId, HistoryInterval interval, List<double?> values,
      DateTime endValueTime) {
    // Not implemented
  }
}

SingleValue<double> _value(double value) {
  return SingleValue(value, Source.derived, Property.depthWithOffset);
}

void main() {
  test('truncate date time should truncate unmatched datetimes', () {
    expect(
        truncateUtcToDuration(
            DateTime.utc(2023, 5, 23, 3, 25, 51), const Duration(minutes: 2)),
        DateTime.utc(2023, 5, 23, 3, 24, 00));
  });

  test('truncate date time should not truncate matched datetimes', () {
    expect(
        truncateUtcToDuration(
            DateTime.utc(2023, 5, 23, 3, 24, 00), const Duration(minutes: 2)),
        DateTime.utc(2023, 5, 23, 3, 24, 00));
  });

  test('OptionalHistory should begin uninitialized.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    expect(history.inner, null);
  });

  test('OptionalHistory initialized if manager is registered first.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    final manager = FakeHistoryManager();
    history.registerManager(manager);
    expect(history.inner, null);
    history.addListener(() {});
    expect(history.inner, manager.restorableHistory);
  });

  test('OptionalHistory initialized if listener is added first.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    final manager = FakeHistoryManager();
    history.addListener(() {});
    expect(history.inner, null);
    history.registerManager(manager);
    expect(history.inner, manager.restorableHistory);
  });

  test('OptionalHistory should passes through events.', () {
    int eventCount = 0;

    final history = OptionalHistory(_testInterval, _testDataId);
    final manager = FakeHistoryManager();
    history.addListener(() => eventCount++);
    history.registerManager(manager);

    history.inner!.addValue(_value(2.0));
    expect(eventCount, 0);
    history.inner!
        .endSegment(DateTime.now().toUtc().add(_testInterval.segment * 2));
    expect(eventCount, 1);
  });

  test('History should be initialized without data by default', () {
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager);
    expect(history.values, List.filled(_testInterval.count, null));
  });

  test('History should use previous values when they overlap', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    List<double> previousValues =
        List.generate(_testInterval.count, (i) => 100 + i.toDouble());
    final history = History(_testInterval, _testDataId, manager,
        now: start,
        previousEndValueTime: start.subtract(_testInterval.segment * 10),
        previousValues: previousValues);

    for (int i = 0; i < _testInterval.count - 10; i++) {
      expect(history.values[i], (i + 100 + 10).toDouble());
    }
    for (int i = _testInterval.count - 10; i < _testInterval.count; i++) {
      expect(history.values[i], null);
    }
  });

  test('History should ignore previous values when they dont overlap', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    List<double> previousValues =
        List.generate(_testInterval.count, (i) => 100 + i.toDouble());
    final history = History(_testInterval, _testDataId, manager,
        now: start,
        previousEndValueTime: start.subtract(_testInterval.segment * 9999),
        previousValues: previousValues);

    for (int i = 0; i < _testInterval.count; i++) {
      expect(history.values[i], null);
    }
  });

  test('History should register an event at the next interval', () {
    final start = DateTime.now().toUtc();
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    expect(
        manager.lastEventTime,
        truncateUtcToDuration(start, _testInterval.segment)
            .add(_testInterval.segment));
    expect(history.endValueTime,
        truncateUtcToDuration(start, _testInterval.segment));
  });

  test('History should accumulate in segment without updating properties', () {
    final start = DateTime.now().toUtc();
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    history.addValue(_value(2.0));
    history.addValue(_value(3.0));
    history.addValue(_value(4.0));
    expect(history.min, null);
    expect(history.max, null);
    expect(history.values[_testInterval.count - 1], null);
  });

  test('History should update min,max,values on segment end', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    history.addValue(_value(2.0));
    history.addValue(_value(3.0));
    history.addValue(_value(4.0));
    history.endSegment(start.add(_testInterval.segment));
    history.addValue(_value(5.0));
    history.endSegment(start.add(_testInterval.segment * 2));
    expect(history.min, 3.0);
    expect(history.max, 5.0);
    expect(history.values[_testInterval.count - 1], 5.0);
    expect(history.values[_testInterval.count - 2], 3.0);
    expect(manager.lastEventTime, start.add(_testInterval.segment * 3));
  });

  test('History should notify listeners on segment end', () {
    int eventCount = 0;
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    history.addListener(() => eventCount++);
    history.addValue(_value(2.0));
    history.addValue(_value(2.0));
    history.addValue(_value(2.0));
    history.addValue(_value(2.0));
    expect(eventCount, 0);
    history.endSegment(start.add(_testInterval.segment));
    expect(eventCount, 1);
  });

  test('History should insert gaps if timer misses', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    history.addValue(_value(10.0));
    history.endSegment(start.add(_testInterval.segment * 3));
    history.addValue(_value(11.0));
    history.endSegment(start.add(_testInterval.segment * 4));
    expect(history.min, 10.0);
    expect(history.max, 11.0);
    expect(history.values[_testInterval.count - 1], 11.0);
    expect(history.values[_testInterval.count - 2], null);
    expect(history.values[_testInterval.count - 3], null);
    expect(history.values[_testInterval.count - 4], 10.0);
    expect(history.values[_testInterval.count - 5], null);
    expect(manager.lastEventTime, start.add(_testInterval.segment * 5));
  });

  test('History should ignore negative time step', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);
    history.addValue(_value(4.0));
    expect(manager.lastEventTime, start.add(_testInterval.segment));
    history.endSegment(start.subtract(_testInterval.segment * 1));
    expect(manager.lastEventTime, start.add(_testInterval.segment));
    expect(history.min, null);
    expect(history.max, null);

    history.addValue(_value(12.0));
    history.endSegment(start.add(_testInterval.segment));
    expect(manager.lastEventTime, start.add(_testInterval.segment * 2));
    expect(history.min, 12.0);
    expect(history.max, 12.0);
    expect(history.values[_testInterval.count - 1], 12.0);
  });

  test('History should expire old entries once full', () {
    final start =
        truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager();
    final history = History(_testInterval, _testDataId, manager, now: start);

    for (int i = 1; i < _testInterval.count + 4; i++) {
      history.addValue(_value(i.toDouble()));
      history.endSegment(start.add(_testInterval.segment * i));
    }

    expect(history.min, 4.0);
    expect(history.max, _testInterval.count.toDouble() + 3.0);
    for (int i = 0; i < _testInterval.count; i++) {
      expect(history.values[i], i.toDouble() + 4.0);
    }
  });
}
