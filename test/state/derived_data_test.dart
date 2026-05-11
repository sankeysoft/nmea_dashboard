// Copyright Jody M Sankey 2023-2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

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
    final formatter = formattersFor(Dimension.depth)['feet'] as ConvertingFormatter;
    final derived = DerivedDataElement(_testName, source, formatter, Operation.add, 100);

    int eventCount = 0;
    derived.addListener(() => eventCount++);

    // We should echo updates on the source and pass through notifications.
    expect(derived.value, null);
    expect(derived.shortName, _testName);
    expect(derived.longName, _testName);
    source.updateValue(BoundValue(_testSource, Property.depthUncalibrated, SingleValue(5)));
    expect(derived.value, ValueMatches(SingleValue((5 * metersToFeet + 100) / metersToFeet)));
    expect(eventCount, 1);

    // And go stale when our source does.
    await Future.delayed(_staleness.duration * 2);
    expect(source.value, null);
    expect(derived.value, null);
    expect(eventCount, 2);
  });
}
