// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/settings.dart';
import 'abstract.dart';
import 'edit_page.dart';

/// A form that lets the user edit the list of pages.
class EditPagesPage extends StatelessFormPage {
  EditPagesPage({super.key})
      : super(
            title: 'Edit pages',
            actions: [_CopyButton(), _PasteButton(), _ResetButton()],
            content: _EditPagesContent());
}

class _ResetButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<PageSettings>(context);
    return IconButton(
        icon: const Icon(Icons.settings_backup_restore_outlined),
        onPressed: () => showDialog(
            context: context,
            builder: (context) => buildConfirmationDialog(
                context: context,
                title: 'Reset to default?',
                content: 'Do you want to replace all pages and contents '
                    'with the defaults? This action cannot be undone.',
                onPressed: () {
                  settings.useDefaults();
                  showSnackBar(context, 'Reset page definitions to default');
                })));
  }
}

class _CopyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<PageSettings>(context);
    return IconButton(
        icon: const Icon(Icons.copy_all_outlined),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: settings.toJson())).then((_) =>
              showSnackBar(context, 'Page definitions copied to clipboard'));
        });
  }
}

class _PasteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<PageSettings>(context);
    return IconButton(
        icon: const Icon(Icons.content_paste_outlined),
        onPressed: () =>
            Clipboard.getData(Clipboard.kTextPlain).then((clipboardData) {
              final text = clipboardData?.text;
              if (text == null) {
                showSnackBar(context, 'Clipboard does not contain text');
              } else if (!settings.useClipboard(text, dryRun: true)) {
                showSnackBar(context,
                    'Clipboard does not contain valid page definition json');
              } else {
                showDialog(
                    context: context,
                    builder: (context) => buildConfirmationDialog(
                        context: context,
                        title: 'Load pages from clipboard?',
                        content:
                            'Do you want to replace all pages and contents '
                            'with the clipboard data? This action cannot be undone.',
                        onPressed: () {
                          settings.useClipboard(text);
                          showSnackBar(context,
                              'Pasted page definitions from clipboard');
                        }));
              }
            }));
  }
}

class _EditPagesContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // Need an intermediate `Material` between the form and the
              // list tiles so the tile background renders correctly (see
              // the `ListTile` documentation).
              child: Material(
                  child: Consumer<PageSettings>(
                      builder: (context, settings, child) =>
                          _buildReorderableList(context, settings))),
            ),
            buildCloseButton(context),
          ]),
    );
  }

  Widget _buildReorderableList(BuildContext context, PageSettings settings) {
    List<Widget> tiles = [];
    for (final pageSpec in settings.dataPageSpecs) {
      tiles.add(_buildPageTile(context, settings, pageSpec, tiles.length));
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        List<KeyedDataPageSpec> specs = settings.dataPageSpecs.toList();
        final moved = specs.removeAt(oldIndex);
        // Correct the newIndex for the deleted item if we're moving down.
        if (newIndex > oldIndex) newIndex -= 1;
        specs.insert(newIndex, moved);
        settings.replacePages(specs);
      },
      footer: _buildAddPageTile(context, settings),
      children: tiles,
    );
  }

  Widget _buildPageTile(BuildContext context, PageSettings settings,
      KeyedDataPageSpec spec, int index) {
    return buildMovableDeletableTile(
        key: spec.key,
        index: index,
        context: context,
        title: spec.name,
        icon: const Icon(Icons.article_outlined),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditPagePage(
                    pageSpec: spec.toBareSpec(),
                    onCreate: (updatedSpec) {
                      final keyedSpec = KeyedDataPageSpec.fromBareSpec(
                          updatedSpec,
                          key: spec.key);
                      settings.setPage(keyedSpec);
                    }),
              ),
            ),
        onDeleteTap: () => showDialog(
            context: context,
            builder: (context) => buildConfirmationDialog(
                  context: context,
                  title: 'Delete ${spec.name} page?',
                  content: 'This action cannot be undone.',
                  onPressed: () => settings.removePage(spec),
                )));
  }

  Widget _buildAddPageTile(BuildContext context, PageSettings settings) {
    // Use a list tile to make this look consistent, but note its not
    // actually in the list like the others.
    return buildStaticTile(
      context: context,
      title: "Add new page",
      icon: const Icon(Icons.add_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditPagePage(onCreate: (spec) {
            final keyedSpec = KeyedDataPageSpec.fromBareSpec(spec);
            settings.setPage(keyedSpec);
          }),
        ),
      ),
    );
  }
}
