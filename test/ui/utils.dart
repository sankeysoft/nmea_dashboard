// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestNavObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
  }
}

DropdownButton<String> getDropdownByLabel(String label, WidgetTester tester) {
  final finder = find.ancestor(of: find.text(label), matching: find.byType(DropdownButton<String>));
  expect(finder, findsOneWidget);
  return tester.widget(finder);
}
