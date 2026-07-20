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

    Switch getChecksumSwitch(WidgetTester tester) {
      final finder = find.byType(Switch);
      expect(finder, findsOneWidget);
      return tester.widget(finder);
    }

    Future<void> selectProtocol(WidgetTester tester, NetworkProtocol protocol) async {
      await tester.tap(find.byType(DropdownButtonFormField<NetworkProtocol>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(protocol.description).last);
      await tester.pumpAndSettle();
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

    testWidgets('enables checksum switch when protocol is NMEA0183', (tester) async {
      await pumpForm(tester);
      expect(getChecksumSwitch(tester).onChanged, isNotNull);
    });

    testWidgets('disables checksum switch when an NMEA2000 protocol is selected', (tester) async {
      await pumpForm(tester);
      await selectProtocol(tester, NetworkProtocol.nmea2000ngt);
      expect(getChecksumSwitch(tester).onChanged, isNull);

      await selectProtocol(tester, NetworkProtocol.nmea0183);
      expect(getChecksumSwitch(tester).onChanged, isNotNull);
    });

    testWidgets('fails to save when port is out of range', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.text('2000'), '0');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Port must be between 1 and 65536'), findsOneWidget);
    });

    testWidgets('fails to save when IP address is invalid in TCP mode', (tester) async {
      await pumpForm(tester, initialPrefs: {'network_mode': NetworkMode.tcpConnect.index});
      await tester.enterText(find.text('192.168.4.1'), '999.1.1.1');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(
        find.text('IP address must be a valid IPv4 address such as 192.168.1.1'),
        findsOneWidget,
      );
    });

    testWidgets('SAVE persists values and pops navigator', (tester) async {
      final observer = TestNavObserver();
      await pumpForm(tester, observer: observer);

      await tester.enterText(find.text('2000'), '3000');
      await selectProtocol(tester, NetworkProtocol.nmea2000ngt);
      // Selecting from the dropdown menu pops its own route, so count only the save.
      final popsBefore = observer.popCount;
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, popsBefore + 1);
      expect(settings.port, 3000);
      expect(settings.protocol, NetworkProtocol.nmea2000ngt);
    });

    testWidgets('SAVE preserves checksum value while switch is disabled', (tester) async {
      await pumpForm(tester);
      await selectProtocol(tester, NetworkProtocol.nmea2000ngt);
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(settings.protocol, NetworkProtocol.nmea2000ngt);
      expect(settings.requireChecksum, isTrue);
    });
  });
}
