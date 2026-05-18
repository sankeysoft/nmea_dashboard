// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/data/data_element_history.dart';
import 'package:nmea_dashboard/state/data/data_set.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_elements.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        HistoryManagerImpl(prefs),
      );
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<DerivedDataSettings>.value(value: derivedDataSettings),
          ],
          child: MaterialApp(home: EditDerivedElementsPage()),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows title and add element tile', (tester) async {
      await pumpPage(tester);
      expect(find.text('Edit derived elements'), findsOneWidget);
      expect(find.text('Add new element'), findsOneWidget);
    });

    testWidgets('shows existing derived elements', (tester) async {
      derivedDataSettings.setElement(
        DerivedDataSpec('MyDerived', 'network', 'speedOverGround', 'knots', 'add', 0.0),
      );
      await pumpPage(tester);
      expect(find.text('MyDerived'), findsOneWidget);
    });

    testWidgets('delete tap shows confirmation dialog', (tester) async {
      derivedDataSettings.setElement(
        DerivedDataSpec('MyDerived', 'network', 'speedOverGround', 'knots', 'add', 0.0),
      );
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(find.text('Delete MyDerived element?'), findsOneWidget);
    });
  });
}
