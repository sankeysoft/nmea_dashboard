// Copyright Jody M Sankey 2026
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:provider/provider.dart';
import 'package:nmea_dashboard/state/common.dart';

class GaugeValueCell extends HeadingContentsCell {
  GaugeValueCell({
    required DataElement element,
    required Formatter formatter,
    required DataCellSpec spec,
    DataElement? externalAlarmElement,
    double minValue = 0.0,
    double maxValue = 6000.0,
    super.key,
  }) : super(
         heading: spec.name ?? (element.shortName.isEmpty ? ' ' : element.shortName),
         units: formatter.units ?? ' ',
         content: ChangeNotifierProvider<DataElement>.value(
           value: element,
           child: _GaugeValue(
             property: element.property,
             formatter: formatter,
             minValue: minValue,
             maxValue: maxValue,
             externalAlarmElement: externalAlarmElement,
           ),
         ),
         alarmState: (element is WithAlarms) ? element.alarmState : null,
         spec: spec,
       );
}

class _GaugeValue extends StatelessWidget {
  final Property property;
  final Formatter formatter;
  final double minValue;
  final double maxValue;
  final DataElement? externalAlarmElement;

  const _GaugeValue({
    required this.property,
    required this.formatter,
    required this.minValue,
    required this.maxValue,
    this.externalAlarmElement,
  });

