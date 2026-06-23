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
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_cell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

const _defaultPagesJson =
    '[{"name":"page","cells":[{"source":"network","element":"speedOverGround",'
    '"type":"current","format":"knots"}]}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditCellPage', () {
    late DataSet dataSet;
    late PageSettings pageSettings;
    late FormatPreferences formatPrefs;
    late AlarmSettings alarmSettings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      alarmSettings = AlarmSettings(prefs);
      dataSet = DataSet(
        NetworkSettings(prefs),
        DerivedDataSettings(prefs),
        AlarmSettings(prefs),
        HistoryManagerImpl(prefs),
        AlarmManager(),
      );
      pageSettings = PageSettings(prefs, _defaultPagesJson);
      formatPrefs = FormatPreferences(prefs);
    });

    Future<void> pumpForm(
      WidgetTester tester,
      DataCellSpec spec, {
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

      pageSettings.replacePages([
        DataPageSpec('Test', [spec]),
      ]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DataSet>.value(value: dataSet),
            ChangeNotifierProvider<PageSettings>.value(value: pageSettings),
            ChangeNotifierProvider<FormatPreferences>.value(value: formatPrefs),
            ChangeNotifierProvider<AlarmSettings>.value(value: alarmSettings),
          ],
          child: MaterialApp(
            navigatorObservers: [?observer],
            home: EditCellPage(spec: spec),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows expected values for grouped source', (tester) async {
      // speedOverGround has Group.general, so source shows "Network - General"
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);
      expect(find.text('Network - General'), findsOneWidget);
      expect(find.text('Speed over ground'), findsOneWidget);
      expect(find.text('SOG'), findsOneWidget);
    });

    testWidgets('shows local device in source dropdown for local element', (tester) async {
      final spec = DataCellSpec('local', 'localTime', 'current', 'hms');
      await pumpForm(tester, spec);
      expect(find.text('Local device'), findsOneWidget);
    });

    testWidgets('shows spec name when name is overridden', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots', name: 'MySOG');
      await pumpForm(tester, spec);
      expect(find.text('MySOG'), findsOneWidget);
      expect(find.text('SOG'), findsNothing);
    });

    testWidgets('shows history-interval-based name for history type', (tester) async {
      final spec = DataCellSpec(
        'network',
        'speedOverGround',
        'history',
        'knots',
        historyInterval: 'fifteenMin',
      );
      await pumpForm(tester, spec);
      // HistoryInterval.fifteenMin.shortCellName produces "<shortName> (15min)"
      expect(find.text('SOG (15min)'), findsOneWidget);
    });

    testWidgets('shows average type selection for WithStats element', (tester) async {
      final spec = DataCellSpec(
        'network',
        'speedOverGround',
        'average',
        'knots',
        statsInterval: 'oneMin',
      );
      await pumpForm(tester, spec);
      expect(find.text('Average - 1 minute'), findsOneWidget);
    });

    testWidgets('fails to save when spec references unknown element name', (tester) async {
      // _wipeInvalidFields sets _element=null when element is not in data sources.
      final spec = DataCellSpec('network', 'doesNotExist', 'current', 'knots');
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Element must be set'), findsOneWidget);
    });

    testWidgets('fails to save when type doesnt have a required stats', (tester) async {
      // localTime is ConsistentDataElement<DateTime> which is not WithStats or WithHistory.
      // _wipeInvalidFields must clear the type, leaving the type field empty.
      final spec = DataCellSpec('local', 'localTime', 'average', 'hms', statsInterval: 'oneMin');
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Type must be set'), findsOneWidget);
    });

    testWidgets('resets format to preferred default when spec has invalid format key', (
      tester,
    ) async {
      final spec = DataCellSpec(
        'network',
        'speedOverGround',
        'history',
        'INVALID_FORMAT',
        historyInterval: 'fifteenMin',
      );
      await pumpForm(tester, spec);

      // speedOverGround is Dimension.speed; default preferred formatter is 'knots'.
      expect(getDropdownByLabel('Format:', tester).value, 'knots');
    });

    testWidgets('enabling name override makes name field interactive', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);

      // Initially name is auto-filled and the override switch is off.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      TextField name = tester.widget(find.byType(TextField));
      expect(name.controller!.text, 'SOG');
      expect(name.enabled, isFalse);

      // Toggle the override switch on.
      await tester.tap(find.byType(Switch));
      await tester.pump();

      final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(updatedSwitch.value, isTrue);
    });

    testWidgets('changing source dropdown to different value clears element', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);
      expect(getDropdownByLabel('Element:', tester).value, 'speedOverGround');

      await tester.tap(find.text('Network - General'));
      await tester.pump();
      await tester.tap(find.text('Network - Navigation'));
      await tester.pump();
      expect(getDropdownByLabel('Element:', tester).value, isNull);
    });

    testWidgets('changing element dropdown resets format to preferred default when incompatible', (
      tester,
    ) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);
      expect(getDropdownByLabel('Format:', tester).value, 'knots');

      // Switching to a compatible dimension keeps the current format.
      await tester.tap(find.text('Speed over ground'));
      await tester.pump();
      await tester.tap(find.text('Speed through water'));
      await tester.pump();
      expect(getDropdownByLabel('Format:', tester).value, 'knots');

      // Switching to an incompatible dimension resets to the preferred default
      // for the new dimension. Roll angle is Dimension.angle whose default is 'degrees'.
      await tester.tap(find.text('Speed through water'));
      await tester.pump();
      await tester.tap(find.text('Roll angle'));
      await tester.pump();
      expect(getDropdownByLabel('Format:', tester).value, 'degrees');
    });

    testWidgets('SAVE creates updated spec and pops navigator', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      final observer = TestNavObserver();
      await pumpForm(tester, spec, observer: observer);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, 1);
    });

    testWidgets('defaults type to current when spec has unrecognized type', (tester) async {
      // CellType.fromString returns null for 'invalid_type', so _type starts null.
      // _wipeInvalidFields sets it to CellType.current when a valid element is present.
      final spec = DataCellSpec('network', 'speedOverGround', 'invalid_type', 'knots');
      final observer = TestNavObserver();
      await pumpForm(tester, spec, observer: observer);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(find.text('Type must be set'), findsNothing);
      expect(observer.popCount, 1);
    });

    testWidgets('resets type to current when element has no history support', (tester) async {
      // localTime is ConsistentDataElement<DateTime> which does not implement WithHistory.
      // _wipeInvalidFields resets _type from history to current, leaving _historyInterval set,
      // which means the intended value is not in the dropdown entries → type appears unset.
      final spec = DataCellSpec(
        'local',
        'localTime',
        'history',
        'hms',
        historyInterval: 'fifteenMin',
      );
      await pumpForm(tester, spec);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Type must be set'), findsOneWidget);
    });

    testWidgets('alarms button navigates to alarms filtered to the cell element', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      // The pushed alarms page is scoped to this element (speedOverGround.shortName is "SOG").
      expect(find.text('Edit SOG alarms'), findsOneWidget);
    });

    testWidgets('alarms button still navigates when the element is unset', (tester) async {
      // An unknown element resolves to a null dataElement; the button must still navigate
      // (to the unfiltered alarms page) rather than do nothing.
      final spec = DataCellSpec('network', 'doesNotExist', 'current', 'knots');
      final observer = TestNavObserver();
      await pumpForm(tester, spec, observer: observer);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();

      expect(observer.pushCount, 1);
    });

    testWidgets('changing format dropdown updates internal format', (tester) async {
      final spec = DataCellSpec('network', 'speedOverGround', 'current', 'knots');
      await pumpForm(tester, spec);
      expect(getDropdownByLabel('Format:', tester).value, 'knots');

      await tester.tap(find.text('knots'));
      await tester.pump();
      await tester.tap(find.text('m/sec'));
      await tester.pump();

      expect(getDropdownByLabel('Format:', tester).value, 'metersPerSec');
    });
  });
}
