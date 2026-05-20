// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_element_stats.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:provider/provider.dart';

/// The fractional change from the current mean that saturates the change bar.
const double maxBarFraction = 0.1;

/// The width of the change bar as a fraction of the axis mark.
const double barWidth = 0.8;

/// The absolute height of the axis mark between increasing and decreasing.
const double axisHeight = 4.0;

// Identifiers for the different subwidgets in an AverageValueCell content.
enum _Component { value, changeTick }

class AverageValueCell extends HeadingContentsCell {
  AverageValueCell({
    required DataElement element,
    required OptionalStats stats,
    required formatter,
    required super.spec,
    super.key,
  }) : super(
         heading: spec.name ?? stats.interval.shortCellName(element),
         units: formatter.units ?? ' ',
         content: ChangeNotifierProvider<OptionalStats>.value(
           value: stats,
           child: CustomMultiChildLayout(
             delegate: _CellContentLayoutDelegate(),
             children: [
               LayoutId(id: _Component.value, child: _Value(formatter)),
               LayoutId(id: _Component.changeTick, child: _ChangeTick()),
             ],
           ),
         ),
       );
}

class _CellContentLayoutDelegate extends MultiChildLayoutDelegate {
  // The width fraction of the last value tick.
  static const double _tickFraction = 0.1;
  // The width fraction of the margin between elements.
  static const double _marginFraction = 0.05;

  @override
  Size getSize(BoxConstraints constraints) {
    // Always use the maximum space available.
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void performLayout(Size size) {
    // Fix the tick to the right of the cell.
    final tickSize = layoutChild(
      _Component.changeTick,
      BoxConstraints(
        maxHeight: size.height * (1.0 - _marginFraction * 2),
        maxWidth: size.width * _tickFraction,
      ),
    );
    positionChild(
      _Component.changeTick,
      Offset(size.width - tickSize.width, (size.height - tickSize.height) / 2.0),
    );

    // And scale the value height by the same fraction so the aspect ratio doesn't change.
    final valueScale = 1.0 - _tickFraction - _marginFraction;
    final valueSize = Size(size.width * valueScale, size.height * valueScale);
    layoutChild(_Component.value, BoxConstraints.tight(valueSize));
    positionChild(_Component.value, Offset(0, (size.height - valueSize.height) / 2.0));
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // The class is stateless so a change in instance never leads to relayout.
    return false;
  }
}

class _Value extends StatelessWidget {
  final Formatter formatter;

  const _Value(this.formatter);

  @override
  Widget build(BuildContext context) {
    final optionalStats = Provider.of<OptionalStats>(context);
    final stats = optionalStats.inner;
    if (stats == null) {
      return const FittedBox(
        fit: BoxFit.contain,
        child: Text("No Stats Object", textAlign: TextAlign.center),
      );
    }

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.headlineLarge!,
      // Let the displayable choose to discard some of the available vertical
      // space then scale the text as large as we can in the remainder.
      child: FractionallySizedBox(
        heightFactor: formatter.heightFraction,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(formatter.format(stats.mean), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ChangeTick extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final optionalStats = Provider.of<OptionalStats>(context);
    final stats = optionalStats.inner;
    final theme = Theme.of(context);
    if (stats != null && stats is Stats<SingleValue<double>>) {
      return CustomPaint(painter: _TickPainter(theme, stats), child: Container());
    } else {
      return Container(color: theme.colorScheme.onPrimary);
    }
  }
}

class _TickPainter extends CustomPainter {
  final ThemeData theme;
  final Stats<SingleValue<double>> stats;
  double? changeFraction;

  _TickPainter(this.theme, this.stats);

  void calculate() {
    final mean = stats.mean?.data;
    final last = stats.last?.data;
    if (mean == null || last == null || mean.abs() < 0.0001) {
      changeFraction = null;
    } else {
      changeFraction = (last - mean) / mean;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Only draw if we have a valid change to display.
    calculate();
    if (changeFraction == null) return;

    final axisFill = Paint()
      ..style = PaintingStyle.fill
      ..color = theme.colorScheme.primary;
    final changeFill = Paint()
      ..style = PaintingStyle.fill
      ..color = theme.colorScheme.primaryContainer;

    final yCentre = size.height / 2.0;
    // Draw the change bar first.
    final hBar = min(changeFraction!.abs(), maxBarFraction) / maxBarFraction * (size.height / 2);
    final yBar = (changeFraction! < 0.0) ? yCentre : yCentre - hBar;
    final wBar = barWidth * size.width;
    final xBar = (size.width - wBar) / 2.0;
    canvas.drawRect(Rect.fromLTWH(xBar, yBar, wBar, hBar), changeFill);
    // Then draw a fixed line at zero on top.
    canvas.drawRect(Rect.fromLTWH(0, yCentre - axisHeight / 2, size.width, axisHeight), axisFill);
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) {
    calculate();
    return changeFraction != oldDelegate.changeFraction;
  }
}
