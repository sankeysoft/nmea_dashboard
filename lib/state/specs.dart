// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

/// This allows the other class to access private members in
/// the JsonSerializable generated file.
part 'specs.g.dart';

final _log = Logger('Specs');

/// A unique identifier for specifications.
class _SpecKey extends ValueKey<int> {
  const _SpecKey(super.value);

  static int _nextValue = 1;

  static int allocate() {
    _nextValue += 1;
    return _nextValue - 1;
  }
}

/// A specification for an element of derived data and a key
/// to uniquely identify it.
class KeyedDerivedDataSpec {
  final DerivedDataKey key;
  final DerivedDataSpec _spec;

  KeyedDerivedDataSpec(this.key, this._spec);

  static KeyedDerivedDataSpec fromBareSpec(DerivedDataSpec bareSpec,
      {DerivedDataKey? key}) {
    return KeyedDerivedDataSpec(key ?? DerivedDataKey.make(), bareSpec);
  }

  DerivedDataSpec toBareSpec() => _spec;

  String get name => _spec.name;
  String get inputSource => _spec.inputSource;
  String get inputElement => _spec.inputElement;
  String get inputFormat => _spec.inputFormat;
  String get operation => _spec.operation;
  double get operand => _spec.operand;
}

/// A unique identifier for each derived data element.
class DerivedDataKey extends _SpecKey {
  const DerivedDataKey(super.value);

  static DerivedDataKey make() {
    return DerivedDataKey(_SpecKey.allocate());
  }
}

/// A serializable specification that may be used to recreate an
/// element of derived data.
@JsonSerializable()
class DerivedDataSpec {
  /// The name of the derived data field.
  final String name;

  /// The name of the input source.
  final String inputSource;

  /// The name of the input element within source.
  final String inputElement;

  /// The units in which to work with the input.
  final String inputFormat;

  /// The operation to apply to the input data element.
  final String operation;

  /// The value to feed into the operation.
  final double operand;

  DerivedDataSpec(this.name, this.inputSource, this.inputElement,
      this.inputFormat, this.operation, this.operand);

  factory DerivedDataSpec.fromJson(Map<String, dynamic> json) =>
      _$DerivedDataSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DerivedDataSpecToJson(this);
}

/// A specification for a data page and a key to uniquely identify it.
class KeyedDataPageSpec extends ChangeNotifier {
  final DataPageKey key;
  final String _name;
  final List<KeyedDataCellSpec> _cellList;
  final Map<DataCellKey, KeyedDataCellSpec> _cellMap = {};

  KeyedDataPageSpec(this.key, this._name, this._cellList) {
    // Build the map for fast lookup.
    for (final cell in _cellList) {
      _cellMap[cell.key] = cell;
    }
  }

  static KeyedDataPageSpec fromBareSpec(DataPageSpec barePage,
      {DataPageKey? key}) {
    final pageKey = key ?? DataPageKey.make();
    final cellList = barePage.cells
        .map((bareCell) =>
            KeyedDataCellSpec(DataCellKey.make(pageKey), bareCell))
        .toList();
    return KeyedDataPageSpec(pageKey, barePage.name, cellList);
  }

  DataPageSpec toBareSpec() {
    return DataPageSpec(
        _name, cells.map((keyedCell) => keyedCell.toBareSpec()).toList());
  }

  String get name => _name;
  List<KeyedDataCellSpec> get cells => _cellList;

  /// Updates the supplied cell key with a new specification.
  void updateCell(DataCellKey cellKey, DataCellSpec cellSpec) {
    final cell = _cellMap[cellKey];
    if (cell == null) {
      _log.warning('Could not find cell to update $cellKey');
    } else {
      cell._spec = cellSpec;
      notifyListeners();
    }
  }
}

/// A unique identifier for each data page.
class DataPageKey extends _SpecKey {
  const DataPageKey(super.value);

  static DataPageKey make() {
    return DataPageKey(_SpecKey.allocate());
  }
}

/// A serializable specification that may be used to recreate a table
/// of data elements.
@JsonSerializable(explicitToJson: true)
class DataPageSpec {
  /// A short name for the page
  final String name;

  /// The data to display in the table
  final List<DataCellSpec> cells;

  DataPageSpec(this.name, this.cells);

  factory DataPageSpec.fromJson(Map<String, dynamic> json) =>
      _$DataPageSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DataPageSpecToJson(this);
}

/// A specification for a data page and a key to uniquely identify it.
class KeyedDataCellSpec {
  final DataCellKey key;
  DataCellSpec _spec;

  KeyedDataCellSpec(this.key, this._spec);

  DataCellSpec toBareSpec() => _spec;

  String get source => _spec.source;
  String get element => _spec.element;
  String get format => _spec.format;
  String? get name => _spec.name;
}

/// A unique identifier for each data cell.
class DataCellKey extends _SpecKey {
  final DataPageKey pageKey;
  const DataCellKey(super.value, this.pageKey);

  static DataCellKey make(DataPageKey pageKey) {
    return DataCellKey(_SpecKey.allocate(), pageKey);
  }
}

/// A serializable specification that may be used to recreate a displayable
/// data element.
@JsonSerializable()
class DataCellSpec {
  /// The name of the source.
  final String source;

  /// The name of the element supplying data within source.
  final String element;

  /// The format to use when rendering the element.
  final String format;

  /// An optional name to override the source name on display.
  final String? name;

  DataCellSpec(this.source, this.element, this.format, {this.name});

  factory DataCellSpec.fromJson(Map<String, dynamic> json) =>
      _$DataCellSpecFromJson(json);
  Map<String, dynamic> toJson() => _$DataCellSpecToJson(this);
}
