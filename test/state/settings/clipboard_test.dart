// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';

void main() {
  test('encode then decode round-trips kind and data', () {
    for (final kind in ClipboardKind.values) {
      final text = encodeClipboard(kind, [
        {'a': 1},
      ]);
      expect(clipboardKind(text), kind);
      expect(clipboardData(text, kind), [
        {'a': 1},
      ]);
    }
  });

  test('clipboardData returns null for the wrong kind', () {
    final text = encodeClipboard(ClipboardKind.cell, {'a': 1});
    expect(clipboardData(text, ClipboardKind.page), isNull);
  });

  test('rejects text that is not a valid envelope', () {
    for (final text in [
      'not json',
      '[]',
      '"cell"',
      '{"data":{}}',
      '{"kind":"unknown","data":{}}',
      '{"kind":3,"data":{}}',
      '{"kind":"cell"}',
    ]) {
      expect(clipboardKind(text), isNull, reason: text);
      expect(clipboardData(text, ClipboardKind.cell), isNull, reason: text);
    }
  });
}
