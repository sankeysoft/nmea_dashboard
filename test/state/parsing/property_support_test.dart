// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/property_support.dart';
import 'package:property_support_builder/builder.dart';
import 'package:test/test.dart';

List<String> _readSources(String dir) {
  final files = Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
  return (files.toList()..sort((a, b) => a.path.compareTo(b.path)))
      .map((f) => f.readAsStringSync())
      .toList();
}

void main() {
  test('generated property sets should be up to date', () {
    final expected = generatePropertySets(
      nmea0183Sources: _readSources(nmea0183Dir),
      nmea2000Sources: _readSources(nmea2000Dir),
    );
    expect(
      File(outputPath).readAsStringSync(),
      expected,
      reason: 'Run `dart run build_runner build` to regenerate $outputPath',
    );
  });

  test('should report expected protocol support for network properties', () {
    const only0183 = {
      Property.alternator1Voltage,
      Property.alternator2Voltage,
      Property.battery1Voltage,
      Property.battery2Voltage,
      Property.engine1Rpm,
      Property.engine2Rpm,
      Property.engine1Temperature,
      Property.engine2Temperature,
      Property.engine2OilPressure,
    };
    for (final property in Property.values.where((p) => p.sources.contains(Source.network))) {
      expect(property.supportedBy(NetworkStandard.nmea0183), true, reason: '$property 0183');
      expect(
        property.supportedBy(NetworkStandard.nmea2000),
        !only0183.contains(property),
        reason: '$property 2000',
      );
    }
  });

  test('should not report support for properties without a network source', () {
    for (final property in [Property.localTime, Property.vmgWind, Property.vmgWaypoint]) {
      for (final standard in NetworkStandard.values) {
        expect(property.supportedBy(standard), false, reason: '$property $standard');
      }
    }
  });
}
