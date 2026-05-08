// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:nmea_dashboard/ui/forms/view_release_notes.dart';

/// A form that lets the user view help markdown, either for the entire app or for a specific page.
class ViewHelpPage extends StatelessFormPage {
  ViewHelpPage({
    required String filename,
    required super.title,
    bool linkToReleaseNotes = false,
    super.key,
  }) : super(
         maxWidth: double.infinity,
         maxHeight: double.infinity,
         content: _ViewHelpContent(filename, linkToReleaseNotes),
       );
}

class _ViewHelpContent extends StatelessWidget {
  final String _filename;
  final bool _linkToReleaseNotes;

  const _ViewHelpContent(this._filename, this._linkToReleaseNotes);

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildText(context)),
          const SizedBox(height: 15),
          if (_linkToReleaseNotes)
            Row(
              children: [
                Expanded(
                  child: buildOtherButton(
                    context: context,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => ViewReleaseNotesPage(displayAll: true),
                      ),
                    ),
                    text: 'VERSIONS',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: buildCloseButton(context)),
              ],
            )
          else
            buildCloseButton(context),
        ],
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    // Annoyingly Image assets can be read synchronously but text can't.
    return FutureBuilder(
      future: rootBundle.loadString('assets/help/$_filename'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final data = snapshot.data ?? 'ASSET NOT FOUND';
          return buildThemedMarkdown(context, data);
        } else {
          return Center(child: spinner());
        }
      },
    );
  }
}
