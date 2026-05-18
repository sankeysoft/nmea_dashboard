// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Mocks the clipboard platform channel for the duration of a test.
/// Pass [text] to simulate text on the clipboard, or omit it for an empty
/// clipboard. Automatically restores the real handler on teardown.
void mockClipboard(WidgetTester tester, {String? text}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'Clipboard.setData':
          return null;
        case 'Clipboard.getData':
          return text != null ? <String, dynamic>{'text': text} : null;
        default:
          return null;
      }
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}

DropdownButton<String> getDropdownByLabel(String label, WidgetTester tester) {
  final finder = find.ancestor(of: find.text(label), matching: find.byType(DropdownButton<String>));
  expect(finder, findsOneWidget);
  return tester.widget(finder);
}
