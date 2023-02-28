// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'abstract.dart';

/// A form that lets the user view and copy the log in real time.
class ViewHelpPage extends StatelessFormPage {
  ViewHelpPage({required String filename, required String title, super.key})
      : super(
            title: title,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            content: _ViewHelpContent(filename));
}

class _ViewHelpContent extends StatelessWidget {
  final String _filename;

  const _ViewHelpContent(this._filename);

  @override
  Widget build(BuildContext context) {
    return Form(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Expanded(child: _buildText(context)),
          const SizedBox(height: 15),
          buildCloseButton(context),
        ]));
  }

  Widget _buildText(BuildContext context) {
    // Annoyingly Image assets can be read synchronously but text can't.
    return FutureBuilder(
        future: rootBundle.loadString('assets/$_filename'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final data = snapshot.data ?? 'ASSET NOT FOUND';
            return _buildThemedMarkdown(context, data);
          } else {
            return Center(child: _spinner());
          }
        });
  }

  Widget _buildThemedMarkdown(BuildContext context, String data) {
    final current = Theme.of(context);
    return Theme(
      data: current.copyWith(
        textTheme: current.textTheme.copyWith(
          bodyMedium:
              TextStyle(fontSize: 16, color: current.colorScheme.primary),
          headlineSmall: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 2,
              color: current.colorScheme.primaryContainer),
          //bodyLarge: current.textTheme.bodyLarge!.copyWith(height: 10),
          //headlineSmall: current.textTheme.headlineSmall!.copyWith(height: 10),
        ),
      ),
      child: Markdown(data: data),
    );
  }

  Widget _spinner() {
    return const SizedBox(
        height: 40, width: 40, child: CircularProgressIndicator());
  }
}
