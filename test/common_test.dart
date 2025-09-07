// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:test/test.dart';

void main() {
  // A lot of the early material in this module would only result in change
  // detector tests so skip testing it.
  test('derivation friendly dimensions should have numeric formatters.', () {
    for (final dim in Dimension.values) {
      if (dim.derivationFriendly) {
        for (final fmt in formattersFor(dim).values) {
          fmt as NumericFormatter;
        }
      }
    }
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
    expect(StatsInterval.oneMin.shortCellName(element), 'SOG (1min)');
  });
}
