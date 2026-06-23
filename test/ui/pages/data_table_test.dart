// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:nmea_dashboard/ui/pages/data_table.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A silent warning alarm so the warning dialog never tries to play audio.
Alarm _warning() {
  return Alarm(
    source: Source.network,
    elementName: Property.depthWithOffset.shortName,
    property: Property.depthWithOffset,
    level: AlarmLevel.warning,
    formatter: numericFormattersFor(Dimension.depth)['feet']!,
    min: 10.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataTablePage warning dialog', () {
    late AlarmManager manager;
    late UiSettings uiSettings;
    late DataSet dataSet;
    late DataPageSpec pageSpec;
    late PageSettings pageSettings;

    Future<void> setUpWith(WidgetTester tester, Map<String, Object> initialPrefs) async {
      SharedPreferences.setMockInitialValues(initialPrefs);
      // DataSet and HistoryManagerImpl start periodic timers in their constructors.
      // Build them in the real async zone so those timers are not flagged as pending
      // by the fake-async timer check when the widget test tears down.
      await tester.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        manager = AlarmManager();
        uiSettings = UiSettings(prefs);
        dataSet = DataSet(
          NetworkSettings(prefs),
          DerivedDataSettings(prefs),
          AlarmSettings(prefs),
          HistoryManagerImpl(prefs),
          manager,
        );
        // A single cell avoids the empty-grid divide-by-zero in column layout.
        pageSpec = DataPageSpec('Test page', [
          DataCellSpec('network', 'speedOverGround', 'current', 'knots'),
        ]);
        pageSettings = PageSettings(
          prefs,
          '[{"name":"Test page","cells":[{"source":"network","element":"speedOverGround",'
          '"type":"current","format":"knots"}]}]',
        );
      });
    }

    Future<void> pumpPage(WidgetTester tester) async {
      // DropdownButtonFormField and the dialog can overflow the narrow test surface,
      // which raises layout assertions we don't care about here.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is FlutterError &&
            details.exception.toString().contains('overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<UiSettings>.value(value: uiSettings),
            ChangeNotifierProvider<DataPageSpec>.value(value: pageSpec),
            ChangeNotifierProvider<PageSettings>.value(value: pageSettings),
            Provider<AlarmManager>.value(value: manager),
          ],
          child: const MaterialApp(home: DataTablePage()),
        ),
      );
      // Build, then let the post-frame callback open the dialog and its entrance
      // animation finish. Avoid pumpAndSettle so the DataSet's real network retry
      // timer is never advanced and left pending at teardown.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows the dialog when an unacknowledged warning is present', (tester) async {
      await setUpWith(tester, {});
      manager.setAlarm(_warning());
      await pumpPage(tester);
      expect(find.text('Warning'), findsOneWidget);
    });

    testWidgets('tapping silence acknowledges warnings and dismisses the dialog', (tester) async {
      await setUpWith(tester, {});
      manager.setAlarm(_warning());
      await pumpPage(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
      expect(find.text('Warning'), findsNothing);
      // The default option is "one time", which stores no persistent silence.
      expect(uiSettings.alarmSilenceTime, isNull);
    });

    testWidgets('selecting a duration from the dropdown persists it on silence', (tester) async {
      await setUpWith(tester, {});
      manager.setAlarm(_warning());
      await pumpPage(tester);

      // Open the attached dropdown and pick the one hour option. The button itself also
      // contains the (hidden) label text, so target the menu entry with .last.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Silence for 1 hour').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(uiSettings.alarmSilenceTime, const Duration(hours: 1));
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
    });

    testWidgets('dialog defaults its silence duration from settings', (tester) async {
      // A stored 5 minute silence should pre-select that option, so silencing keeps it.
      await setUpWith(tester, {'ui_alarm_silence_seconds': 300});
      manager.setAlarm(_warning());
      await pumpPage(tester);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(uiSettings.alarmSilenceTime, const Duration(minutes: 5));
      expect(manager.unacknowledgedWarnings.isEmpty, isTrue);
    });
  });
}
