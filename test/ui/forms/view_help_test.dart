// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/ui/forms/view_help.dart';

import '../utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewHelpPage', () {
    // rootBundle caches asset futures across tests; evict so each test gets a fresh load.
    setUp(() => rootBundle.evict('assets/help/edit_cell.md'));

    Future<void> pumpPage(
      WidgetTester tester, {
      String filename = 'edit_cell.md',
      String title = 'Help',
      bool linkToReleaseNotes = false,
      NavigatorObserver? observer,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [?observer],
          home: ViewHelpPage(
            filename: filename,
            title: title,
            linkToReleaseNotes: linkToReleaseNotes,
          ),
        ),
      );
    }

    testWidgets('shows given title', (tester) async {
      await pumpPage(tester, title: 'Cell Help');
      expect(find.text('Cell Help'), findsOneWidget);
    });

    testWidgets('shows spinner before content loads', (tester) async {
      await pumpPage(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows CLOSE button after loading', (tester) async {
      await pumpPage(tester);
      // runAsync lets the rootBundle platform channel call complete outside fake-async,
      // then pump builds the final FutureBuilder state.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('shows VERSIONS and CLOSE when linkToReleaseNotes is true', (tester) async {
      await pumpPage(tester, linkToReleaseNotes: true);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('VERSIONS'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('CLOSE button pops navigator', (tester) async {
      final observer = TestNavObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder:
                (context) => ElevatedButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ViewHelpPage(filename: 'edit_cell.md', title: 'Help'),
                        ),
                      ),
                  child: const Text('Open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('CLOSE'));
      await tester.pump();
      expect(observer.popCount, 1);
    });
  });
}
