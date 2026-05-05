// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarm.dart';
import 'package:provider/provider.dart';

/// A form that lets the user edit the list of alarms.
class EditAlarmsPage extends StatelessFormPage {
  EditAlarmsPage({super.key})
    : super(
        title: 'Edit alarms',
        actions: [_CopyButton(), _PasteButton()],
        content: _EditAlarmsContent(),
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
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // Need an intermediate `Material` between the form and the list
            // tiles so the tile background renders correctly (see ListTile
            // documentation).
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
      tiles.add(_buildAlarmTile(context, settings, spec, tiles.length));
    }
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        List<AlarmSpec> specs = settings.alarmSpecs.toList();
        final moved = specs.removeAt(oldIndex);
        if (newIndex > oldIndex) newIndex -= 1;
        specs.insert(newIndex, moved);
        settings.replaceAlarms(specs);
      },
      footer: _buildAddTile(context, settings),
      children: tiles,
    );
  }

  Widget _buildAlarmTile(
    BuildContext context,
    AlarmSettings settings,
    AlarmSpec spec,
    int index,
  ) {
    return buildMovableDeletableTile(
      key: spec.key,
      index: index,
      context: context,
      title: '${spec.name}  (${spec.comparison} ${_formatThreshold(spec)})',
      icon: Icon(spec.enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              EditAlarmPage(spec: spec, onSave: (newSpec) => settings.setAlarm(newSpec)),
        ),
      ),
      onDeleteTap: () => showDialog(
        context: context,
        builder: (context) => buildConfirmationDialog(
          context: context,
          title: 'Delete ${spec.name} alarm?',
          content: 'This action cannot be undone.',
          onPressed: () => settings.removeAlarm(spec),
        ),
      ),
    );
  }

  Widget _buildAddTile(BuildContext context, AlarmSettings settings) {
    return buildStaticTile(
      context: context,
      title: 'Add new alarm',
      icon: const Icon(Icons.add_outlined),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditAlarmPage(onSave: (spec) => settings.setAlarm(spec)),
        ),
      ),
    );
  }

  String _formatThreshold(AlarmSpec spec) {
    final threshold = spec.threshold;
    final asInt = threshold.truncateToDouble() == threshold;
    return asInt ? threshold.toStringAsFixed(0) : threshold.toString();
  }
}
