// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/displayable.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:test/test.dart';

KeyedDataCellSpec _makeSpec(String element, String format) {
  return KeyedDataCellSpec(DataCellKey.make(DataPageKey.make()),
      DataCellSpec('network', element, format));
}

DataElement _makeData(Property property) {
  return ConsistentDataElement.newForProperty(
      property, Staleness(const Duration(seconds: 1)));
}

void main() {
  test('should not accept mismatched type', () {
    expect(
        () => DataElementDisplay(
            _makeData(Property.gpsPosition),
            formattersFor(Dimension.depth)['feet']!,
            _makeSpec('gpsPosition', 'degMin')),
        throwsException);
  });

  test('should handle missing data', () {
    final data = _makeData(Property.speedOverGround);
    final displayable = DataElementDisplay(
        data,
        formattersFor(Dimension.speed)['metersPerSec']!,
        _makeSpec('speedOverGround', 'metersPerSec'));
    expect(displayable.value, '-.-');
    expect(displayable.heading, 'SOG');
    expect(displayable.units, 'm/s');
  });

  test('should handle present data', () {
    final data = _makeData(Property.speedOverGround);
    final displayable = DataElementDisplay(
        data,
        formattersFor(Dimension.speed)['metersPerSec']!,
        _makeSpec('speedOverGround', 'metersPerSec'));
    data.updateValue(
        SingleValue<double>(1.234, Source.network, Property.speedOverGround));
    expect(displayable.value, '1.2');
    expect(displayable.heading, 'SOG');
    expect(displayable.units, 'm/s');
  });

  test('should pass through change events', () {
    final data = _makeData(Property.speedOverGround);
    final displayable = DataElementDisplay(
        data,
        formattersFor(Dimension.speed)['metersPerSec']!,
        _makeSpec('speedOverGround', 'metersPerSec'));
    int eventCount = 0;
    displayable.addListener(() => eventCount++);

    expect(eventCount, 0);
    data.updateValue(
        SingleValue<double>(1.234, Source.network, Property.speedOverGround));
    expect(eventCount, 1);
  });
}
