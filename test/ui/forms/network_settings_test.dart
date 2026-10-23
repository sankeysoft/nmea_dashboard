// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/ui/forms/network_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkSettingsPage', () {
    late NetworkSettings settings;

    Future<void> pumpForm(
      WidgetTester tester, {
      Map<String, Object> initialPrefs = const {},
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

      SharedPreferences.setMockInitialValues(initialPrefs);
      settings = NetworkSettings(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [?observer],
          home: NetworkSettingsPage(settings: settings),
        ),
      );
      await tester.pump();
    }

    Switch getDefaultVariationSwitch(WidgetTester tester) => tester.widget(find.byType(Switch));

    TextField getDefaultVariationField(WidgetTester tester) =>
        tester.widget(find.widgetWithText(TextField, '0.0'));

    // The direction enum is private so we can't name the SegmentedButton's type parameter.
    bool isDirectionButtonEnabled(WidgetTester tester) {
      final dynamic button = tester.widget(find.byWidgetPredicate((w) => w is SegmentedButton));
      return button.onSelectionChanged != null;
    }

    Future<void> selectProtocol(WidgetTester tester, String text) async {
      await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    Future<void> saveForm(WidgetTester tester) async {
      await tester.tap(find.text('SAVE'));
      await tester.pump();
    }

    testWidgets('shows title', (tester) async {
      await pumpForm(tester);
      expect(find.text('Network settings'), findsOneWidget);
    });

    testWidgets('shows values from settings', (tester) async {
      await pumpForm(
        tester,
        initialPrefs: {
          'network_mode': NetworkMode.tcpConnect.index,
          'network_address': '10.0.0.5',
          'network_port': 3000,
          'network_protocol': NetworkProtocol.nmea2000ngt.index,
          'network_staleness_seconds': 30,
        },
      );
      expect(find.text('Connect to TCP port'), findsOneWidget);
      expect(find.text('10.0.0.5'), findsOneWidget);
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('NMEA2000 ActiSense NGT'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('shows NMEA0183 checksum setting in protocol', (tester) async {
      await pumpForm(tester, initialPrefs: {'network_checksum': false});
      expect(find.text('NMEA0183 (no checksum)'), findsOneWidget);
    });

    testWidgets('SAVE persists NMEA0183 without checksum', (tester) async {
      await pumpForm(tester);
      expect(find.text('NMEA0183 (checksum)'), findsOneWidget);
      await selectProtocol(tester, 'NMEA0183 (no checksum)');
      await saveForm(tester);
      expect(settings.protocol, NetworkProtocol.nmea0183);
      expect(settings.requireChecksum, isFalse);
    });

    testWidgets('SAVE persists NMEA0183 with checksum', (tester) async {
      await pumpForm(tester, initialPrefs: {'network_checksum': false});
      await selectProtocol(tester, 'NMEA0183 (checksum)');
      await saveForm(tester);
      expect(settings.protocol, NetworkProtocol.nmea0183);
      expect(settings.requireChecksum, isTrue);
    });

    testWidgets('fails to save when port is out of range', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.text('2000'), '0');
      await saveForm(tester);
      expect(find.text('Port must be between 1 and 65536'), findsOneWidget);
    });

    testWidgets('fails to save when IP address is invalid in TCP mode', (tester) async {
      await pumpForm(tester, initialPrefs: {'network_mode': NetworkMode.tcpConnect.index});
      await tester.enterText(find.text('192.168.4.1'), '999.1.1.1');
      await saveForm(tester);
      expect(
        find.text('IP address must be a valid IPv4 address such as 192.168.1.1'),
        findsOneWidget,
      );
    });

    testWidgets('SAVE persists values and pops navigator', (tester) async {
      final observer = TestNavObserver();
      await pumpForm(tester, observer: observer);

      await tester.enterText(find.text('2000'), '3000');
      await selectProtocol(tester, 'NMEA2000 ActiSense NGT');
      // Selecting from the dropdown menu pops its own route, so count only the save.
      final popsBefore = observer.popCount;
      await saveForm(tester);

      expect(observer.popCount, popsBefore + 1);
      expect(settings.port, 3000);
      expect(settings.protocol, NetworkProtocol.nmea2000ngt);
    });

    testWidgets('SAVE preserves checksum value when selecting NMEA2000', (tester) async {
      await pumpForm(tester, initialPrefs: {'network_checksum': false});
      await selectProtocol(tester, 'NMEA2000 ActiSense NGT');
      await saveForm(tester);

      expect(settings.protocol, NetworkProtocol.nmea2000ngt);
      expect(settings.requireChecksum, isFalse);
    });

    testWidgets('disables default variation fields until switch is enabled', (tester) async {
      await pumpForm(tester);
      expect(getDefaultVariationSwitch(tester).value, isFalse);
      expect(getDefaultVariationField(tester).enabled, isFalse);
      expect(isDirectionButtonEnabled(tester), isFalse);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(getDefaultVariationSwitch(tester).value, isTrue);
      expect(getDefaultVariationField(tester).enabled, isTrue);
      expect(isDirectionButtonEnabled(tester), isTrue);
    });

    testWidgets('validates default variation when enabled', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      const error = 'Must be between 0 and 30 with at most one decimal';

      for (final valid in ['0', '12.5', '30', '30.0']) {
        await tester.enterText(find.widgetWithText(TextField, '°'), valid);
        await tester.pump();
        expect(find.text(error), findsNothing, reason: valid);
      }
      for (final invalid in ['30.1', '-5', '1.25', '', '.']) {
        await tester.enterText(find.widgetWithText(TextField, '°'), invalid);
        await tester.pump();
        expect(find.text(error), findsOneWidget, reason: invalid);
      }
    });
  });
}
