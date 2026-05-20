// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/data/data_element_history.dart';
import 'package:nmea_dashboard/state/data/data_set.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_pages.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

const _emptyPagesJson = '[]';
// Valid page JSON (minimum one page required for useClipboard to accept).
const _validPagesJson = '[{"name":"TestPage","cells":[]}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditPagesPage', () {
    late DataSet dataSet;
    late PageSettings pageSettings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        HistoryManagerImpl(prefs),
      );
      pageSettings = PageSettings(prefs, _emptyPagesJson);
    });

    Future<void> pumpPage(WidgetTester tester, {NavigatorObserver? observer}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<PageSettings>.value(value: pageSettings),
          ],
          child: MaterialApp(navigatorObservers: [?observer], home: EditPagesPage()),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows title and add page tile', (tester) async {
      await pumpPage(tester);
      expect(find.text('Edit pages'), findsOneWidget);
      expect(find.text('Add new page'), findsOneWidget);
    });

    testWidgets('shows existing pages', (tester) async {
      pageSettings.setPage(DataPageSpec('MyPage', []));
      await pumpPage(tester);
      expect(find.text('MyPage'), findsOneWidget);
    });

    testWidgets('delete tap shows confirmation dialog', (tester) async {
      pageSettings.setPage(DataPageSpec('MyPage', []));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('Delete MyPage page?'), findsOneWidget);
    });

    testWidgets('confirm delete removes page', (tester) async {
      pageSettings.setPage(DataPageSpec('MyPage', []));
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(pageSettings.dataPageSpecs, isEmpty);
    });

    testWidgets('tapping page tile navigates to edit form', (tester) async {
      pageSettings.setPage(DataPageSpec('MyPage', []));
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('MyPage'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('tapping add page tile navigates to edit form', (tester) async {
      final observer = TestNavObserver();
      await pumpPage(tester, observer: observer);

      await tester.tap(find.text('Add new page'));
      await tester.pump();

      expect(observer.pushCount, greaterThan(0));
    });

    testWidgets('reset button shows confirmation dialog', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.settings_backup_restore_outlined));
      await tester.pump();

      expect(find.text('Reset to default?'), findsOneWidget);
    });

    testWidgets('confirm reset shows snackbar', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.settings_backup_restore_outlined));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(find.text('Reset page definitions to default'), findsOneWidget);
    });

    testWidgets('copy button shows snackbar', (tester) async {
      mockClipboard(tester);
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Page definitions copied to clipboard'), findsOneWidget);
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

      expect(find.text('Clipboard does not contain valid page definition json'), findsOneWidget);
    });

    testWidgets('paste with valid json shows confirmation dialog', (tester) async {
      mockClipboard(tester, text: _validPagesJson);
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.content_paste_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.text('Load pages from clipboard?'), findsOneWidget);
    });
  });
}
