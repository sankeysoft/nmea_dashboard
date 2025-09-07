// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import 'utils.dart';

const String _testDataId = 'test_data_id';
const HistoryInterval _testInterval = HistoryInterval.fifteenMin;

List<SingleValue<double>?> valuesListFromSuffix(Iterable<double?> suffix) {
  final doubles =
      List<double?>.filled(_testInterval.count - suffix.length, null) + List<double?>.from(suffix);
  return doubles.map((e) => (e == null) ? null : SingleValue(e)).toList();
}

// Super inconvenient to take the real HistoryManager with the asynchronous
// and global state problems of SharedPrefs so fake it out.
class FakeHistoryManager<V extends Value> extends HistoryManager {
  DateTime? lastEventTime;
  History? lastEventHistory;

  late final History<V> restorableHistory;

  FakeHistoryManager() {
    restorableHistory = History(_testInterval, _testDataId, this);
  }

  @override
  void registerEvent(DateTime time, History history) {
    lastEventTime = time;
    lastEventHistory = history;
  }

  @override
  History<FV> restoreHistory<FV extends Value>(HistoryInterval interval, String dataId) {
    assert(interval == restorableHistory.interval);
    assert(dataId == restorableHistory.dataId);
    return restorableHistory as History<FV>;
  }

  @override
  void save<FV extends Value>(
    String dataId,
    HistoryInterval interval,
    List<FV?> values,
    DateTime endValueTime,
  ) {
    // Not implemented
  }
}