  @override
  Widget build(BuildContext context) {
    final element = Provider.of<DataElement>(context);
    final rawValue = element.value;

    double? value;

    if (rawValue is SingleValue<double>) {
      if (formatter is NumericFormatter<SingleValue<double>>) {
        value = (formatter as NumericFormatter<SingleValue<double>>).toNumber(rawValue);
      } else {
        value = rawValue.data;
      }
    }

    Widget buildGauge() {
      final alarmValue = externalAlarmElement?.value;

      final externalAlarmActive = alarmValue is SingleValue<int> && alarmValue.data != 0;

      return LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            painter: _GaugePainter(
              property: property,
              value: value,
              minValue: minValue,
              maxValue: maxValue,
              externalAlarmActive: externalAlarmActive,
              colorScheme: Theme.of(context).colorScheme,
              textStyle: Theme.of(context).textTheme,
            ),
            child: const SizedBox.expand(),
          );
        },
      );
    }

    if (externalAlarmElement == null) {
      return buildGauge();
    }

    return ListenableBuilder(
      listenable: externalAlarmElement!,
      builder: (context, child) {
        return buildGauge();
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final Property property;
  final double? value;
  final double minValue;
  final double maxValue;
  final bool externalAlarmActive;
  final ColorScheme colorScheme;
  final TextTheme textStyle;

  const _GaugePainter({
    required this.property,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.externalAlarmActive,
    required this.colorScheme,
    required this.textStyle,
  });

  static const double _startAngle = 150.0 * pi / 180.0;
  static const double _sweepAngle = 240.0 * pi / 180.0;

  bool get _isRpmGauge => minValue == 0.0 && maxValue == 6000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);

    final radius = min(size.width * 0.42, size.height * 0.68);

    if (radius <= 0) {
      return;
    }

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: _isRpmGauge ? 0.38 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isRpmGauge ? max(4.0, radius * 0.045) : max(7.0, radius * 0.10)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, backgroundPaint);

    if (value != null) {
      final normalized = ((value! - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);

      final valuePaint = Paint()
        ..color = externalAlarmActive ? colorScheme.error : colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = _isRpmGauge ? max(3.0, radius * 0.035) : max(7.0, radius * 0.10)
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(arcRect, _startAngle, _sweepAngle * normalized, false, valuePaint);

      final needleAngle = _startAngle + (_sweepAngle * normalized);

      final needleEnd = Offset(
        center.dx + cos(needleAngle) * radius * 0.84,
        center.dy + sin(needleAngle) * radius * 0.84,
      );

      final needlePaint = Paint()
        ..color = externalAlarmActive
            ? colorScheme.error
            : (_isRpmGauge ? colorScheme.primary : colorScheme.onSurface)
        ..strokeWidth = _isRpmGauge ? max(3.5, radius * 0.045) : max(3.0, radius * 0.035)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, needleEnd, needlePaint);

      canvas.drawCircle(center, max(4.0, radius * 0.055), Paint()..color = colorScheme.onSurface);
    }
    // Roter Drehzahlbereich 5800–6000 rpm.
    if (_isRpmGauge) {
      const redStartRpm = 5800.0;
      const redEndRpm = 6000.0;

      final redStartFraction = (redStartRpm - minValue) / (maxValue - minValue);
      final redEndFraction = (redEndRpm - minValue) / (maxValue - minValue);

      final redStartAngle = _startAngle + (_sweepAngle * redStartFraction);

      final redSweepAngle = _sweepAngle * (redEndFraction - redStartFraction);

      final redZonePaint = Paint()
        ..color = colorScheme.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(5.0, radius * 0.065)
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(arcRect, redStartAngle, redSweepAngle, false, redZonePaint);
    }
    // Farbiger Bereich der Motortemperatur.
    // Die Skala dient als optische Orientierung.
    // Ein echter Übertemperaturalarm kommt über PGN 127489.
    if (minValue == 40.0 && maxValue == 120.0) {
      const normalStartTemp = 60.0;
      const normalEndTemp = 90.0;

      final normalStartFraction = (normalStartTemp - minValue) / (maxValue - minValue);
      final normalEndFraction = (normalEndTemp - minValue) / (maxValue - minValue);

      final normalStartAngle = _startAngle + (_sweepAngle * normalStartFraction);
      final normalSweepAngle = _sweepAngle * (normalEndFraction - normalStartFraction);

      final normalZonePaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(5.0, radius * 0.065)
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(arcRect, normalStartAngle, normalSweepAngle, false, normalZonePaint);
    }
    // Farbige Spannungsbereiche für 12-V-LiFePO4-Batterien.
    // Nur Battery 1/2 - nicht für die Mercury-Alternatorspannung.
    if (property == Property.battery1Voltage || property == Property.battery2Voltage) {
      void drawVoltageZone(double startVoltage, double endVoltage, Color color) {
        final startFraction = (startVoltage - minValue) / (maxValue - minValue);

        final endFraction = (endVoltage - minValue) / (maxValue - minValue);

        final startAngle = _startAngle + (_sweepAngle * startFraction);

        final sweepAngle = _sweepAngle * (endFraction - startFraction);

        final zonePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(5.0, radius * 0.065)
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(arcRect, startAngle, sweepAngle, false, zonePaint);
      }

      drawVoltageZone(11.0, 12.0, colorScheme.error);

      drawVoltageZone(12.0, 12.8, Colors.amber);

      drawVoltageZone(12.8, 14.4, Colors.green);

      drawVoltageZone(14.4, 15.0, colorScheme.error);
    }
    // Farbige Spannungsbereiche für das Mercury-Ladesystem.
    // Getrennt von den LiFePO4-Batteriespannungen.
    if (property == Property.alternator1Voltage || property == Property.alternator2Voltage) {
      void drawAlternatorVoltageZone(double startVoltage, double endVoltage, Color color) {
        final startFraction = (startVoltage - minValue) / (maxValue - minValue);

        final endFraction = (endVoltage - minValue) / (maxValue - minValue);

        final startAngle = _startAngle + (_sweepAngle * startFraction);

        final sweepAngle = _sweepAngle * (endFraction - startFraction);

        final zonePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(5.0, radius * 0.065)
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(arcRect, startAngle, sweepAngle, false, zonePaint);
      }

      // Niedrige Ladespannung.
      drawAlternatorVoltageZone(11.0, 12.0, colorScheme.error);

      // Unterhalb des normalen Ladebereichs.
      drawAlternatorVoltageZone(12.0, 13.0, Colors.amber);

      // Normaler Ladebereich.
      drawAlternatorVoltageZone(13.0, 14.7, Colors.green);

      // Zu hohe Ladespannung.
      drawAlternatorVoltageZone(14.7, 15.0, colorScheme.error);
    }
    if (_isRpmGauge) {
      _drawRpmMinorTicks(canvas, center, radius);
    }

    if (minValue == 0.0 && maxValue == 100.0) {
      _drawPercentageMinorTicks(canvas, center, radius);
    }

    _drawTicks(canvas, center, radius);

    _drawValue(canvas, size, center, radius);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: _isRpmGauge ? 0.95 : 0.75)
      ..strokeWidth = _isRpmGauge ? max(2.0, radius * 0.025) : max(1.0, radius * 0.012)
      ..strokeCap = StrokeCap.round;

    final int divisions;

    if (minValue == 0.0 && maxValue == 100.0) {
      divisions = 5;
    } else if (minValue == 11.0 && maxValue == 15.0) {
      divisions = 4;
    } else if (minValue == 40.0 && maxValue == 120.0) {
      divisions = 4;
    } else if (minValue == 0.0 && maxValue == 80.0) {
      divisions = 4;
    } else if (minValue == 0.0 && maxValue == 12.0) {
      divisions = 6;
    } else if (property == Property.engine1OilPressure ||
        property == Property.engine2OilPressure ||
        property == Property.engine1CoolantPressure ||
        property == Property.engine2CoolantPressure) {
      divisions = 5;
    } else {
      divisions = 6;
    }

    for (int i = 0; i <= divisions; i++) {
      final fraction = i / divisions;

      final angle = _startAngle + (_sweepAngle * fraction);

      final outer = Offset(
        center.dx + cos(angle) * radius * 1.02,
        center.dy + sin(angle) * radius * 1.02,
      );

      final innerRadius = _isRpmGauge ? 0.84 : 0.88;

      final inner = Offset(
        center.dx + cos(angle) * radius * innerRadius,
        center.dy + sin(angle) * radius * innerRadius,
      );

      canvas.drawLine(inner, outer, tickPaint);

      final labelValue = minValue + ((maxValue - minValue) * fraction);

      final labelPosition = Offset(
        center.dx + cos(angle) * radius * 0.70,
        center.dy + sin(angle) * radius * 0.70,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: (minValue == 0.0 && maxValue == 6000.0)
              ? (labelValue / 1000.0).toStringAsFixed(0)
              : labelValue.toStringAsFixed(0),
          style: textStyle.bodySmall?.copyWith(
            color: colorScheme.onSurface,
            fontSize: max(10.0, radius * 0.15),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(labelPosition.dx - painter.width / 2, labelPosition.dy - painter.height / 2),
      );
    }
  }

  void _drawRpmMinorTicks(Canvas canvas, Offset center, double radius) {
    final minorPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.65)
      ..strokeWidth = max(1.0, radius * 0.012)
      ..strokeCap = StrokeCap.round;

    const minorDivisions = 30;

    for (int i = 0; i <= minorDivisions; i++) {
      if (i % 5 == 0) {
        continue;
      }

      final fraction = i / minorDivisions;

      final angle = _startAngle + (_sweepAngle * fraction);

      final outer = Offset(
        center.dx + cos(angle) * radius * 1.01,
        center.dy + sin(angle) * radius * 1.01,
      );

      final inner = Offset(
        center.dx + cos(angle) * radius * 0.93,
        center.dy + sin(angle) * radius * 0.93,
      );

      canvas.drawLine(inner, outer, minorPaint);
    }
  }

  void _drawPercentageMinorTicks(Canvas canvas, Offset center, double radius) {
    final minorPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.55)
      ..strokeWidth = max(1.5, radius * 0.020)
      ..strokeCap = StrokeCap.round;

    const minorDivisions = 10;

    for (int i = 1; i < minorDivisions; i++) {
      if (i.isEven) {
        continue;
      }

      final fraction = i / minorDivisions;

      final angle = _startAngle + (_sweepAngle * fraction);

      final outer = Offset(
        center.dx + cos(angle) * radius * 1.01,
        center.dy + sin(angle) * radius * 1.01,
      );

      final inner = Offset(
        center.dx + cos(angle) * radius * 0.89,
        center.dy + sin(angle) * radius * 0.89,
      );

      canvas.drawLine(inner, outer, minorPaint);
    }
  }

  void _drawValue(Canvas canvas, Size size, Offset center, double radius) {
    final valueText = value == null ? '---' : value!.toStringAsFixed(0);

    final valuePainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: textStyle.headlineLarge?.copyWith(
          color: externalAlarmActive ? colorScheme.error : colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: _isRpmGauge ? max(22.0, radius * 0.40) : max(18.0, radius * 0.31),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final y = center.dy + radius * (_isRpmGauge ? 0.17 : 0.20);

    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, y - valuePainter.height / 2),
    );

    if (_isRpmGauge) {
      final multiplierPainter = TextPainter(
        text: TextSpan(
          text: '×1000',
          style: textStyle.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
            fontSize: max(8.0, radius * 0.11),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      multiplierPainter.paint(
        canvas,
        Offset(center.dx - multiplierPainter.width / 2, y + valuePainter.height * 0.42),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.property != property ||
        oldDelegate.value != value ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.externalAlarmActive != externalAlarmActive ||
        oldDelegate.colorScheme != colorScheme;
  }
}
