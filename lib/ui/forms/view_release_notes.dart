// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmea_dashboard/state/settings/common.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:pub_semver/pub_semver.dart';

/// A form that lets the user view help markdown, either for the entire app or for a specific page.
class ViewReleaseNotesPage extends StatelessFormPage {
  ViewReleaseNotesPage({required bool displayAll, super.key})
    : super(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        title: displayAll ? "Release Notes" : "What's New",
        content: _ViewReleaseNotes(displayAll),
      );
}

class _ViewReleaseNotes extends StatelessWidget {
  final bool _displayAll;

  const _ViewReleaseNotes(this._displayAll);

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
        ],
      ),
    );
  }

  Future<String> _assembleMarkdown(PackageInfo packageInfo) async {
    final regex = RegExp(r"^assets\/rel_notes\/((0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))\.md$");
    Iterable<Version> versions;
    if (_displayAll) {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      // Work in semver versions so we can sort versions correctly.
      versions = manifest
          .listAssets()
          .map((a) => regex.firstMatch(a)?.group(1) ?? '')
          .where((a) => a.isNotEmpty)
          .map((a) => Version.parse(a))
          .toList()
          .sorted((a, b) => b.compareTo(a));
    } else {
      versions = [Version.parse(packageInfo.version)];
    }

    final buff = StringBuffer();
    for (final v in versions) {
      buff.write("## Version $v\n\n");
      final data = await rootBundle.load("assets/rel_notes/$v.md");
      buff.write(utf8.decode(data.buffer.asUint8List()));
      buff.write("\n\n");
    }
    buff.write("## &nbsp; \n\n");
    final data = await rootBundle.load("assets/rel_notes/suffix.md");
    buff.write(utf8.decode(data.buffer.asUint8List()));
    return buff.toString();
  }

  Widget _buildText(BuildContext context) {
    final packageInfo = Provider.of<Settings>(context).packageInfo;

    // Annoyingly Image assets can be read synchronously but text can't.
    return FutureBuilder(
      //future: rootBundle.loadString('assets/$_filename'),
      future: _assembleMarkdown(packageInfo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final data = snapshot.data ?? 'RELEASE NOTES NOT FOUND';
          return buildThemedMarkdown(context, data);
        } else {
          return Center(child: spinner());
        }
      },
    );
  }
}
