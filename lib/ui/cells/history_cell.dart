// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/history.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:provider/provider.dart';

import 'abstract.dart';

class HistoryCell extends HeadingContentsCell {
  HistoryCell(
      {required OptionalHistory history,
      required DataElement element,
      required ConvertingFormatter formatter,
      required DataCellSpec spec,
      key})
      : super(
            spec: spec,
            key: key,
            heading: spec.name ?? history.interval.shortCellName(element),
            units: formatter.units ?? ' ',
            content: ChangeNotifierProvider<OptionalHistory>.value(
                value: history, child: _Graph(formatter)));
}

class _Graph extends StatelessWidget {
  final ConvertingFormatter formatter;

  const _Graph(this.formatter);

  @override
  Widget build(BuildContext context) {
    final history = Provider.of<OptionalHistory>(context);
    if (history.inner == null) {
      return const FittedBox(
          fit: BoxFit.contain,
          child: Text("No History Object", textAlign: TextAlign.center));
    }
    return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: RepaintBoundary(
            child: CustomPaint(
                painter:
                    _GraphPainter(history.inner!, formatter, Theme.of(context)),
                child: Container())));
  }
}

class _YAxis {
  final double minNative;
  final double minDisplay;
  final double maxNative;
  final double maxDisplay;
  final int tickCount;
  final int _formatDp;

  _YAxis(this.minNative, this.minDisplay, this.maxNative, this.maxDisplay,
      this.tickCount, this._formatDp);

  static _YAxis calculate(History history, ConvertingFormatter formatter) {
    // Default to fixed values if the history does not yet have a range.
    double minNative = history.min ?? 0;
    double maxNative = history.max ?? 1;
    double minDisplay = formatter.convert(minNative);
    double maxDisplay = formatter.convert(maxNative);

    // Find the distance we want between tick marks to give about 1-4 ticks.
    final logRange = log(max(maxDisplay - minDisplay, 0.2)) / ln10;
    double tickSpacing;
    if (logRange % 1.0 < log(2) / ln10) {
      // Value is between 1eX and 2eX, use 0.5eX step
      tickSpacing = 0.5 * pow(10, logRange.floorToDouble());
    } else if (logRange % 1.0 < log(4) / ln10) {
      // Value is between 2eX and 4eX, use 1eX step
      tickSpacing = 1.0 * pow(10, logRange.floorToDouble());
    } else {
      // Value is between 4eX and 10eX, use 2eX step
      tickSpacing = 2.0 * pow(10, logRange.floorToDouble());
    }
    final formatDp = max(-(log(tickSpacing) / ln10).floor(), 0);

    // Round the min down and the max up to this step, ensuring they can't be
    // the same output even if they were the same and exactly an integer.
    minDisplay = minDisplay.abs() < 0.001
        ? 0.0
        : ((minDisplay - 0.0001) / tickSpacing).floorToDouble() * tickSpacing;
    maxDisplay =
        ((maxDisplay + 0.0001) / tickSpacing).ceilToDouble() * tickSpacing;
    minNative = formatter.unconvert(minDisplay);
    maxNative = formatter.unconvert(maxDisplay);
    final tickCount = ((maxDisplay - minDisplay) / tickSpacing).round() + 1;

    return _YAxis(
        minNative, minDisplay, maxNative, maxDisplay, tickCount, formatDp);
  }

  String format(double value) {
    return value.toStringAsFixed(_formatDp);
  }
}

class _XAxis {
  final int firstTickSegment;
  final DateTime firstTickTime;
  final int tickSpacing;
  final Duration timeSpacing;

  _XAxis(this.firstTickSegment, this.firstTickTime, this.tickSpacing,
      this.timeSpacing);

  static _XAxis calculate(History history) {
    final interval = history.interval;
    final startTime =
        history.endValueTime.subtract(interval.segment * history.values.length);
    final truncatedTime = truncateUtcToDuration(startTime, interval.tick);
    final firstTickTime = (truncatedTime == startTime)
        ? truncatedTime
        : truncatedTime.add(interval.tick);
    final segmentMs = interval.segment.inMilliseconds;
    return _XAxis(
        (firstTickTime.difference(startTime).inMilliseconds / segmentMs)
            .floor(),
        firstTickTime,
        (interval.tick.inMilliseconds / segmentMs).floor(),
        interval.tick);
  }
}

