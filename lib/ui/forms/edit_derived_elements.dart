// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_element.dart';
import 'package:provider/provider.dart';

import '../../state/settings.dart';
import '../../state/specs.dart';
import 'abstract.dart';

/// A form that lets the user edit the list of derived elements.
class EditDerivedElementsPage extends StatelessFormPage {
  EditDerivedElementsPage({super.key})
      : super(
            title: 'Edit derived elements',
            actions: [
              _CopyButton(),
              _PasteButton(),
              const HelpButton('help_edit_derived_elements.md')
            ],
            content: _EditDerivedElementsContent());
}

class _CopyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<DerivedDataSettings>(context);
    return IconButton(
        icon: const Icon(Icons.copy_all_outlined),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: settings.toJson())).then((_) =>
              showSnackBar(
                  context, 'Derived data definitions copied to clipboard'));
        });
  }
}

class _PasteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<DerivedDataSettings>(context);
    return IconButton(
        icon: const Icon(Icons.content_paste_outlined),
        onPressed: () =>
            Clipboard.getData(Clipboard.kTextPlain).then((clipboardData) {
              final text = clipboardData?.text;
              if (text == null) {
                showSnackBar(context, 'Clipboard does not contain text');
              } else if (!settings.useClipboard(text, dryRun: true)) {
                showSnackBar(context,
                    'Clipboard does not contain valid data definition json');
              } else {
                showDialog(
                    context: context,
                    builder: (context) => buildConfirmationDialog(
                        context: context,
                        title: 'Load derived data from clipboard?',
                        content:
                            'Do you want to replace all derived data elements '
                            'with the clipboard data? This action cannot be undone.',
                        onPressed: () {
                          settings.useClipboard(text);
                          showSnackBar(context,
                              'Pasted derived data definitions from clipboard');
                        }));
              }
            }));
  }
}

class _EditDerivedElementsContent extends StatelessWidget {
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
                  child: Consumer<DerivedDataSettings>(
                      builder: (context, settings, child) =>
                          _buildReorderableList(context, settings))),
            ),
            buildCloseButton(context),
          ]),
    );
  }

  Widget _buildReorderableList(
      BuildContext context, DerivedDataSettings settings) {
    List<Widget> tiles = [];
    for (final spec in settings.derivedDataSpecs) {
      tiles.add(_buildElementTile(context, settings, spec, tiles.length));
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        List<DerivedDataSpec> specs = settings.derivedDataSpecs.toList();
        final moved = specs.removeAt(oldIndex);
        // Correct the newIndex for the deleted item if we're moving down.
        if (newIndex > oldIndex) newIndex -= 1;
        specs.insert(newIndex, moved);
        settings.replaceElements(specs);
      },
      footer: _buildAddElementTile(context, settings),
      children: tiles,
    );
  }

  Widget _buildElementTile(BuildContext context, DerivedDataSettings settings,
      DerivedDataSpec spec, int index) {
    return buildMovableDeletableTile(
        key: spec.key,
        index: index,
        context: context,
        title: spec.name,
        icon: const Icon(Icons.data_object_outlined),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditDerivedDataPage(
                    spec: spec, onCreate: (spec) => settings.setElement(spec)),
              ),
            ),
        onDeleteTap: () => showDialog(
            context: context,
            builder: (context) => buildConfirmationDialog(
                  context: context,
                  title: 'Delete ${spec.name} element?',
                  content: 'This action cannot be undone.',
                  onPressed: () => settings.removeElement(spec),
                )));
  }

  Widget _buildAddElementTile(
      BuildContext context, DerivedDataSettings settings) {
    // Use a list tile to make this look consistent, but note its not
    // actually in the list like the others.
    return buildStaticTile(
      context: context,
      title: "Add new element",
      icon: const Icon(Icons.add_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditDerivedDataPage(onCreate: (spec) {
            settings.setElement(spec);
          }),
        ),
      ),
    );
  }
}
