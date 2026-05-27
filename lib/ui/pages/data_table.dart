// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/settings/ui.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:nmea_dashboard/ui/cells/creation.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarms.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_elements.dart';
import 'package:nmea_dashboard/ui/forms/edit_page.dart';
import 'package:nmea_dashboard/ui/forms/edit_pages.dart';
import 'package:nmea_dashboard/ui/forms/ui_settings.dart';
import 'package:nmea_dashboard/ui/forms/network_settings.dart';
import 'package:nmea_dashboard/ui/forms/view_help.dart';
import 'package:nmea_dashboard/ui/forms/view_log.dart';
import 'package:nmea_dashboard/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// A page that fills the available space with a table of
/// displayable data created from the supplied specs.
class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<DataTablePage> createState() => _DataTablePageState();
}

class _DataTablePageState extends State<DataTablePage> {
  AlarmManager? _alarmManager;
  UiSettings? _uiSettings;
  bool _isWarningDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _uiSettings ??= Provider.of<UiSettings>(context, listen: false);
    if (_alarmManager == null) {
      _alarmManager = Provider.of<AlarmManager>(context, listen: false);
      _alarmManager!.unacknowledgedWarnings.addListener(_handleWarningsChanged);
      // Surface any warnings that were already present before this page mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleWarningsChanged());
    }
  }

  @override
  void dispose() {
    _alarmManager?.unacknowledgedWarnings.removeListener(_handleWarningsChanged);
    super.dispose();
  }

  void _handleWarningsChanged() {
    if (mounted && !_isWarningDialogOpen && _alarmManager!.unacknowledgedWarnings.isNotEmpty) {
      _showWarningDialog();
    }
  }

  void _showWarningDialog() {
    if (_isWarningDialogOpen) {
      return;
    }
    _isWarningDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WarningDialog(alarmManager: _alarmManager!, uiSettings: _uiSettings!),
    ).whenComplete(() => _isWarningDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final dataSet = Provider.of<DataSet>(context);
    final pageSpec = Provider.of<DataPageSpec>(context);
    final settings = Provider.of<UiSettings>(context);

    if (settings.keepScreenAwake) {
      // Force screen awake every draw in case the OS has released the lock. Disable happens
      // only once on a change to the setting.
      WakelockPlus.enable();
    }

    return Scaffold(
      appBar: AppBar(title: Text(pageSpec.name), actions: [_EditPageButton()]),
      drawer: Drawer(child: _DrawerContent()),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox.expand(
              child: _Grid(
                cells: pageSpec.cells.map((cellSpec) => createCell(dataSet, cellSpec)).toList(),
                numColumns: _decideNumColumns(constraints, pageSpec.cells.length),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A modal popup listing currently unacknowledged warnings.
class _WarningDialog extends StatefulWidget {
  final AlarmManager alarmManager;
  final UiSettings uiSettings;

  const _WarningDialog({required this.alarmManager, required this.uiSettings});

  @override
  State<_WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<_WarningDialog> {
  bool _popped = false;

  void _popOnce() {
    if (_popped || !mounted) {
      return;
    }
    _popped = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final basicTheme = Theme.of(context);
    final warningTheme = createThemeData(widget.uiSettings, alarm: AlarmLevel.warning);

    return ListenableBuilder(
      listenable: widget.alarmManager.unacknowledgedWarnings,
      builder: (context, _) {
        final warningSet = widget.alarmManager.unacknowledgedWarnings;

        // If the set is emptied and we've not already requested a pop, dismiss after this frame.
        if (warningSet.isEmpty && !_popped) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _popOnce());
        }
        return AlertDialog(
          backgroundColor: basicTheme.colorScheme.surfaceTint,
          title: const Text('Warning', textAlign: TextAlign.center),
          titleTextStyle: TextStyle(fontSize: 24, color: basicTheme.colorScheme.primary),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: warningSet.alarms
                .map(
                  (a) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: warningTheme.colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(a.toString()),
                  ),
                )
                .toList(),
          ),
          contentTextStyle: TextStyle(fontSize: 36, color: warningTheme.colorScheme.primary),
          actionsPadding: const EdgeInsets.all(20),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: basicTheme.colorScheme.primary,
                foregroundColor: basicTheme.colorScheme.onPrimary,
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () {
                widget.alarmManager.acknowledgeWarnings();
                _popOnce();
              },
              child: const Text('Silence'),
            ),
          ],
        );
      },
    );
  }
}

