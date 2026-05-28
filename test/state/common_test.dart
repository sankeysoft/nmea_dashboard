// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:test/test.dart';

void main() {
  test('InvalidTypeException should include message in toString', () {
    expect(InvalidTypeException('test cause').toString(), 'InvalidTypeException: test cause');
  });

  test('Source.fromString should return matching value or null', () {
    expect(Source.fromString('network'), Source.network);
    expect(Source.fromString('invalid'), null);
    expect(Source.fromString(null), null);
  });

  test('Dimension.fromString should return matching value or null', () {
    expect(Dimension.fromString('speed'), Dimension.speed);
    expect(Dimension.fromString('invalid'), null);
  });

  test('CellType.fromString should return matching value or null', () {
    expect(CellType.fromString('current'), CellType.current);
    expect(CellType.fromString('invalid'), null);
  });

  test('HistoryInterval.fromString should return matching value or null', () {
    expect(HistoryInterval.fromString('twoHours'), HistoryInterval.twoHours);
    expect(HistoryInterval.fromString('invalid'), null);
  });

  test('StatsInterval.fromString should return matching value or null', () {
    expect(StatsInterval.fromString('oneMin'), StatsInterval.oneMin);
    expect(StatsInterval.fromString('invalid'), null);
  });

  test('Dimension min and max values must match storageType', () {
    for (final dim in Dimension.values) {
      if (dim.minValue != null) {
        expect(
          dim.minValue.runtimeType,
          dim.storageType,
          reason: '${dim.name}.minValue type does not match storageType',
        );
      }
      if (dim.maxValue != null) {
        expect(
          dim.maxValue.runtimeType,
          dim.storageType,
          reason: '${dim.name}.maxValue type does not match storageType',
        );
      }
    }
  });

  test('derivation friendly dimensions should have numeric formatters.', () {
    for (final dim in Dimension.values) {
      if (dim.derivationFriendly) {
        for (final fmt in formattersFor(dim).values) {
          fmt as NumericFormatter;
        }
      }
    }
  });

  test('HistoryInterval should format cell names', () {
    final element = ConsistentDataElement(
      Source.network,
      Property.apparentWindAngle,
      Staleness(const Duration(minutes: 1)),
    );
    expect(HistoryInterval.twoHours.shortCellName(element), 'AWA (2hr)');
  });

  test('HistoryInterval should format times', () {
    final dt = DateTime(2023, 6, 15, 14, 52, 36);
    expect(HistoryInterval.twelveHours.formatTime(dt), '14:52');
    expect(HistoryInterval.fortyEightHours.formatTime(dt), 'Jun 15');
  });

  test('StatsInterval should format cell names', () {
    final element = ConsistentDataElement(
      Source.network,
      Property.speedOverGround,
      Staleness(const Duration(minutes: 1)),
    );
    expect(StatsInterval.oneMin.shortCellName(element), 'SOG (1m)');
  });
}
