// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_element.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditDerivedDataPage', () {
    late DataSet dataSet;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        HistoryManagerImpl(prefs),
      );
    });

    Future<void> pumpForm(
      WidgetTester tester,
      DerivedDataSpec? spec, {
      CreateDerivedDataFunction? onCreate,
      TestNavObserver? observer,
    }) async {
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
          providers: [ChangeNotifierProvider<DataSet>.value(value: dataSet)],
          child: MaterialApp(
            navigatorObservers: [?observer],
            home: EditDerivedDataPage(spec: spec, onCreate: onCreate ?? (_) {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows values from existing spec', (tester) async {
      final spec = DerivedDataSpec(
        'TestDerived',
        'network',
        'speedOverGround',
        'knots',
        'add',
        1.0,
      );
      await pumpForm(tester, spec);
      expect(find.text('TestDerived'), findsOneWidget);
      expect(find.text('Speed over ground'), findsOneWidget);
    });

    testWidgets('fails to save when name is empty', (tester) async {
      await pumpForm(tester, null);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Name must not be empty'), findsOneWidget);
    });

    testWidgets('fails to save when element is not set', (tester) async {
      // Spec with invalid element name; _wipeInvalidFields will nullify it.
      final spec = DerivedDataSpec('TestDerived', 'network', 'doesNotExist', 'knots', 'add', 0.0);
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Element must be set'), findsOneWidget);
    });

    testWidgets('SAVE calls onCreate and pops navigator', (tester) async {
      final spec = DerivedDataSpec(
        'TestDerived',
        'network',
        'speedOverGround',
        'knots',
        'add',
        0.0,
      );
      final observer = TestNavObserver();
      DerivedDataSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s, observer: observer);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, 1);
      expect(createdSpec?.name, 'TestDerived');
    });
  });
}
