// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:nmea_dashboard/ui/cells/current_value_cell.dart';

import '../utils.dart';

void main() {
  // apparentWindSpeed: shortName='AWS', dimension=speed (SingleValue<double> in m/s).
  const source = Source.network;
  const property = Property.apparentWindSpeed;
  const formatName = 'knots';
  final formatter = formattersFor(property.dimension)['knots']! as SimpleFormatter;

  ConsistentDataElement<SingleValue<double>> makeTestElement({double? initialSpeedMs}) {
    // Null staleness: no timer is scheduled, so tests don't leave pending timers.
    final element = ConsistentDataElement<SingleValue<double>>(source, property, null);
    if (initialSpeedMs != null) {
      element.updateValue(BoundValue(source, property, SingleValue(initialSpeedMs)));
    }
    return element;
  }

  DataCellSpec makeTestSpec({String? name}) =>
      DataCellSpec(source.name, property.name, 'current', formatName, name: name);

  Future<void> pumpCell(
    WidgetTester tester,
    CurrentValueCell cell, {
    TestNavObserver? observer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [?observer],
        home: Scaffold(
          body: SizedBox(width: 200, height: 150, child: Row(children: [cell])),
        ),
      ),
    );
  }

  group('CurrentValueCell', () {
    testWidgets('uses defaults when not overridden in spec', (tester) async {
      await pumpCell(
        tester,
        CurrentValueCell(element: makeTestElement(), formatter: formatter, spec: makeTestSpec()),
      );
      expect(find.text(property.shortName), findsOneWidget);
      expect(find.text(formatter.units!), findsOneWidget);
      expect(find.text(formatter.invalid), findsOneWidget);
    });

    testWidgets('uses spec name as heading when spec overrides it', (tester) async {
      await pumpCell(
        tester,
        CurrentValueCell(
          element: makeTestElement(),
          formatter: formatter,
          spec: makeTestSpec(name: 'MyAWS'),
        ),
      );
      expect(find.text('MyAWS'), findsOneWidget);
      expect(find.text(property.shortName), findsNothing);
    });

    testWidgets('displays formatted value when element has data', (tester) async {
      await pumpCell(
        tester,
        CurrentValueCell(
          element: makeTestElement(initialSpeedMs: 10.0 / metersPerSecondToKnots),
          formatter: formatter,
          spec: makeTestSpec(),
        ),
      );
      expect(find.text('10.0'), findsOneWidget);
    });

    testWidgets('updates display when element receives a new value', (tester) async {
      final element = makeTestElement();
      await pumpCell(
        tester,
        CurrentValueCell(element: element, formatter: formatter, spec: makeTestSpec()),
      );
      expect(find.text(formatter.invalid), findsOneWidget);

      element.updateValue(BoundValue(source, property, SingleValue(10.0 / metersPerSecondToKnots)));
      await tester.pump();
      expect(find.text('10.0'), findsOneWidget);
    });

    testWidgets('reverts to invalid placeholder when element is invalidated', (tester) async {
      final element = makeTestElement(initialSpeedMs: 10.0 / metersPerSecondToKnots);
      await pumpCell(
        tester,
        CurrentValueCell(element: element, formatter: formatter, spec: makeTestSpec()),
      );
      expect(find.text('10.0'), findsOneWidget);

      element.invalidateValue();
      await tester.pump();
      expect(find.text(formatter.invalid), findsOneWidget);
    });

    testWidgets('long press triggers navigation', (tester) async {
      final observer = TestNavObserver();
      await pumpCell(
        tester,
        CurrentValueCell(element: makeTestElement(), formatter: formatter, spec: makeTestSpec()),
        observer: observer,
      );
      // observer.pushCount is 1 here from the initial home route push.

      // EditCellPage needs DataSet and PageSettings providers which are impractical
      // to construct in a unit test (they start stream timers). Suppress the resulting
      // ProviderNotFoundException so we can still verify navigation was triggered.
      FlutterError.onError = (_) {};
      await tester.longPress(find.byType(GestureDetector).first);
      FlutterError.onError = FlutterError.presentError;

      expect(observer.pushCount, 2);
    });
  });
}
