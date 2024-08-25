// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:provider/provider.dart';

import 'abstract.dart';

class CurrentValueCell extends HeadingContentsCell {
  CurrentValueCell(
      {required element, required formatter, required super.spec, super.key})
      : super(
            heading: spec.name ?? element.shortName ?? ' ',
            units: formatter.units ?? ' ',
            content: ChangeNotifierProvider<DataElement>.value(
                value: element, child: _Value(formatter)));
}

class _Value extends StatelessWidget {
  final Formatter formatter;

  const _Value(this.formatter);

  @override
  Widget build(BuildContext context) {
    final element = Provider.of<DataElement>(context);
    final value = element.value;

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.headlineLarge!,
      // Let the displayable choose to discard some of the available vertical
      // space then scale the text as large as we can in the remainder.
      child: FractionallySizedBox(
        heightFactor: formatter.heightFraction,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(formatter.format(value), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