/// A button to edit the current page
class _EditPageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pageSpec = Provider.of<DataPageSpec>(context);
    final settings = Provider.of<PageSettings>(context);
    return IconButton(
      icon: const Icon(Icons.tune_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditPagePage(
            pageSpec: pageSpec,
            onCreate: (updatedSpec) {
              settings.setPage(updatedSpec);
            },
          ),
        ),
      ),
    );
  }
}

/// The content of the menu drawer.
class _DrawerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final networkSettings = Provider.of<NetworkSettings>(context);
    final uiSettings = Provider.of<UiSettings>(context);
    final packageInfo = Provider.of<PackageInfo>(context);
    final enabledColor = theme.colorScheme.onSurface;
    final enabledStyle = TextStyle(fontSize: 18, color: enabledColor);

    final headingStyle = TextStyle(color: enabledColor, fontWeight: FontWeight.bold, fontSize: 30);

    return ListView(
      // Important: Remove any padding from the ListView.
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceTint),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NMEA Dashboard', style: headingStyle),
              Text('Version: ${packageInfo.version}', style: headingStyle.copyWith(fontSize: 18)),
            ],
          ),
        ),
        CheckboxListTile(
          title: Text('Night Mode', style: enabledStyle),
          secondary: Icon(Icons.dark_mode_outlined, color: enabledColor),
          controlAffinity: ListTileControlAffinity.trailing,
          value: uiSettings.nightMode,
          onChanged: (value) {
            Navigator.pop(context);
            uiSettings.toggleNightMode();
          },
          activeColor: enabledColor,
          checkColor: theme.colorScheme.surface,
        ),
        ListTile(
          leading: Icon(Icons.lan_outlined, color: enabledColor),
          title: Text('Network', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NetworkSettingsPage(settings: networkSettings),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.content_copy_outlined, color: enabledColor),
          title: Text('Pages', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditPagesPage()));
          },
        ),
        ListTile(
          leading: Icon(Icons.hub_outlined, color: enabledColor),
          title: Text('Derived Data', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => EditDerivedElementsPage()));
          },
        ),
        ListTile(
          leading: Icon(Icons.notifications_outlined, color: enabledColor),
          title: Text('Alarms', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditAlarmsPage()));
          },
        ),
        ListTile(
          leading: Icon(Icons.text_format_outlined, color: enabledColor),
          title: Text('User Interface', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => UiSettingsPage(settings: uiSettings)));
          },
        ),
        ListTile(
          leading: Icon(Icons.analytics_outlined, color: enabledColor),
          title: Text('Debug Log', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => ViewLogPage()));
          },
        ),
        ListTile(
          leading: Icon(Icons.help_outlined, color: enabledColor),
          title: Text('Help & License', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ViewHelpPage(
                  title: 'Help Overview & License',
                  filename: 'overview.md',
                  linkToReleaseNotes: true,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A widget that fills the available space with a grid of cells each displaying one
/// of the supplied displays using the supplied number of columns.
class _Grid extends StatelessWidget {
  final List<Cell> cells;
  final int numColumns;

  const _Grid({required this.cells, required this.numColumns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate((cells.length / numColumns).ceil(), (row) {
          return Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(numColumns, (col) {
                final num = row * numColumns + col;
                return num < cells.length ? cells[num] : const EmptyCell();
              }),
            ),
          );
        }),
      ),
    );
  }
}

/// Returns the most appropriate number of columns to fit the supplied
/// number of elements into the grid constraints.
int _decideNumColumns(BoxConstraints constraints, int numElements) {
  // Each cell looks best when its about twice as wide as high.
  const idealAspect = 2.0;

  // The simplest way is just check every column count since we'll almost
  // always be less that 5. We could do a more complex algorithm based
  // on square root of the number of elements and aspect ratios, but I
  // don't feel its worth it.
  double? lastError;
  for (int cols = 1; cols <= numElements; cols++) {
    final rows = (numElements / cols).ceil();
    final aspect = (constraints.maxWidth / cols) / (constraints.maxHeight / rows);
    final error = (aspect - idealAspect).abs();
    // use the last one if if was closer to the ideal ratio.
    if (lastError != null && lastError < error) {
      return cols - 1;
    }
    lastError = error;
  }
  // The final thing we checked must have been better than everything else. Use it.
  return numElements;
}
