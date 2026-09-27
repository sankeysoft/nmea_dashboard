// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/ui/cells/anchor_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:nmea_dashboard/ui/cells/average_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/current_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/gauge_value_cell.dart';
import 'package:nmea_dashboard/ui/cells/history_cell.dart';
import 'package:nmea_dashboard/ui/cells/text_cell.dart';
import 'package:nmea_dashboard/state/values.dart';

/// This module's logger.
final _log = Logger('CellCreation');

/// Returns an appropriate concrete cell to display the supplied cell spec,
/// potentially returning a text cell that displays problems encountered during
/// lookup.
(double, double)? _gaugeRangeFor(Property property, Formatter formatter) {
  if (property == Property.engine1Rpm || property == Property.engine2Rpm) {
    return (0.0, 6000.0);
  }

  if (property.dimension == Dimension.percentage) {
    return (0.0, 100.0);
  }

  if (property == Property.engine1FuelRate) {
    return (0.0, 80.0);
  }

  if (property == Property.engine1Temperature) {
    return (40.0, 120.0);
  }

  if (property == Property.battery1Voltage ||
      property == Property.battery2Voltage ||
      property == Property.alternator1Voltage ||
      property == Property.alternator2Voltage) {
    return (11.0, 15.0);
  }

  if (property == Property.battery1TimeRemaining || property == Property.battery2TimeRemaining) {
    return (0.0, 12.0);
  }

  if (property == Property.engine1OilPressure || property == Property.engine2OilPressure) {
    if (formatter is NumericFormatter<SingleValue<double>>) {
      final min = formatter.toNumber(const SingleValue(0.0));
      final max = formatter.toNumber(const SingleValue(689475.729));

      if (min != null && max != null) {
        return (min, max);
      }
    }

    return null;
  }

  if (property == Property.engine1CoolantPressure || property == Property.engine2CoolantPressure) {
    if (formatter is NumericFormatter<SingleValue<double>>) {
      final min = formatter.toNumber(const SingleValue(0.0));

      // Vorläufige neutrale Gauge-Obergrenze.
      // Kein Mercury Warn- oder Alarmwert.
      final max = formatter.toNumber(const SingleValue(344737.865));

      if (min != null && max != null) {
        return (min, max);
      }
    }

    return null;
  }
  return null;
}

Cell createCell(DataSet dataset, DataCellSpec spec, NetworkSettings networkSettings) {
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

  final Formatter? formatter = formattersFor(element.property.dimension)[spec.format];
  if (formatter == null) {
    _log.warning('Could not find ${spec.format} format for ${element.property.dimension}');
    return NotFoundCell(spec: spec);
  }

  final CellType? type = CellType.fromString(spec.type);
  if (type == null) {
    _log.warning('Could not find ${spec.type} cell type');
    return NotFoundCell(spec: spec);
  }
  switch (type) {
    case CellType.current:
      if (element.property == Property.anchorRodeLength) {
        return AnchorValueCell(
          element: element,
          formatter: formatter,
          spec: spec,
          gatewayAddress: networkSettings.ipAddress,
          gatewayPort: networkSettings.port,
        );
      }

      if (spec.displayMode == 'gauge') {
        final range = _gaugeRangeFor(element.property, formatter);

        if (range != null) {
          final DataElement? externalAlarmElement;

          if (element.property == Property.engine1Temperature) {
            externalAlarmElement = dataset.find(source, Property.engine1OverTemperature.name);
          } else if (element.property == Property.engine1OilPressure) {
            externalAlarmElement = dataset.find(source, Property.engine1LowOilPressure.name);
          } else {
            externalAlarmElement = null;
          }

          return GaugeValueCell(
            element: element,
            formatter: formatter,
            spec: spec,
            externalAlarmElement: externalAlarmElement,
            minValue: range.$1,
            maxValue: range.$2,
          );
        }
      }

      return CurrentValueCell(element: element, formatter: formatter, spec: spec);

    case CellType.average:
      final StatsInterval? interval = StatsInterval.fromString(spec.statsInterval);
      if (interval == null) {
        _log.warning('Could not find ${spec.statsInterval} interval');
        return NotFoundCell(spec: spec);
      }
      if (element is! WithStats) {
        _log.warning('Could not build average cell for non-stats type ${element.property}');
      }
      return AverageValueCell(
        element: element,
        stats: (element as WithStats).stats(interval),
        formatter: formatter,
        spec: spec,
      );
    case CellType.history:
      final HistoryInterval? interval = HistoryInterval.fromString(spec.historyInterval);
      if (interval == null) {
        _log.warning('Could not find ${spec.historyInterval} interval');
        return NotFoundCell(spec: spec);
      }
      if (formatter is! NumericFormatter) {
        _log.warning('History formatter ${formatter.longName} is not numeric');
        return NotFoundCell(spec: spec);
      }
      if (element is! WithHistory) {
        _log.warning('Could not build history cell for non-history type ${element.property}');
      }
      return HistoryCell(
        element: element,
        history: (element as WithHistory).history(interval),
        formatter: formatter,
        spec: spec,
      );
  }
}
