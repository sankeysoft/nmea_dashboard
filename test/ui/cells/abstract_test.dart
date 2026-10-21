// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:nmea_dashboard/ui/cells/current_value_cell.dart';
import 'package:nmea_dashboard/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmptyCell', () {
    testWidgets('renders with no contents and no GestureDetector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, height: 100, child: Row(children: [EmptyCell()])),
          ),
        ),
      );
      expect(find.byType(EmptyCell), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('SpecCell alarm theming', () {
    testWidgets('reacts to alarmState transitions', (tester) async {
      SharedPreferences.setMockInitialValues({'ui_dark_theme': true});
      final settings = UiSettings(await SharedPreferences.getInstance());

      // SingleValueDoubleConsistentDataElement has WithAlarms, so CurrentValueCell
      // forwards element.alarmState into the SpecCell.
      final element =
          ConsistentDataElement.newForProperty(
                Source.network,
                Property.depthWithOffset,
                Staleness(const Duration(seconds: 10)),
              )
              as SingleValueDoubleConsistentDataElement;
      final formatter = formattersFor(Property.depthWithOffset.dimension)['feet']!;
      final spec = DataCellSpec('network', 'depthWithOffset', 'current', 'feet');

      await tester.pumpWidget(
        ChangeNotifierProvider<UiSettings>.value(
          value: settings,
          child: MaterialApp(
            theme: createThemeData(settings),
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 150,
                child: Row(
                  children: [CurrentValueCell(element: element, formatter: formatter, spec: spec)],
                ),
              ),
            ),
          ),
        ),
      );

      Color surfaceColor() {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(CurrentValueCell),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.margin == const EdgeInsets.all(6.0),
            ),
          ),
        );
        return (container.decoration as BoxDecoration).color!;
      }

      // Baseline: alarm level null → ambient dark theme midBackground.
      expect(surfaceColor(), Colors.grey.shade900);

      // Transition to caution → themed branch overrides surface with caution color.
      element.alarmState.set(AlarmLevel.caution);
      await tester.pump();
      expect(surfaceColor(), Colors.yellow.shade600);

      // Back to null → reverts to ambient surface.
      element.alarmState.set(null);
      await tester.pump();
      expect(surfaceColor(), Colors.grey.shade900);
    });
  });

  group('HeadingContentsCell heading size', () {
    Future<UiSettings> pumpLargeCell(WidgetTester tester, Map<String, Object> prefs) async {
      // Use a cell big enough that the heading height is limited by the max heading setting.
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(prefs);
      final settings = UiSettings(await SharedPreferences.getInstance());
      final element = ConsistentDataElement.newForProperty(
        Source.network,
        Property.depthWithOffset,
        Staleness(const Duration(seconds: 10)),
      );
      final formatter = formattersFor(Property.depthWithOffset.dimension)['feet']!;
      final spec = DataCellSpec('network', 'depthWithOffset', 'current', 'feet', name: 'HEAD');

      await tester.pumpWidget(
        ChangeNotifierProvider<UiSettings>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [CurrentValueCell(element: element, formatter: formatter, spec: spec)],
              ),
            ),
          ),
        ),
      );
      return settings;
    }

    double headingHeight(WidgetTester tester) => tester
        .getSize(find.ancestor(of: find.text('HEAD'), matching: find.byType(FittedBox)))
        .height;

    for (final size in HeadingSize.values) {
      testWidgets('limits heading to ${size.maxHeight} for ${size.name}', (tester) async {
        await pumpLargeCell(tester, {'ui_max_heading_height': size.maxHeight});
        expect(headingHeight(tester), size.maxHeight.toDouble());
      });
    }

    testWidgets('relayouts when the setting changes', (tester) async {
      final settings = await pumpLargeCell(tester, {});
      expect(headingHeight(tester), 48.0);
      settings.setMaxHeading(HeadingSize.large);
      await tester.pump();
      expect(headingHeight(tester), 96.0);
      settings.setMaxHeading(HeadingSize.small);
      await tester.pump();
      expect(headingHeight(tester), 24.0);
    });
  });
}
