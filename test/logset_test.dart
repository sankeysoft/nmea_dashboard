// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/log_set.dart';
import 'package:test/test.dart';

void main() {
  test('should start with no entries', () {
    expect(LogSet().entries, isEmpty);
  });

  test('should store entries', () {
    final logSet = LogSet();
    final record1 = LogRecord(Level.INFO, 'Test info', 'logger1');
    final record2 = LogRecord(Level.WARNING, 'Test warn', 'logger2');

    logSet.add(record1);
    logSet.add(record2);
    final entries = logSet.entries;

    expect(entries.length, 2);
    expect(entries[0].level, record1.level);
    expect(entries[0].message, record1.message);
    expect(entries[1].level, record2.level);
    expect(entries[1].message, record2.message);

    expect(
      logSet.toString(),
      matches(r'^\d{2}:\d{2}:\d{2} INFO Test info\n\d{2}:\d{2}:\d{2} WARNING Test warn$'),
    );
  });

  test('should clear entries', () {
    final logSet = LogSet();

    logSet.add(LogRecord(Level.INFO, 'Test info', 'logger1'));
    expect(logSet.entries.length, 1);
    logSet.clear();
    expect(logSet.entries.length, 0);
  });

  test('should notify listeners', () {
    int eventCount = 0;
    final logSet = LogSet();
    logSet.addListener(() => eventCount++);

    expect(eventCount, 0);
    logSet.add(LogRecord(Level.INFO, 'Test info', 'logger1'));
    expect(eventCount, 1);
    logSet.clear();
    expect(eventCount, 2);
  });
}
