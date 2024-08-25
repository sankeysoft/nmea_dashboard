// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import 'abstract.dart';

/// A cell to display a fixed text string.
class TextCell extends SpecCell {
  TextCell({required text, required super.spec, super.key})
      : super(content: _TextContent(text));
}

class _TextContent extends StatelessWidget {
  final String text;

  const _TextContent(this.text);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
        style: Theme.of(context).textTheme.headlineLarge!,
        child: FittedBox(
            fit: BoxFit.contain,
            child: Text(text, textAlign: TextAlign.center)));
  }
}

/// A cell to display a spec that could not be resolved.
class NotFoundCell extends TextCell {
  NotFoundCell({required super.spec, super.key}) : super(text: 'Not Found');
}

/// An cell to display a spec whose source is Unset.
class UnsetCell extends TextCell {
  UnsetCell({required super.spec, super.key})
      : super(text: 'Hold here to select\ndata to display');
}