class _GraphPainter extends CustomPainter {
  final History history;
  final ConvertingFormatter formatter;
  final ThemeData theme;
  DateTime? _lastPaintEvt;

  _GraphPainter(this.history, this.formatter, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    // First calculate and validate the information we need for the axes.
    final yAxis = _YAxis.calculate(history, formatter);
    final xAxis = _XAxis.calculate(history);

    // If we have enough height to comfortably fit the *max* number of tick
    // marks (so if a graph range changes and gets a different number of tick
    // marks we won't change format) then display ticks.
    final minText = layoutText(yAxis.format(yAxis.minDisplay));
    final charHeight = minText.height;
    bool drawGrid = (size.height > minText.height * 12);
    bool validData = (history.min != null && history.max != null);

    late final double yAxisWidth;
    late final Size plotSize;
    late final Offset plotOffset;
    if (drawGrid) {
      // While drawing a grid we reduce the height of the y axis to allow for
      // the x axis...
      final axisHeight = size.height - charHeight;
      yAxisWidth = paintYAxis(canvas, axisHeight, yAxis, drawGrid, minText) +
          charHeight / 2;
      paintXAxis(canvas, Offset(yAxisWidth, size.height - charHeight),
          size.width - yAxisWidth, xAxis, history);
      // ...and reduce the plot height further so the top and bottom are aligned
      // with the center of the top and bottom labels.
      plotSize = Size(size.width - yAxisWidth, axisHeight - charHeight);
      plotOffset = Offset(yAxisWidth, charHeight / 2);
    } else {
      // When height is constrained, let both the axis and the plot take the
      // full height and don't draw the xaxis.
      yAxisWidth = paintYAxis(canvas, size.height, yAxis, drawGrid, minText) +
          charHeight / 2;
      plotSize = Size(size.width - yAxisWidth, size.height);
      plotOffset = Offset(yAxisWidth, 0);
    }

    paintPlot(canvas, plotSize, plotOffset, yAxis);
    if (drawGrid && validData) {
      // Avoid the grid if we paint status text explaining lack of data.
      paintXGrid(canvas, plotSize, plotOffset, xAxis);
      paintYGrid(canvas, plotSize, plotOffset, yAxis);
    }

    _lastPaintEvt = history.endValueTime;
  }

