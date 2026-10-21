// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_page.dart';

import '../utils.dart';

DataCellSpec _makeCell() => DataCellSpec('network', 'speedOverGround', 'current', 'knots');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditPagePage', () {
    Future<void> pumpForm(
      WidgetTester tester,
      DataPageSpec? spec, {
      CreatePageSpecFunction? onCreate,
      TestNavObserver? observer,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [?observer],
          home: EditPagePage(pageSpec: spec, onCreate: onCreate ?? (_) {}),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows title', (tester) async {
      await pumpForm(tester, null);
      expect(find.text('Edit page'), findsOneWidget);
    });

    testWidgets('shows default cell count for new page', (tester) async {
      await pumpForm(tester, null);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('shows existing spec values', (tester) async {
      final spec = DataPageSpec('MyPage', List.generate(5, (_) => _makeCell()));
      await pumpForm(tester, spec);
      expect(find.text('MyPage'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('fails to save when name is empty', (tester) async {
      await pumpForm(tester, null);
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Name must not be empty'), findsOneWidget);
    });

    testWidgets('fails to save when cell count is zero', (tester) async {
      final spec = DataPageSpec('MyPage', [_makeCell()]);
      await pumpForm(tester, spec);
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      // Note: error message says "Port" — copy-paste bug from another form.
      expect(find.text('Count must be between 1 and 65'), findsOneWidget);
    });

    testWidgets('fails to save when cell count exceeds maximum', (tester) async {
      final spec = DataPageSpec('MyPage', [_makeCell()]);
      await pumpForm(tester, spec);
      await tester.enterText(find.byType(TextFormField).at(1), '65');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Count must be between 1 and 65'), findsOneWidget);
    });

    testWidgets('SAVE calls onCreate and pops navigator', (tester) async {
      final spec = DataPageSpec('MyPage', [_makeCell()]);
      final observer = TestNavObserver();
      DataPageSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s, observer: observer);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(observer.popCount, 1);
      expect(createdSpec?.name, 'MyPage');
    });

    testWidgets('SAVE preserves original key', (tester) async {
      final spec = DataPageSpec('MyPage', [_makeCell()]);
      final originalKey = spec.key;
      DataPageSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(createdSpec?.key, originalKey);
    });

    testWidgets('SAVE truncates cells when size is reduced', (tester) async {
      final cells = List.generate(5, (_) => _makeCell());
      final spec = DataPageSpec('MyPage', cells);
      DataPageSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(createdSpec?.cells.length, 3);
      for (int i = 0; i < 3; i++) {
        expect(createdSpec?.cells[i].key, cells[i].key);
      }
    });

    testWidgets('SAVE appends new cells when size is increased', (tester) async {
      final cells = List.generate(3, (_) => _makeCell());
      final spec = DataPageSpec('MyPage', cells);
      DataPageSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(createdSpec?.cells.length, 5);
      for (int i = 0; i < 3; i++) {
        expect(createdSpec?.cells[i].key, cells[i].key);
      }
    });

    Future<void> tapAndSettle(WidgetTester tester, IconData icon) async {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('copy copies the current unsaved form contents', (tester) async {
      String? copied;
      mockClipboard(tester, onSet: (text) => copied = text);
      await pumpForm(tester, DataPageSpec('MyPage', List.generate(3, (_) => _makeCell())));

      await tester.enterText(find.byType(TextFormField).at(0), 'Renamed');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tapAndSettle(tester, Icons.copy_all_outlined);

      expect(find.text('Page definition copied to clipboard'), findsOneWidget);
      final decoded = json.decode(copied!);
      expect(decoded['kind'], 'page');
      expect(decoded['data']['name'], 'Renamed');
      expect(decoded['data']['cells'].length, 2);
      expect(decoded['data']['cells'][0]['element'], 'speedOverGround');
    });

    testWidgets('copy of an incomplete form shows snackbar', (tester) async {
      String? copied;
      mockClipboard(tester, onSet: (text) => copied = text);
      await pumpForm(tester, null);

      await tapAndSettle(tester, Icons.copy_all_outlined);

      expect(find.text('Complete the page definition before copying'), findsOneWidget);
      expect(copied, isNull);
    });

    testWidgets('paste with a cell definition shows snackbar', (tester) async {
      mockClipboard(tester, text: PageSettings.cellToClipboard(_makeCell()));
      await pumpForm(tester, null);

      await tapAndSettle(tester, Icons.content_paste_outlined);

      expect(
        find.text('Clipboard contains a cell definition, not a page definition'),
        findsOneWidget,
      );
    });

    testWidgets('paste updates fields immediately and SAVE uses pasted cells', (tester) async {
      final pasted = DataPageSpec('Pasted', [
        DataCellSpec('local', 'localTime', 'current', 'hms'),
        _makeCell(),
        _makeCell(),
      ]);
      mockClipboard(tester, text: PageSettings.pageToClipboard(pasted));
      final spec = DataPageSpec('MyPage', [_makeCell()]);
      DataPageSpec? createdSpec;
      await pumpForm(tester, spec, onCreate: (s) => createdSpec = s);

      await tapAndSettle(tester, Icons.content_paste_outlined);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Pasted a page definition from clipboard'), findsOneWidget);
      expect(find.text('Pasted'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(createdSpec, isNull);

      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.tap(find.text('SAVE'));
      await tester.pump();

      expect(createdSpec?.key, spec.key);
      expect(createdSpec?.name, 'Pasted');
      expect(createdSpec?.cells.length, 2);
      expect(createdSpec?.cells[0].element, 'localTime');
    });
  });
}
