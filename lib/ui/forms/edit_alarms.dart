// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/alarm.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarm.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

/// A form that lets the user edit the list of alarms, optionally filtered to one data element.
class EditAlarmsPage extends StatelessFormPage {
  EditAlarmsPage({DataElement? element, super.key})
    : super(
        title: element == null ? 'Edit alarms' : 'Edit ${element.property.shortName} alarms',
        actions: element == null
            ? [_CopyButton(), _PasteButton(), const HelpButton('edit_alarms.md')]
            : [const HelpButton('edit_alarms.md')],
        content: _EditAlarmsContent(element),
      );
}

class _CopyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AlarmSettings>(context);
    final sm = ScaffoldMessenger.of(context);
    return IconButton(
      icon: const Icon(Icons.copy_all_outlined),
      onPressed: () {
        Clipboard.setData(
          ClipboardData(text: settings.toJson()),
        ).then((_) => showSnackBar(sm, 'Alarm definitions copied to clipboard'));
      },
    );
  }
}

class _PasteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AlarmSettings>(context);
    final sm = ScaffoldMessenger.of(context);
    return IconButton(
      icon: const Icon(Icons.content_paste_outlined),
      onPressed: () async {
        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        if (!context.mounted) return;
        final text = clipboardData?.text;
        if (text == null) {
          showSnackBar(sm, 'Clipboard does not contain text');
        } else if (!settings.useClipboard(text, dryRun: true)) {
          showSnackBar(sm, 'Clipboard does not contain valid alarm definition json');
        } else {
          showDialog(
            context: context,
            builder: (context) => buildConfirmationDialog(
              context: context,
              title: 'Load alarms from clipboard?',
              content:
                  'Do you want to replace all alarms with the clipboard data? '
                  'This action cannot be undone.',
              onPressed: () {
                settings.useClipboard(text);
                showSnackBar(sm, 'Pasted alarm definitions from clipboard');
              },
            ),
          );
        }
      },
    );
  }
}

class _EditAlarmsContent extends StatelessWidget {
  final DataElement? _dataElement;

  const _EditAlarmsContent(this._dataElement);

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
              child: Consumer<AlarmSettings>(
                builder: (context, settings, child) => _buildReorderableList(context, settings),
              ),
            ),
          ),
          buildCloseButton(context),
        ],
      ),
    );
  }

  Widget _buildReorderableList(BuildContext context, AlarmSettings settings) {
    List<Widget> tiles = [];

    for (final spec in settings.alarmSpecs) {
      // If we are filtered to a data element, only add alarms that match.
      if (_dataElement == null ||
          (spec.source == _dataElement.source.name) && spec.element == _dataElement.name) {
        tiles.add(_buildElementTile(context, settings, spec, tiles.length));
      }
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        // In filtered mode it doesn't make sense to manage ordering of the global list, ignore.
        if (_dataElement == null) {
          List<AlarmSpec> specs = settings.alarmSpecs.toList();
          final moved = specs.removeAt(oldIndex);
          // Correct the newIndex for the deleted item if we're moving down.
          if (newIndex > oldIndex) newIndex -= 1;
          specs.insert(newIndex, moved);
          settings.replaceElements(specs);
        }
      },
      footer: _buildAddElementTile(context, settings),
      children: tiles,
    );
  }

  Widget _buildElementTile(
    BuildContext context,
    AlarmSettings settings,
    AlarmSpec spec,
    int index,
  ) {
    final dataSet = Provider.of<DataSet>(context);
    Alarm? alarm;
    try {
      alarm = Alarm.fromSpec(spec, (s, e) => dataSet.find(s, e));
    } catch (e) {
      alarm = null;
    }

    Icon icon;
    if (alarm == null) {
      icon = const Icon(Icons.question_mark);
    } else if (alarm.level == AlarmLevel.warning) {
      icon = const Icon(Icons.warning);
    } else {
      icon = const Icon(Icons.info_outlined);
    }
    final alarmTitle = alarm?.toString() ?? "Invalid spec";

    return buildMovableDeletableTile(
      key: spec.key,
      index: index,
      context: context,
      title: alarmTitle,
      icon: icon,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditAlarmPage(
            element: _dataElement,
            spec: spec,
            onCreate: (spec) => settings.setAlarm(spec),
          ),
        ),
      ),
      onDeleteTap: () => showDialog(
        context: context,
        builder: (context) => buildConfirmationDialog(
          context: context,
          title: 'Delete $alarmTitle',
          content: 'This action cannot be undone.',
          onPressed: () => settings.removeElement(spec),
        ),
      ),
    );
  }

  Widget _buildAddElementTile(BuildContext context, AlarmSettings settings) {
    // Use a list tile to make this look consistent, but note its not
    // actually in the list like the others.
    return buildStaticTile(
      context: context,
      title: "Add new alarm",
      icon: const Icon(Icons.add_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              EditAlarmPage(element: _dataElement, onCreate: (spec) => settings.setAlarm(spec)),
        ),
      ),
    );
  }
}
