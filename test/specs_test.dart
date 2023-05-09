// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:nmea_dashboard/state/specs.dart';
import 'package:test/test.dart';

void main() {
  test('should serialize DerivedDataSpec', () {
    final spec =
        DerivedDataSpec('derived spec', 'network', 'depth', 'feet', '+', 4.0);
    expect(spec.toJson(), json.decode("""{
      "name": "${spec.name}",
      "inputSource": "${spec.inputSource}",
      "inputElement": "${spec.inputElement}",
      "inputFormat": "${spec.inputFormat}",
      "operation": "${spec.operation}",
      "operand": ${spec.operand}
    }"""));
  });

  test('should deserialize DerivedDataSpec', () {
    final prototype =
        DerivedDataSpec('derived spec', 'network', 'depth', 'feet', '+', 4.0);
    final spec = DerivedDataSpec.fromJson({
      'name': prototype.name,
      'inputSource': prototype.inputSource,
      'inputElement': prototype.inputElement,
      'inputFormat': prototype.inputFormat,
      'operation': prototype.operation,
      'operand': prototype.operand,
    });
    expect(spec.name, prototype.name);
    expect(spec.inputSource, prototype.inputSource);
    expect(spec.inputElement, prototype.inputElement);
    expect(spec.inputFormat, prototype.inputFormat);
    expect(spec.operation, prototype.operation);
    expect(spec.operand, prototype.operand);
    expect(spec.key.value, isNot(equals(prototype.key.value)));
  });

  test('should copy DerivedDataSpec key if supplied', () {
    final prototype =
        DerivedDataSpec('derived spec', 'network', 'depth', 'feet', '+', 4.0);
    final spec1 = DerivedDataSpec(
      prototype.name,
      prototype.inputSource,
      prototype.inputElement,
      prototype.inputFormat,
      prototype.operation,
      prototype.operand,
    );
    expect(spec1.key.value, isNot(equals(prototype.key.value)));
    final spec2 = DerivedDataSpec(
      prototype.name,
      prototype.inputSource,
      prototype.inputElement,
      prototype.inputFormat,
      prototype.operation,
      prototype.operand,
      key: prototype.key,
    );
    expect(spec2.key.value, equals(prototype.key.value));
  });

  test('should serialize DerivedDataPage', () {
    final pageSpec = DataPageSpec('page 1', [
      DataCellSpec('network', 'element 1', 'current', 'feet'),
      DataCellSpec('network', 'element 2', 'history', 'meters',
          historyInterval: 'fifteenMinutes'),
      DataCellSpec('derived', 'element 3', 'current', 'stoats',
          name: '3 stoats'),
    ]);
    expect(pageSpec.toJson(), {
      'name': pageSpec.name,
      'cells': [
        {
          'source': 'network',
          'element': 'element 1',
          'type': 'current',
          'format': 'feet',
        },
        {
          'source': 'network',
          'element': 'element 2',
          'type': 'history',
          'historyInterval': 'fifteenMinutes',
          'format': 'meters',
        },
        {
          'source': 'derived',
          'element': 'element 3',
          'type': 'current',
          'format': 'stoats',
          'name': '3 stoats',
        }
      ]
    });
  });

  test('should deserialize DerivedDataPage', () {
    /// Note one of these has no name and one has a null type as we used to
    /// generate in old code. One also has a missing type which we interpret
    /// as current value.
    final pageSpec = DataPageSpec.fromJson(json.decode("""{
      "name": "test page",
      "cells": [
        {
          "source": "network",
          "element": "element 1",
          "type": "current",
          "format": "feet"
        },
        {
          "source": "network",
          "element": "element 2",
          "type": "history",
          "historyInterval": "twoHours",
          "format": "meters",
          "name": null
        },
        {
          "source": "derived",
          "element": "element 3",
          "format": "stoats",
          "name": "3 stoats"
        }
      ]
    }"""));
    expect(pageSpec.name, 'test page');
    expect(pageSpec.cells.length, 3);
    expect(pageSpec.cells[0].source, 'network');
    expect(pageSpec.cells[0].element, 'element 1');
    expect(pageSpec.cells[0].type, 'current');
    expect(pageSpec.cells[0].historyInterval, isNull);
    expect(pageSpec.cells[0].format, 'feet');
    expect(pageSpec.cells[0].name, isNull);
    expect(pageSpec.cells[1].source, 'network');
    expect(pageSpec.cells[1].element, 'element 2');
    expect(pageSpec.cells[1].type, 'history');
    expect(pageSpec.cells[1].historyInterval, 'twoHours');
    expect(pageSpec.cells[1].format, 'meters');
    expect(pageSpec.cells[1].name, isNull);
    expect(pageSpec.cells[2].source, 'derived');
    expect(pageSpec.cells[2].element, 'element 3');
    expect(pageSpec.cells[2].type, 'current');
    expect(pageSpec.cells[2].historyInterval, isNull);
    expect(pageSpec.cells[2].format, 'stoats');
    expect(pageSpec.cells[2].name, '3 stoats');
    expect(pageSpec.cells.length, 3);
    expect(pageSpec.cells[0].key, isNot(equals(pageSpec.cells[1].key)));
    expect(pageSpec.cells[1].key, isNot(equals(pageSpec.cells[2].key)));
    expect(pageSpec.cells[2].key, isNot(equals(pageSpec.cells[0].key)));
  });

  test('containCell should only be true for contained cells', () {
    final pageSpec = DataPageSpec('page 1', [
      DataCellSpec('network', 'element 1', 'current', 'feet'),
      DataCellSpec('network', 'element 2', 'history', 'meters',
          historyInterval: 'twoHours'),
    ]);

    expect(pageSpec.containsCell(pageSpec.key), false);
    expect(pageSpec.containsCell(pageSpec.cells[0].key), true);
    expect(pageSpec.containsCell(pageSpec.cells[1].key), true);
  });

  test('should be able to update valid cell', () {
    final pageSpec = DataPageSpec('page 1', [
      DataCellSpec('network', 'element 1', 'current', 'feet'),
      DataCellSpec('network', 'element 2', 'history', 'meters',
          historyInterval: 'twoHours'),
    ]);
    final updatedCell = DataCellSpec('local', 'updated 2', 'history', 'meters',
        historyInterval: 'twoHours', key: pageSpec.cells[1].key);
    pageSpec.updateCell(updatedCell);
    expect(pageSpec.containsCell(updatedCell.key), true);
    expect(pageSpec.cells[1].source, 'local');
    expect(pageSpec.cells[1].element, 'updated 2');
    expect(pageSpec.cells[1].format, 'meters');
  });

  test('should fail to update invalid cell', () {
    final pageSpec = DataPageSpec('page 1', [
      DataCellSpec('network', 'element 1', 'current', 'feet'),
      DataCellSpec('network', 'element 2', 'history', 'meters',
          historyInterval: 'twoHours'),
    ]);
    // Note this gets a new key rather than a key that matches an existing cell.
    final updatedCell = DataCellSpec('local', 'updated 2', 'history', 'meters',
        historyInterval: 'twoHours');
    pageSpec.updateCell(updatedCell);
    expect(pageSpec.containsCell(updatedCell.key), false);
  });
}
