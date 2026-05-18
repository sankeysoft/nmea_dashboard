// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:nmea_dashboard/ui/forms/view_release_notes.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PackageInfo _fakePackageInfo(String version) {
  return PackageInfo(
    appName: 'test',
    packageName: 'com.test',
    version: version,
    buildNumber: '1',
    buildSignature: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewReleaseNotesPage', () {
    late Settings settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settings = Settings(prefs, '[]', _fakePackageInfo('0.4.2'));
    });

    Future<void> pumpPage(WidgetTester tester, {required bool displayAll}) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<Settings>.value(
          value: settings,
          child: MaterialApp(home: ViewReleaseNotesPage(displayAll: displayAll)),
        ),
      );
    }

    testWidgets('shows Release Notes title when displaying all', (tester) async {
      await pumpPage(tester, displayAll: true);
      expect(find.text('Release Notes'), findsOneWidget);
    });

    testWidgets("shows What's New title when not displaying all", (tester) async {
      await pumpPage(tester, displayAll: false);
      expect(find.text("What's New"), findsOneWidget);
    });

    testWidgets('shows spinner before content loads', (tester) async {
      await pumpPage(tester, displayAll: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows content and no spinner after loading', (tester) async {
      await pumpPage(tester, displayAll: false);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('CLOSE'), findsOneWidget);
    });
  });

  test('release notes asset exists for current app version', () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s+(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'Could not parse version from pubspec.yaml');
    final version = match!.group(1)!;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
      manifest.listAssets(),
      contains('assets/rel_notes/$version.md'),
      reason: 'No release notes asset found for version $version',
    );
  });
}
