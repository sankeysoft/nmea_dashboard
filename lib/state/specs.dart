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
class SpecKey extends ValueKey<int> {
  const SpecKey(super.value);

  static int _nextValue = 1;

  static SpecKey make() {
    _nextValue += 1;
    return SpecKey(_nextValue - 1);
  }
}

/// A serializable specification that may be used to recreate an
/// element of derived data.
@JsonSerializable()
class DerivedDataSpec {
  /// A unique identifier within the current power cycle.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final SpecKey key;

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
      this.inputFormat, this.operation, this.operand,
      {SpecKey? key})
      : key = key ?? SpecKey.make();

  factory DerivedDataSpec.fromJson(Map<String, dynamic> json) =>
      _$DerivedDataSpecFromJson(json);

  Map<String, dynamic> toJson() => _$DerivedDataSpecToJson(this);
}

/// A serializable specification that may be used to recreate a table
/// of data elements.
@JsonSerializable(explicitToJson: true)
class DataPageSpec extends ChangeNotifier {
  /// A unique identifier within the current power cycle.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final SpecKey key;

  /// A short name for the page
  final String name;

  /// A map from a CellKey to the list index for fast lookup.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final Map<SpecKey, int> _cellMap;

  /// The data to display in the table
  final List<DataCellSpec> cells;

  DataPageSpec(this.name, this.cells, {SpecKey? key})
      : key = key ?? SpecKey.make(),
        _cellMap = {} {
    for (int i = 0; i < cells.length; i++) {
      _cellMap[cells[i].key] = i;
    }
  }

  /// Returns true iff the page contains the supplied cellKey.
  bool containsCell(SpecKey cellKey) {
    return _cellMap[cellKey] != null;
  }

  /// Updates the supplied specification, assuming its key was already present.
  void updateCell(DataCellSpec cellSpec) {
    final idx = _cellMap[cellSpec.key];
    if (idx == null) {
      _log.warning('Could not find cell to update ${cellSpec.key}');
    } else {
      cells[idx] = cellSpec;
      notifyListeners();
    }
  }

  factory DataPageSpec.fromJson(Map<String, dynamic> json) =>
      _$DataPageSpecFromJson(json);

  Map<String, dynamic> toJson() => _$DataPageSpecToJson(this);
}

/// A serializable specification that may be used to recreate a displayable
/// data element.
@JsonSerializable()
class DataCellSpec {
  /// A unique identifier within the current power cycle.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final SpecKey key;

  /// The name of the source.
  final String source;

  /// The name of the element supplying data within source.
  final String element;

  /// The type of cell, e.g. current value or history.
  @JsonKey(defaultValue: 'current')
  final String type;

  /// The history interval, only populated for history cell types.
  @JsonKey(includeIfNull: false)
  final String? historyInterval;

  /// The format to use when rendering the element.
  final String format;

  /// An optional name to override the source name on display.
  @JsonKey(includeIfNull: false)
  final String? name;

  DataCellSpec(this.source, this.element, this.type, this.format,
      {this.name, this.historyInterval, SpecKey? key})
      : key = key ?? SpecKey.make();

  factory DataCellSpec.fromJson(Map<String, dynamic> json) =>
      _$DataCellSpecFromJson(json);

  Map<String, dynamic> toJson() => _$DataCellSpecToJson(this);
}
