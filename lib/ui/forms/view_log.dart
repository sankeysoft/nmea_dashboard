// Copyright Jody M Sankey 2023
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/log_set.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

const double _cellPadding = 4.0;

final Map<Level, Color> _levelColors = {
  Level.FINE: Colors.blue.shade300,
  Level.INFO: Colors.green.shade300,
  Level.WARNING: Colors.yellow,
  Level.SEVERE: Colors.red.shade400,
  Level.SHOUT: Colors.pink.shade300,
};

/// A form that lets the user view and copy the log in real time.
class ViewLogPage extends StatelessFormPage {
  ViewLogPage({super.key})
    : super(
        title: 'Debug Log',
        actions: [_CopyButton(), _ClearButton(), const HelpButton('help_view_log.md')],
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        content: _ViewLogContent(),
      );
}

class _ClearButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logSet = Provider.of<LogSet>(context);
    final sm = ScaffoldMessenger.of(context);
    return IconButton(
      icon: const Icon(Icons.settings_backup_restore_outlined),
      onPressed: () {
        logSet.clear();
        showSnackBar(sm, 'Cleared all log entries');
      },
    );
  }
}

class _CopyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logSet = Provider.of<LogSet>(context);
    return IconButton(
      icon: const Icon(Icons.copy_all_outlined),
      onPressed: () => _copyLogToClipboard(context, logSet),
    );
  }
}

void _copyLogToClipboard(BuildContext context, LogSet logSet) {
  final sm = ScaffoldMessenger.of(context);
  Clipboard.setData(
    ClipboardData(text: logSet.toString()),
  ).then((_) => showSnackBar(sm, 'Log copied to clipboard'));
}

class _ViewLogContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logSet = Provider.of<LogSet>(context);
    return Form(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Delegate contruction of the log listing.
          Expanded(child: _buildLogMessages(context, logSet)),
          // Gap to stop the log crowding the buttons.
          const SizedBox(height: 15),
          // Buttons that we want all users to be able to find even if they
          // might not understand toolbars.
          Row(
            children: [
              Expanded(
                child: buildOtherButton(
                  context: context,
                  onPressed: () => _copyLogToClipboard(context, logSet),
                  text: 'COPY',
                ),
              ),
              const SizedBox(width: 20.0),
              Expanded(child: buildCloseButton(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogMessages(BuildContext context, LogSet logSet) {
    final entries = logSet.entries;
    return ListView.builder(
      itemCount: entries.length,
      // Reversing the contents and listview gives better scroll behavior favoring the end.
      reverse: true,
      itemBuilder: (context, index) => _buildLogMessage(entries[entries.length - 1 - index]),
    );
  }

  Widget _buildLogMessage(LogEntry entry) {
    return DefaultTextStyle.merge(
      style: TextStyle(color: _levelColors[entry.level] ?? Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(_cellPadding),
            child: Text(DateFormat('Hms').format(entry.time)),
          ),
          Container(
            constraints: const BoxConstraints.tightFor(width: 20),
            padding: const EdgeInsets.all(_cellPadding),
            child: Center(child: Text(entry.level.toString()[0])),
          ),
          Flexible(
            child: Padding(padding: const EdgeInsets.all(_cellPadding), child: Text(entry.message)),
          ),
        ],
      ),
    );
  }
}
