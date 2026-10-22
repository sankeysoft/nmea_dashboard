// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:nmea_dashboard/ui/cells/creation.dart';
import 'package:nmea_dashboard/ui/cells/stats_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/text_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DataSet dataSet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    dataSet = DataSet(
      NetworkSettings(prefs),
      DerivedDataSettings(prefs),
      AlarmSettings(prefs),
      HistoryManagerImpl(prefs),
      AlarmManager(),
    );
    // Replace a numeric element with one that supports neither stats nor history.
    dataSet.sources[Source.network]![Property.speedOverGround.name] =
        ConsistentDataElement<SingleValue<double>>(Source.network, Property.speedOverGround, null);
  });

  for (final type in ['average', 'minimum', 'maximum']) {
    test('$type cell for an element without stats is not found', () {
      final spec = DataCellSpec(
        'network',
        'speedOverGround',
        type,
        'knots',
        statsInterval: 'oneMin',
      );
      expect(createCell(dataSet, spec), isA<NotFoundCell>());
    });

    test('$type cell with an invalid interval is not found', () {
      final spec = DataCellSpec('network', 'depthWithOffset', type, 'feet', statsInterval: 'nope');
      expect(createCell(dataSet, spec), isA<NotFoundCell>());
    });

    test('$type cell is created for numeric and bearing elements', () {
      for (final (element, format) in [('depthWithOffset', 'feet'), ('courseOverGround', 'true')]) {
        final spec = DataCellSpec('network', element, type, format, statsInterval: 'oneMin');
        expect(createCell(dataSet, spec), isA<StatsValueCell>());
      }
    });
  }

  test('history cell for an element without history is not found', () {
    final spec = DataCellSpec(
      'network',
      'speedOverGround',
      'history',
      'knots',
      historyInterval: 'twoHours',
    );
    expect(createCell(dataSet, spec), isA<NotFoundCell>());
  });
}