  TextPainter layoutText(String text, {TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: theme.textTheme.labelSmall),
        textAlign: align);
    painter.textDirection = TextDirection.ltr;
    painter.layout();
    return painter;
  }

  /// Paints the value markers on the Y axis, either only min/max or all values
  /// depending on the setting of allValues. Returns the largest marker width.
  double paintYAxis(Canvas canvas, double availableHeight, _YAxis yAxis,
      bool allValues, TextPainter minText) {
    // Build a list of the text in all labels so we can right align to the
    // longest.
    List<TextPainter> texts = [minText];
    if (allValues) {
      final displayStep =
          (yAxis.maxDisplay - yAxis.minDisplay) / (yAxis.tickCount - 1);
      for (int i = 1; i < yAxis.tickCount - 1; i++) {
        final display = yAxis.minDisplay + (i * displayStep);
        texts.add(layoutText(yAxis.format(display)));
      }
    }
    texts.add(layoutText(yAxis.format(yAxis.maxDisplay)));

    // And paint them.
    final maxWidth = texts.map((t) => t.width).reduce(max);
    final heightBetweenCenters = availableHeight - minText.height;
    for (int i = 0; i < texts.length; i++) {
      final text = texts[i];
      final y =
          heightBetweenCenters * (texts.length - 1 - i) / (texts.length - 1);
      text.paint(canvas, Offset(maxWidth - text.width, y));
    }

    return maxWidth;
  }

  /// Paints the gridlines on the Y axis.
  void paintYGrid(Canvas canvas, Size size, Offset offset, _YAxis yAxis) {
    final greyStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.colorScheme.primaryContainer;

    final dyStep = size.height / (yAxis.tickCount - 1);
    for (double dy = dyStep + offset.dy; dy < size.height - 1.0; dy += dyStep) {
      canvas.drawLine(Offset(offset.dx, dy), Offset(offset.dx + size.width, dy),
          greyStroke);
    }
  }

  /// Paints the value markers on the X axis.
  void paintXAxis(Canvas canvas, Offset offset, double availableWidth,
      _XAxis xAxis, History history) {
    final interval = history.interval;
    final segWidth = availableWidth / history.values.length;

    int segment = xAxis.firstTickSegment;
    DateTime time = xAxis.firstTickTime;

    // No less than or equal to for DateTime. Sigh.
    DateTime afterEnd = history.endValueTime.add(const Duration(seconds: 1));
    while (time.isBefore(afterEnd)) {
      final text = layoutText(interval.formatTime(time.toLocal()));
      // Ideally center align the text on the line, but adjust as needed so
      // we don't flow outside the width.
      double x = segment * segWidth - text.width / 2;
      if (x < 0) {
        x = 0;
      } else if (x + text.width > availableWidth) {
        x = availableWidth - text.width;
      }
      text.paint(canvas, Offset(offset.dx + x, offset.dy));
      segment += xAxis.tickSpacing;
      time = time.add(xAxis.timeSpacing);
    }
  }

  /// Paints the gridlines on the Y axis.
  void paintXGrid(Canvas canvas, Size size, Offset offset, _XAxis xAxis) {
    final greyStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.colorScheme.primaryContainer;

    for (int segment = xAxis.firstTickSegment;
        segment < history.values.length;
        segment += xAxis.tickSpacing) {
      final dx = offset.dx + (segment / history.values.length) * size.width;
      canvas.drawLine(Offset(dx, offset.dy),
          Offset(dx, offset.dy + size.height), greyStroke);
    }
  }

  /// Paints the actual plot and the surrounding grid.
  void paintPlot(Canvas canvas, Size size, Offset offset, _YAxis yAxis) {
    final segWidth = size.width / history.values.length;
    final rangeNative = max(yAxis.maxNative - yAxis.minNative, 0.01);
    final y0 = offset.dy + size.height;

    final greyStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.colorScheme.primaryContainer;
    final whiteFill = Paint()
      ..style = PaintingStyle.fill
      ..color = theme.colorScheme.primary;
    final blackFill = Paint()
      ..style = PaintingStyle.fill
      ..color = theme.colorScheme.onPrimary;

    // Start with a grey background representing the defualt of invalid data.
    canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        Paint()..color = theme.colorScheme.surfaceTint);

    if (history.min == null || history.max == null) {
      // If there is no history min/max there will be no data. Draw status text
      // instead of the actual graph.
      // TODO: Probably cleaner having a separate method poplulate text driven
      // by the master paint method?
      final endTime = intl.DateFormat("HH:mm:ss")
          .format(history.endValueTime.add(history.interval.segment).toLocal());
      final text = layoutText('Accumulating\nhistory until\n$endTime',
          align: TextAlign.center);
      final txtOffset = Offset(offset.dx + size.width / 2 - text.width / 2,
          offset.dy + size.height / 2 - text.height / 2);
      text.paint(canvas, txtOffset);
    } else {
      // Draw rectangular black and bargraph white paths for each chunk of valid
      // data.
      Path? whitePath;
      Path? blackPath;
      for (int i = 0; i < history.values.length + 1; i++) {
        /// Deliberately iterate one more to close any previous shape.
        final x = segWidth * i + offset.dx;
        if (i >= history.values.length || history.values[i] == null) {
          // Draw the previous shape if we had one.
          if (blackPath != null) {
            blackPath.lineTo(x, offset.dy);
            blackPath.lineTo(x, y0);
            blackPath.close();
            canvas.drawPath(blackPath, blackFill);
            blackPath = null;
          }
          if (whitePath != null) {
            whitePath.lineTo(x, y0);
            whitePath.close();
            canvas.drawPath(whitePath, whiteFill);
            whitePath = null;
          }
        } else {
          final y = y0 -
              min((history.values[i]! - yAxis.minNative) / rangeNative, 1.0) *
                  size.height;
          // Create new paths if needed.
          if (blackPath == null) {
            blackPath = Path();
            blackPath.moveTo(x, y0);
            blackPath.lineTo(x, offset.dy);
          }
          if (whitePath == null) {
            whitePath = Path();
            whitePath.moveTo(x, y0);
          }
          // Draw this bar in the bar graph.
          whitePath.lineTo(x, y);
          whitePath.relativeLineTo(segWidth, 0);
        }
      }
    }

    // Finish with a grey border.
    canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        greyStroke);
  }

  @override
  bool shouldRepaint(_GraphPainter oldDelegate) {
    return history != oldDelegate.history ||
        history.endValueTime != oldDelegate._lastPaintEvt ||
        formatter != oldDelegate.formatter;
  }
}
