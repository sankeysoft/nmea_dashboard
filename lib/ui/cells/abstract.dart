// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import '../../state/specs.dart';
import '../forms/edit_cell.dart';

// A single cell used to populate one entry in some data grid.
abstract class Cell extends StatelessWidget {
  const Cell({super.key});
}

// A cell without any contents or specification.
class EmptyCell extends Cell {
  const EmptyCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container());
  }
}

// A cell whose contents are driven based on some cell specification. Long
// holding the cell will edit this spec.
abstract class SpecCell extends Cell {
  // A widget that will display the contents of the cell.
  final Widget content;

  // The specification used to build this cell.
  final DataCellSpec spec;

  const SpecCell({required this.content, required this.spec, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
            onLongPress: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => EditCellPage(spec: spec)),
              );
            },
            child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                ),
                margin: const EdgeInsets.all(6.0),
                padding: const EdgeInsets.all(10.0),
                child: content)));
  }
}

// Identifiers for the different subwidgets in a HeadingContentsCell.
enum _Component {
  heading,
  units,
  content,
}

abstract class HeadingContentsCell extends SpecCell {
  HeadingContentsCell(
      {required heading, required units, required content, required spec, key})
      : super(
            spec: spec,
            key: key,
            content: CustomMultiChildLayout(
                delegate: _CellContentLayoutDelegate(),
                children: <Widget>[
                  LayoutId(
                      id: _Component.heading, child: _CellHeading(heading)),
                  LayoutId(id: _Component.units, child: _CellUnits(units)),
                  LayoutId(id: _Component.content, child: content),
                ]));
}

class _CellContentLayoutDelegate extends MultiChildLayoutDelegate {
  // The minimum aspect ratio of the header line.
  static const _aspectRatio = 6 / 1;
  // The maximum height of the header line as a fraction of cell height.
  static const _heightFraction = 1 / 5;

  @override
  Size getSize(BoxConstraints constraints) {
    // Always use the maximum space available.
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void performLayout(Size size) {
    Size headerSize;
    if (size.width / (size.height * _heightFraction) < _aspectRatio) {
      // The cell is high. If we used the max header height the aspect ratio
      // would be too stubby. Use less height to maintain aspect ratio.
      headerSize = Size(size.width, size.width / _aspectRatio);
    } else {
      // The cell is wide. If we used the ideal aspect ratio the header would
      // take up too much height so cap to the max height fraction.
      headerSize = Size(size.width, size.height * _heightFraction);
    }

    // Let the units choose its width first since its least likely to overflow.
    final unitsSize = layoutChild(_Component.units,
        BoxConstraints.loose(headerSize).tighten(height: headerSize.height));
    final headingMaxSize =
        Size(size.width - unitsSize.width, headerSize.height);
    positionChild(_Component.units, Offset(headingMaxSize.width, 0));
    // Let the heading take the remainder of the top row.
    layoutChild(
        _Component.heading,
        BoxConstraints.loose(headingMaxSize)
            .tighten(height: headerSize.height));
    positionChild(_Component.heading, Offset.zero);

    // And give the rest of the height to the value.
    Size valueSize = Size(size.width, size.height - headerSize.height);
    layoutChild(_Component.content, BoxConstraints.tight(valueSize));
    positionChild(_Component.content, Offset(0, headerSize.height));
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // The class is stateless so a change in instance never leads to relayout.
    return false;
  }
}

class _CellUnits extends StatelessWidget {
  final String units;

  const _CellUnits(this.units);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium!;
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(units, style: style),
    );
  }
}

class _CellHeading extends StatelessWidget {
  final String heading;

  const _CellHeading(this.heading);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium!;
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(heading, style: style),
    );
  }
}
