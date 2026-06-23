// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarms.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditAlarmsPage', () {
    late DataSet dataSet;
    late AlarmSettings alarmSettings;
    late FormatPreferences formatPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      alarmSettings = AlarmSettings(prefs);
      formatPrefs = FormatPreferences(prefs);
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        AlarmSettings(prefs),
        HistoryManagerImpl(prefs),
        AlarmManager(),
      );
    });

    Future<void> pumpPage(WidgetTester tester, {NavigatorObserver? observer}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<AlarmSettings>.value(value: alarmSettings),
            ChangeNotifierProvider<FormatPreferences>.value(value: formatPrefs),
          ],
          child: MaterialApp(navigatorObservers: [?observer], home: EditAlarmsPage()),
        ),
      );
      await tester.pump();
    }

    // Using an invalid source name ensures Alarm.fromSpec throws and the tile
    // displays "Invalid spec" rather than a resolved alarm description.
    AlarmSpec makeSpec(String element) =>
        AlarmSpec('bogus_source', element, 'caution', 'knots', min: 5.0);

    testWidgets('shows title and add alarm tile', (tester) async {
      await pumpPage(tester);
      expect(find.text('Edit alarms'), findsOneWidget);
      expect(find.text('Add new alarm'), findsOneWidget);
    });

    testWidgets('shows existing alarms', (tester) async {
      alarmSettings.setAlarm(makeSpec('speedOverGround'));
      await pumpPage(tester);
      expect(find.text('Invalid spec'), findsOneWidget);
    });

    testWidgets('delete tap shows confirmation dialog', (tester) async {
      alarmSettings.setAlarm(makeSpec('myElement'));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // The dialog title echoes the tile title, which is "Invalid spec" for an unresolvable spec.
      expect(find.text('Delete Invalid spec'), findsOneWidget);
    });

    testWidgets('confirm delete removes alarm', (tester) async {
      alarmSettings.setAlarm(makeSpec('myElement'));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(alarmSettings.alarmSpecs, isEmpty);
    });

    testWidgets('tapping alarm tile navigates to edit form', (tester) async {
      alarmSettings.setAlarm(makeSpec('speedOverGround'));
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('Invalid spec'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('tapping add alarm tile navigates to edit form', (tester) async {
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('Add new alarm'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('copy button shows snackbar', (tester) async {
      mockClipboard(tester);
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alarm definitions copied to clipboard'), findsOneWidget);
    });

    testWidgets('paste with no clipboard text shows snackbar', (tester) async {
      mockClipboard(tester, text: null);
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Clipboard does not contain text'), findsOneWidget);
    });

    testWidgets('paste with invalid json shows snackbar', (tester) async {
      mockClipboard(tester, text: 'not valid json');
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Clipboard does not contain valid alarm definition json'), findsOneWidget);
    });

    testWidgets('paste with valid json shows confirmation dialog', (tester) async {
      mockClipboard(tester, text: '[]');
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Load alarms from clipboard?'), findsOneWidget);
    });

    testWidgets('confirm paste updates settings and shows snackbar', (tester) async {
      mockClipboard(tester, text: '[]');
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(find.text('Pasted alarm definitions from clipboard'), findsOneWidget);
    });

    testWidgets('shows warning icon for valid warning alarm', (tester) async {
      alarmSettings.setAlarm(
        AlarmSpec('network', 'speedOverGround', 'warning', 'knots', min: 5.0),
      );
      await pumpPage(tester);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
  });

  group('EditAlarmsPage filtered to an element', () {
    late DataSet dataSet;
    late AlarmSettings alarmSettings;
    late FormatPreferences formatPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      alarmSettings = AlarmSettings(prefs);
      formatPrefs = FormatPreferences(prefs);
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        AlarmSettings(prefs),
        HistoryManagerImpl(prefs),
        AlarmManager(),
      );
    });

    Future<void> pumpPage(WidgetTester tester, {NavigatorObserver? observer}) async {
      final element = dataSet.find(Source.network, 'speedOverGround')!;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<AlarmSettings>.value(value: alarmSettings),
            ChangeNotifierProvider<FormatPreferences>.value(value: formatPrefs),
          ],
          child: MaterialApp(
            navigatorObservers: [?observer],
            home: EditAlarmsPage(element: element),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows an element-specific title', (tester) async {
      await pumpPage(tester);
      // speedOverGround.shortName is "SOG".
      expect(find.text('Edit SOG alarms'), findsOneWidget);
      expect(find.text('Edit alarms'), findsNothing);
    });

    testWidgets('hides copy and paste actions in filtered mode', (tester) async {
      await pumpPage(tester);
      expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
      expect(find.byIcon(Icons.content_paste_outlined), findsNothing);
    });

    testWidgets('lists only alarms for the matching element', (tester) async {
      // A matching alarm (network/speedOverGround) and a non-matching one (network/trueWindSpeed).
      alarmSettings.setAlarm(
        AlarmSpec('network', 'speedOverGround', 'warning', 'knots', min: 5.0),
      );
      alarmSettings.setAlarm(
        AlarmSpec('network', 'trueWindSpeed', 'caution', 'knots', min: 5.0),
      );
      await pumpPage(tester);

      // The matching warning alarm is shown (warning icon); the caution alarm for the
      // other element is filtered out (no info icon present).
      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.byIcon(Icons.info_outlined), findsNothing);
    });

    testWidgets('add alarm tile navigates to edit form with the fixed element', (tester) async {
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('Add new alarm'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });
  });
}
