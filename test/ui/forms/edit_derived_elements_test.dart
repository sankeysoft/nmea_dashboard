// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_elements.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditDerivedElementsPage', () {
    late DataSet dataSet;
    late DerivedDataSettings derivedDataSettings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      derivedDataSettings = DerivedDataSettings(prefs);
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
            ChangeNotifierProvider<DerivedDataSettings>.value(value: derivedDataSettings),
          ],
          child: MaterialApp(navigatorObservers: [?observer], home: EditDerivedElementsPage()),
        ),
      );
      await tester.pump();
    }

    DerivedDataSpec makeSpec(String name) =>
        DerivedDataSpec(name, 'network', 'speedOverGround', 'knots', 'add', 0.0);

    testWidgets('shows title and add element tile', (tester) async {
      await pumpPage(tester);
      expect(find.text('Edit derived elements'), findsOneWidget);
      expect(find.text('Add new element'), findsOneWidget);
    });

    testWidgets('shows existing derived elements', (tester) async {
      derivedDataSettings.setElement(makeSpec('MyDerived'));
      await pumpPage(tester);
      expect(find.text('MyDerived'), findsOneWidget);
    });

    testWidgets('delete tap shows confirmation dialog', (tester) async {
      derivedDataSettings.setElement(makeSpec('MyDerived'));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('Delete MyDerived element?'), findsOneWidget);
    });

    testWidgets('confirm delete removes element', (tester) async {
      derivedDataSettings.setElement(makeSpec('MyDerived'));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(derivedDataSettings.derivedDataSpecs, isEmpty);
    });

    testWidgets('tapping element tile navigates to edit form', (tester) async {
      derivedDataSettings.setElement(makeSpec('MyDerived'));
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('MyDerived'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('tapping add element tile navigates to edit form', (tester) async {
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('Add new element'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('copy button shows snackbar', (tester) async {
      mockClipboard(tester);
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Derived data definitions copied to clipboard'), findsOneWidget);
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

      expect(find.text('Clipboard does not contain valid data definition json'), findsOneWidget);
    });

    testWidgets('paste with valid json shows confirmation dialog', (tester) async {
      mockClipboard(tester, text: '[]');
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Load derived data from clipboard?'), findsOneWidget);
    });

    testWidgets('confirm paste updates settings and shows snackbar', (tester) async {
      mockClipboard(tester, text: '[]');
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(find.text('Pasted derived data definitions from clipboard'), findsOneWidget);
    });
  });
}
