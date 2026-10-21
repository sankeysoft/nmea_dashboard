// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:logging/logging.dart';

final _log = Logger('Clipboard');

/// The kinds of data that may be copied to and pasted from the clipboard. Clipboard text is a
/// json object containing the kind and the data, so a paste of the wrong kind can be detected.
enum ClipboardKind {
  pages('Page definitions', 'page definitions', 'page'),
  page('Page definition', 'a page definition', 'page'),
  cell('Cell definition', 'a cell definition', 'cell'),
  alarms('Alarm definitions', 'alarm definitions', 'alarm'),
  derivedData('Derived data definitions', 'derived data definitions', 'derived data');

  /// A capitalized description, suitable for the start of a sentence.
  final String title;

  /// A description suitable for the middle of a sentence.
  final String description;

  /// A short name for the type of definition.
  final String shortName;

  const ClipboardKind(this.title, this.description, this.shortName);

  /// Returns a clipboard kind from its unqualified name.
  static ClipboardKind? fromString(String? name) {
    return ClipboardKind.values.asNameMap()[name];
  }
}

const _kindKey = 'kind';
const _dataKey = 'data';

/// Returns clipboard text containing the supplied json encodable data.
String encodeClipboard(ClipboardKind kind, Object? data) {
  return json.encode({_kindKey: kind.name, _dataKey: data});
}

/// Returns the kind of data in the supplied clipboard text, or null if the text does not contain
/// data from this application.
ClipboardKind? clipboardKind(String text) {
  return _decode(text)?.kind;
}

/// Returns the decoded json data in the supplied clipboard text if it is of the expected kind,
/// or null otherwise.
Object? clipboardData(String text, ClipboardKind kind) {
  final decoded = _decode(text);
  if (decoded?.kind != kind) {
    _log.warning('Clipboard did not contain ${kind.name} data');
    return null;
  }
  return decoded!.data;
}

({ClipboardKind kind, Object? data})? _decode(String text) {
  final Object? decoded;
  try {
    decoded = json.decode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final kindName = decoded[_kindKey];
  final kind = (kindName is String) ? ClipboardKind.fromString(kindName) : null;
  if (kind == null || !decoded.containsKey(_dataKey)) {
    return null;
  }
  return (kind: kind, data: decoded[_dataKey]);
}
