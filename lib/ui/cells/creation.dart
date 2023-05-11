// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/cells/current_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/text_cell.dart';

import 'abstract.dart';

/// This module's logger.
final _log = Logger('CellCreation');

/// Returns an appropriate concrete cell to display the supplied cell spec,
/// potentially returning a text cell that displays problems encountered during
/// lookup.
Cell createCell(DataSet dataset, DataCellSpec spec) {
  final source = Source.fromString(spec.source);
  if (source == null) {
    if (spec.source.isNotEmpty) {
      _log.warning('Invalid spec source ${spec.source}');
    }
    return NotFoundCell(spec: spec);
  } else if (source == Source.unset) {
    return UnsetCell(spec: spec);
  }

  final DataElement? element = dataset.find(source, spec.element);
  if (element == null) {
    _log.warning('Could not find ${spec.element} in source ${spec.source}');
    return NotFoundCell(spec: spec);
  }

  final Formatter? formatter =
      formattersFor(element.property.dimension)[spec.format];
  if (formatter == null) {
    _log.warning(
        'Could not find ${spec.format} format for ${element.property.dimension}');
    return NotFoundCell(spec: spec);
  }

  return CurrentValueCell(element: element, formatter: formatter, spec: spec);
}
