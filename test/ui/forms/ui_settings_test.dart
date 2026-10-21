// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:nmea_dashboard/ui/forms/ui_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Satisfy the wakelock Pigeon channel so setKeepScreenAwake() doesn't throw.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  });

  group('UiSettingsPage', () {
    late UiSettings settings;

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
      settings = UiSettings(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [?observer],
          home: UiSettingsPage(settings: settings),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows max heading below heading font', (tester) async {
      await pumpForm(tester);
      final headingFontY = tester.getTopLeft(find.text('Heading font:')).dy;
      final maxHeadingY = tester.getTopLeft(find.text('Max heading:')).dy;
      expect(maxHeadingY, greaterThan(headingFontY));
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('shows max heading value from settings', (tester) async {
      await pumpForm(tester, initialPrefs: {'ui_max_heading_height': 24});
      expect(find.text('Small'), findsOneWidget);
    });

    testWidgets('SAVE persists max heading and pops navigator', (tester) async {
      final observer = TestNavObserver();
      await pumpForm(tester, observer: observer);

      await tester.tap(find.byType(DropdownButtonFormField<HeadingSize>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large').last);
      await tester.pumpAndSettle();
      // Selecting from the dropdown menu pops its own route, so count only the save.
      final popsBefore = observer.popCount;
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, popsBefore + 1);
      expect(settings.maxHeading, HeadingSize.large);
    });
  });
}
