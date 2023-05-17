// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:flutter/material.dart';
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
    if (history.inner?.min == null || history.inner?.max == null) {
      return const FittedBox(
          fit: BoxFit.contain,
          child: Text("No History Data", textAlign: TextAlign.center));
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

  static _YAxis? calculate(History history, ConvertingFormatter formatter) {
    double? minNative = history.min;
    double? maxNative = history.max;
    if (minNative == null || maxNative == null) {
      return null;
    }
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

    // Round the min down and the max up to this step, ensuring they cant be the
    // same output even if they were the same and exactly an integer.
    minDisplay =
        ((minDisplay - 0.0001) / tickSpacing).floorToDouble() * tickSpacing;
    maxDisplay =
        ((maxDisplay + 0.0001) / tickSpacing).ceilToDouble() * tickSpacing;
    minNative = formatter.unconvert(minDisplay);
    maxNative = formatter.unconvert(maxDisplay);
    final tickCount = ((maxDisplay - minDisplay) / tickSpacing).round() + 1;
    //print('$minDisplay to $maxDisplay step $tickSpacing count $tickCount');

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
    if (yAxis == null) {
      // Should never hit invalid axis because parent should have checked
      // min/max was not null, just bail if it happens.
      // TODO: maybe its better to handle the no history case here and draw
      // a message inside the plot so there is a smaller visual change.
      return;
    }
    final xAxis = _XAxis.calculate(history);

    // If we have enough height to comfortably fit the *max* number of tick
    // marks (so if a graph range changes and gets a different number of tick
    // marks we won't change format) then display ticks.
    final minText = layoutText(yAxis.format(yAxis.minDisplay));
    final charHeight = minText.height;
    bool drawTicks = (size.height > minText.height * 12);
    if (drawTicks) {
      // While drawing ticks we reduce the height of the y axis to allow for the
      // x axis.
      final axisHeight = size.height - charHeight;
      final yAxisWidth =
          paintYAxis(canvas, axisHeight, yAxis, drawTicks, minText) +
              charHeight / 2;
      paintXAxis(canvas, Offset(yAxisWidth, size.height - charHeight),
          size.width - yAxisWidth, xAxis, history);

      // And reduce the plot height further so the top and bottom are aligned
      // with the center of the labels.
      Size plotSize = Size(size.width - yAxisWidth, axisHeight - charHeight);
      Offset plotOffset = Offset(yAxisWidth, charHeight / 2);
      paintPlot(canvas, plotSize, plotOffset, xAxis, yAxis, drawTicks);
    } else {
      // When height is constrained, let both the axis and the plot take the
      // full height and don't draw the xaxis.
      final yAxisWidth =
          paintYAxis(canvas, size.height, yAxis, drawTicks, minText) +
              charHeight / 2;

      Size plotSize = Size(size.width - yAxisWidth, size.height);
      Offset plotOffset = Offset(yAxisWidth, 0);
      paintPlot(canvas, plotSize, plotOffset, xAxis, yAxis, drawTicks);
    }

    _lastPaintEvt = history.endValueTime;
  }

  TextPainter layoutText(String text) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: theme.textTheme.labelSmall));
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

  /// Paints the actual plot and the surrounding grid.
  void paintPlot(Canvas canvas, Size size, Offset offset, _XAxis xAxis,
      _YAxis yAxis, bool drawTicks) {
    final segWidth = size.width / history.values.length;
    // Draw slightly wider than the theoretical to avoid gaps between segments.
    final drawWidth = segWidth + 1.0;
    final rangeNative = max(yAxis.maxNative - yAxis.minNative, 0.01);

    final greyStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.colorScheme.primaryContainer;

    // Start with a black background.
    canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        Paint()..color = theme.colorScheme.onPrimary);

    // Draw vertical slices for each segment of time.
    // TODO: The additional width is annoying. Instead first paint invalid color
    // then for each valid plock of segments paint a black background then a
    // white polygon with the exact shape.
    for (int i = 0; i < history.values.length; i++) {
      final val = history.values[i];
      final dx = segWidth * i + offset.dx;
      if (val == null) {
        // Missing data is shown as a full height grey slice.
        canvas.drawRect(Rect.fromLTWH(dx, offset.dy, drawWidth, size.height),
            Paint()..color = theme.colorScheme.surfaceTint);
      } else {
        // Present data is shown as a primary slice of the appropriate height.
        final h = min((val - yAxis.minNative) / rangeNative, 1.0) * size.height;
        final dy = offset.dy + (size.height - h);
        canvas.drawRect(Rect.fromLTWH(dx, dy, drawWidth, h),
            Paint()..color = theme.colorScheme.primary);
      }
    }

    // Add axis lines.
    if (drawTicks) {
      final dyStep = size.height / (yAxis.tickCount - 1);
      for (double dy = dyStep + offset.dy;
          dy < size.height - 1.0;
          dy += dyStep) {
        canvas.drawLine(Offset(offset.dx, dy),
            Offset(offset.dx + size.width, dy), greyStroke);
      }
      for (int segment = xAxis.firstTickSegment;
          segment < history.values.length;
          segment += xAxis.tickSpacing) {
        final dx = offset.dx + (segment / history.values.length) * size.width;
        canvas.drawLine(Offset(dx, offset.dy),
            Offset(dx, offset.dy + size.height), greyStroke);
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
