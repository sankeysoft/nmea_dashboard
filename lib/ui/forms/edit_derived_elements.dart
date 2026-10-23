// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';
import 'package:nmea_dashboard/state/settings/derived_data.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_element.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

/// A form that lets the user edit the list of derived elements.
class EditDerivedElementsPage extends StatelessFormPage {
  EditDerivedElementsPage({super.key})
    : super(
        title: 'Edit derived elements',
        actions: [
          CopyButton(
            kind: ClipboardKind.derivedData,
            getText: (context) =>
                Provider.of<DerivedDataSettings>(context, listen: false).toClipboard(),
          ),
          PasteButton(
            kind: ClipboardKind.derivedData,
            isValid: (context, text) => Provider.of<DerivedDataSettings>(
              context,
              listen: false,
            ).useClipboard(text, dryRun: true),
            onPaste: (context, text) {
              Provider.of<DerivedDataSettings>(context, listen: false).useClipboard(text);
              return null;
            },
            confirmTitle: 'Load derived data from clipboard?',
            confirmContent:
                'Do you want to replace all derived data elements '
                'with the clipboard data? This action cannot be undone.',
          ),
          const HelpButton('edit_derived_elements.md'),
        ],
        content: _EditDerivedElementsContent(),
      );
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
                builder: (context, settings, child) => _buildReorderableList(context, settings),
              ),
            ),
          ),
          buildCloseButton(context),
        ],
      ),
    );
  }

  Widget _buildReorderableList(BuildContext context, DerivedDataSettings settings) {
    List<Widget> tiles = [];
    for (final spec in settings.derivedDataSpecs) {
      tiles.add(_buildElementTile(context, settings, spec, tiles.length));
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem: (oldIndex, newIndex) {
        List<DerivedDataSpec> specs = settings.derivedDataSpecs.toList();
        final moved = specs.removeAt(oldIndex);
        specs.insert(newIndex, moved);
        settings.replaceElements(specs);
      },
      footer: _buildAddElementTile(context, settings),
      children: tiles,
    );
  }

  Widget _buildElementTile(
    BuildContext context,
    DerivedDataSettings settings,
    DerivedDataSpec spec,
    int index,
  ) {
    return buildMovableDeletableTile(
      key: spec.key,
      index: index,
      context: context,
      title: spec.name,
      icon: const Icon(Icons.data_object_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              EditDerivedDataPage(spec: spec, onCreate: (spec) => settings.setElement(spec)),
        ),
      ),
      onDeleteTap: () => showDialog(
        context: context,
        builder: (context) => buildConfirmationDialog(
          context: context,
          title: 'Delete ${spec.name} element?',
          content: 'This action cannot be undone.',
          onPressed: () => settings.removeElement(spec),
        ),
      ),
    );
  }

  Widget _buildAddElementTile(BuildContext context, DerivedDataSettings settings) {
    // Use a list tile to make this look consistent, but note its not
    // actually in the list like the others.
    return buildStaticTile(
      context: context,
      title: "Add new element",
      icon: const Icon(Icons.add_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditDerivedDataPage(
            onCreate: (spec) {
              settings.setElement(spec);
            },
          ),
        ),
      ),
    );
  }
}
