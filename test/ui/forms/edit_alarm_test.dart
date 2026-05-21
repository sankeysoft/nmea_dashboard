// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/data_element_history.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarm.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditAlarmPage', () {
    late DataSet dataSet;
    late FormatPreferences formatPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        HistoryManagerImpl(prefs),
      );
      formatPrefs = FormatPreferences(prefs);
    });

    Future<void> pumpForm(
      WidgetTester tester,
      AlarmSpec? spec, {
      CreateAlarmFunction? onCreate,
      TestNavObserver? observer,
    }) async {
      // DropdownButtonFormField renders all items off-screen for accessibility, which
      // causes layout overflow assertions in narrow test environments. Suppress them.
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
            ChangeNotifierProvider<FormatPreferences>.value(value: formatPrefs),
          ],
          child: MaterialApp(
            navigatorObservers: [?observer],
            home: EditAlarmPage(spec: spec, onCreate: onCreate ?? (_) {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows correct title', (tester) async {
      await pumpForm(tester, null);
      expect(find.text('Edit alarm'), findsOneWidget);
    });

    testWidgets('shows element name and min/max values from existing spec', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots', min: 5.0, max: 30.5);
      await pumpForm(tester, spec);
      expect(find.text('Speed over ground'), findsOneWidget);
      // NumberFormat("0.##") formats 5.0 as "5" and 30.5 as "30.5".
      expect(find.text('5'), findsOneWidget);
      expect(find.text('30.5'), findsOneWidget);
    });

    testWidgets('shows network group text for network element', (tester) async {
      // speedOverGround has Group.general, so source should show "Network - General".
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots', min: 2.0);
      await pumpForm(tester, spec);
      expect(find.text('Network - General'), findsOneWidget);
    });

    testWidgets('changing source group clears the element selection', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots', min: 2.0);
      await pumpForm(tester, spec);
      expect(find.text('Speed over ground'), findsOneWidget);

      await tester.tap(find.text('Network - General'));
      await tester.pump();
      await tester.tap(find.text('Network - Environment'));
      await tester.pump();
      expect(find.text('Speed over ground'), findsNothing);
    });

    testWidgets('fails to save when element references unknown name', (tester) async {
      final spec = AlarmSpec('network', 'doesNotExist', 'caution', 'knots', max: 20.0);
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Element must be set'), findsOneWidget);
    });

    testWidgets('fails to save when both min and max are unset', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots');
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      // Both the min and max field validators report this error.
      expect(find.text('Below and/or above must be set'), findsAtLeastNWidgets(1));
    });

    testWidgets('fails to save when max is not greater than min', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots', min: 5.0, max: 3.0);
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Above must be greater than below'), findsAtLeastNWidgets(1));
    });

    testWidgets('fails to save when bearing alarm has only one bound', (tester) async {
      // courseOverGround is Dimension.bearing; both bounds are required for bearings.
      final spec = AlarmSpec('network', 'courseOverGround', 'caution', 'true', min: 45.0);
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Below and above must be set for bearings'), findsAtLeastNWidgets(1));
    });

    testWidgets('fails to save when bearing alarm has equal bounds', (tester) async {
      final spec = AlarmSpec(
        'network',
        'courseOverGround',
        'caution',
        'true',
        min: 45.0,
        max: 45.0,
      );
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Above must not equal below'), findsAtLeastNWidgets(1));
    });

    testWidgets('fails to save when min is below the formatter minimum', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'warning', 'knots', min: -10.0);
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Must be ≥ 0'), findsOneWidget);
    });

    testWidgets('fails to save when max is above the formatter maximum', (tester) async {
      final spec = AlarmSpec(
        'network',
        'courseOverGround',
        'caution',
        'true',
        min: 45.0,
        max: 400.0,
      );
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Must be ≤ 359.9'), findsOneWidget);
    });

    testWidgets('SAVE calls onCreate with correct fields and pops navigator', (tester) async {
      final spec = AlarmSpec('network', 'speedOverGround', 'caution', 'knots', min: 2.0, max: 15.0);
      final observer = TestNavObserver();
      AlarmSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s, observer: observer);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, 1);
      expect(createdSpec?.source, 'network');
      expect(createdSpec?.element, 'speedOverGround');
      expect(createdSpec?.type, 'caution');
      expect(createdSpec?.format, 'knots');
      expect(createdSpec?.min, 2.0);
      expect(createdSpec?.max, 15.0);
    });

    testWidgets('SAVE preserves the spec key on update', (tester) async {
      final spec = AlarmSpec('network', 'trueWindSpeed', 'caution', 'knots', max: 30.0);
      AlarmSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(createdSpec?.key, spec.key);
    });

    testWidgets('sound is omitted from the created spec for caution type', (tester) async {
      final spec = AlarmSpec(
        'network',
        'trueWindSpeed',
        'caution',
        'knots',
        max: 30.0,
        sound: 'alarm.mp3',
      );
      AlarmSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(createdSpec?.sound, isNull);
    });

    testWidgets('sound is included in the created spec for warning type', (tester) async {
      final spec = AlarmSpec(
        'network',
        'trueWindSpeed',
        'warning',
        'knots',
        max: 30.0,
        sound: 'alarm.mp3',
      );
      AlarmSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(createdSpec?.sound, 'alarm.mp3');
    });
  });
}