void main() {
  test('truncate date time should truncate unmatched datetimes', () {
    expect(
      truncateUtcToDuration(DateTime.utc(2023, 5, 23, 3, 25, 51), const Duration(minutes: 2)),
      DateTime.utc(2023, 5, 23, 3, 24, 00),
    );
  });

  test('truncate date time should not truncate matched datetimes', () {
    expect(
      truncateUtcToDuration(DateTime.utc(2023, 5, 23, 3, 24, 00), const Duration(minutes: 2)),
      DateTime.utc(2023, 5, 23, 3, 24, 00),
    );
  });

  test('OptionalHistory should begin uninitialized.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    expect(history.inner, null);
  });

  test('OptionalHistory initialized if manager is registered first.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    final manager = FakeHistoryManager<SingleValue<double>>();
    history.registerManager(manager);
    expect(history.inner, null);
    history.addListener(() {});
    expect(history.inner, manager.restorableHistory);
  });

  test('OptionalHistory initialized if listener is added first.', () {
    final history = OptionalHistory(_testInterval, _testDataId);
    final manager = FakeHistoryManager<SingleValue<double>>();
    history.addListener(() {});
    expect(history.inner, null);
    history.registerManager(manager);
    expect(history.inner, manager.restorableHistory);
  });

  test('OptionalHistory should passes through events.', () {
    int eventCount = 0;

    final history = OptionalHistory<SingleValue<double>>(_testInterval, _testDataId);
    final manager = FakeHistoryManager<SingleValue<double>>();
    history.addListener(() => eventCount++);
    history.registerManager(manager);

    history.inner!.addValue(SingleValue(2.0));
    expect(eventCount, 0);
    history.inner!.endSegment(DateTime.now().toUtc().add(_testInterval.segment * 2));
    expect(eventCount, 1);
  });

  test('History should be initialized without data by default', () {
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager);
    expect(history.values, List.filled(_testInterval.count, null));
  });

  test('History should use previous values when they overlap', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final previousValues = List.generate(
      _testInterval.count,
      (i) => SingleValue(100 + i.toDouble()),
    );
    final history = History(
      _testInterval,
      _testDataId,
      manager,
      now: start,
      previousEndValueTime: start.subtract(_testInterval.segment * 10),
      previousValues: previousValues,
    );

    for (int i = 0; i < _testInterval.count - 10; i++) {
      expect(history.values[i], ValueMatches(SingleValue((i + 100 + 10).toDouble())));
    }
    for (int i = _testInterval.count - 10; i < _testInterval.count; i++) {
      expect(history.values[i], null);
    }
  });

  test('History should use different length previous values when possible', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final previousValues = List.generate(
      _testInterval.count + 20,
      (i) => SingleValue(100 + i.toDouble()),
    );
    final history = History(
      _testInterval,
      _testDataId,
      manager,
      now: start,
      previousEndValueTime: start.subtract(_testInterval.segment * 10),
      previousValues: previousValues,
    );

    for (int i = 0; i < _testInterval.count - 10; i++) {
      expect(history.values[i], ValueMatches(SingleValue((i + 120 + 10).toDouble())));
    }
    for (int i = _testInterval.count - 10; i < _testInterval.count; i++) {
      expect(history.values[i], null);
    }
  });

  test('History should ignore previous values when they dont overlap', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    List<SingleValue<double>> previousValues = List.generate(
      _testInterval.count,
      (i) => SingleValue(100 + i.toDouble()),
    );
    final history = History(
      _testInterval,
      _testDataId,
      manager,
      now: start,
      previousEndValueTime: start.subtract(_testInterval.segment * 9999),
      previousValues: previousValues,
    );

    for (int i = 0; i < _testInterval.count; i++) {
      expect(history.values[i], null);
    }
  });

  test('History should register an event at the next interval', () {
    final start = DateTime.now().toUtc();
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    expect(
      manager.lastEventTime,
      truncateUtcToDuration(start, _testInterval.segment).add(_testInterval.segment),
    );
    expect(history.endValueTime, truncateUtcToDuration(start, _testInterval.segment));
  });

  test('History should accumulate in segment without updating properties', () {
    final start = DateTime.now().toUtc();
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addValue(SingleValue(2.0));
    history.addValue(SingleValue(3.0));
    history.addValue(SingleValue(4.0));
    expect(history.values[_testInterval.count - 1], null);
  });

  test('History should update values on segment end', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addValue(SingleValue(2.0));
    history.addValue(SingleValue(3.0));
    history.addValue(SingleValue(4.0));
    history.endSegment(start.add(_testInterval.segment));
    history.addValue(SingleValue(5.0));
    history.endSegment(start.add(_testInterval.segment * 2));
    expect(history.values, ValueListMatches(valuesListFromSuffix([3.0, 5.0])));
    expect(manager.lastEventTime, start.add(_testInterval.segment * 3));
  });

  test('History should notify listeners on segment end', () {
    int eventCount = 0;
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addListener(() => eventCount++);
    history.addValue(SingleValue(2.0));
    history.addValue(SingleValue(2.0));
    history.addValue(SingleValue(2.0));
    history.addValue(SingleValue(2.0));
    expect(eventCount, 0);
    history.endSegment(start.add(_testInterval.segment));
    expect(eventCount, 1);
  });

  test('History should insert gaps if timer misses', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addValue(SingleValue(10.0));
    history.endSegment(start.add(_testInterval.segment * 3));
    history.addValue(SingleValue(11.0));
    history.endSegment(start.add(_testInterval.segment * 4));
    expect(history.values, ValueListMatches(valuesListFromSuffix([10.0, null, null, 11.0])));
  });

  test('History should wipe values if timer is very late', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addValue(SingleValue(10.0));
    history.endSegment(start.add(_testInterval.segment));
    history.addValue(SingleValue(11.0));
    history.endSegment(start.add(_testInterval.segment * 2));
    history.addValue(SingleValue(12.0));
    history.endSegment(start.add(_testInterval.segment * 9999));
    expect(history.values, ValueListMatches(valuesListFromSuffix([])));
  });

  test('History should ignore negative time step', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);
    history.addValue(SingleValue(4.0));
    expect(manager.lastEventTime, start.add(_testInterval.segment));
    history.endSegment(start.subtract(_testInterval.segment * 1));
    expect(manager.lastEventTime, start.add(_testInterval.segment));

    history.addValue(SingleValue(12.0));
    history.endSegment(start.add(_testInterval.segment));
    expect(manager.lastEventTime, start.add(_testInterval.segment * 2));
    expect(history.values, ValueListMatches(valuesListFromSuffix([12.0])));
  });

  test('History should expire old entries once full', () {
    final start = truncateUtcToDuration(DateTime.now().toUtc(), _testInterval.segment);
    final manager = FakeHistoryManager<SingleValue<double>>();
    final history = History<SingleValue<double>>(_testInterval, _testDataId, manager, now: start);

    for (int i = 1; i < _testInterval.count + 4; i++) {
      history.addValue(SingleValue(i.toDouble()));
      history.endSegment(start.add(_testInterval.segment * i));
    }

    for (int i = 0; i < _testInterval.count; i++) {
      expect(history.values[i]!.data, i.toDouble() + 4.0);
    }
  });
}
