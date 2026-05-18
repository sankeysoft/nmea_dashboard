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

const _emptyPagesJson = '[]';

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

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<PageSettings>.value(value: pageSettings),
          ],
          child: MaterialApp(home: EditPagesPage()),
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
  });
}
