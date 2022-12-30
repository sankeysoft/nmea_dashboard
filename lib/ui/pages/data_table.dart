// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/ui/forms/edit_derived_elements.dart';
import 'package:nmea_dashboard/ui/forms/ui_settings.dart';
import 'package:nmea_dashboard/ui/forms/network_settings.dart';
import 'package:provider/provider.dart';

import '../../state/data_set.dart';
import '../../state/displayable.dart';
import '../forms/edit_cell.dart';
import '../forms/edit_page.dart';
import '../forms/edit_pages.dart';

/// A page that fills the available space with a table of
/// displayable data created from the supplied specs.
class DataTablePage extends StatelessWidget {
  const DataTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dataSet = Provider.of<DataSet>(context);
    final pageSpec = Provider.of<KeyedDataPageSpec>(context);

    return Scaffold(
      appBar: AppBar(title: Text(pageSpec.name), actions: [_EditPageButton()],),
      drawer: Drawer(child: _DrawerContent()),
      body: LayoutBuilder(builder: (context, constraints) {
        return SizedBox.expand(
          child: _Grid(
              displayables: pageSpec.cells
                  .map((cellSpec) => dataSet.find(cellSpec))
                  .toList(),
              numColumns:
                  _decideNumColumns(constraints, pageSpec.cells.length)),
        );
      }),
    );
  }
}

/// A button to edit the current page
class _EditPageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pageSpec = Provider.of<KeyedDataPageSpec>(context);
    final settings = Provider.of<PageSettings>(context);
    return IconButton(
        icon: const Icon(Icons.tune_outlined),
        onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditPagePage(
                    pageSpec: pageSpec.toBareSpec(),
                    onCreate: (updatedSpec) {
                      final keyedSpec = KeyedDataPageSpec.fromBareSpec(
                          updatedSpec,
                          key: pageSpec.key);
                      settings.setPage(keyedSpec);
                    }),
              ),
            ));
  }
}

/// The content of the menu drawer.
class _DrawerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final networkSettings = Provider.of<NetworkSettings>(context);
    final uiSettings = Provider.of<UiSettings>(context);
    final packageInfo = Provider.of<Settings>(context).packageInfo;
    final enabledColor = theme.colorScheme.onBackground;
    final enabledStyle = TextStyle(fontSize: 18, color: enabledColor);
    final disabledStyle = enabledStyle.copyWith(color: theme.disabledColor);

    final headingStyle = TextStyle(
        color: enabledColor, fontWeight: FontWeight.bold, fontSize: 30);

    return ListView(
      // Important: Remove any padding from the ListView.
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceTint,
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NMEA Dashboard', style: headingStyle),
              Text('Version: ${packageInfo.version}',
                  style: headingStyle.copyWith(fontSize: 18)),
            ])),
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
          checkColor: theme.colorScheme.background,
        ),
        ListTile(
          leading: Icon(Icons.lan_outlined, color: enabledColor),
          title: Text('Network', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    NetworkSettingsPage(settings: networkSettings),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.content_copy_outlined, color: enabledColor),
          title: Text('Pages', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditPagesPage(),
              ),
            );
          },
        ),
        ListTile(
            leading: Icon(Icons.hub_outlined, color: enabledColor),
            title: Text('Data', style: enabledStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditDerivedElementsPage(),
                ),
              );
            }),
        ListTile(
          leading: Icon(Icons.text_format_outlined, color: enabledColor),
          title: Text('UI Style', style: enabledStyle),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UiSettingsPage(settings: uiSettings),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.analytics_outlined, color: theme.disabledColor),
          title: Text('Debug Log', style: disabledStyle),
        ),
        ListTile(
          leading: Icon(Icons.help_outlined, color: theme.disabledColor),
          title: Text('Help', style: disabledStyle),
        ),
      ],
    );
  }
}

/// A widget that fills the available space with a grid of cells each displaying one
/// of the supplied displays using the supplied number of columns.
class _Grid extends StatelessWidget {
  final List<Displayable> displayables;
  final int numColumns;

  const _Grid({required this.displayables, required this.numColumns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            List.generate((displayables.length / numColumns).ceil(), (row) {
          return Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(numColumns, (col) {
                  final cellNum = row * numColumns + col;
                  final displayable = cellNum < displayables.length
                      ? displayables[cellNum]
                      : null;
                  return _Cell(displayable: displayable);
                }),
              ));
        }),
      ),
    );
  }
}

// A single data cell used to display an element of data, if displayable is
// not supplied the cell will be empty but cover the space space.
class _Cell extends StatelessWidget {
  final Displayable? displayable;

  const _Cell({this.displayable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayable = this.displayable;

    if (displayable == null) {
      return Expanded(child: Container());
    }

    return ChangeNotifierProvider<Displayable>.value(
      value: displayable,
      child: Expanded(
        child: GestureDetector(
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => EditCellPage(spec: displayable.spec)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
            ),
            margin: const EdgeInsets.all(6.0),
            padding: const EdgeInsets.all(6.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CellHeading(),
                  Expanded(child: _CellValue()),
                ]),
          ),
        ),
      ),
    );
  }
}

class _CellHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayable = Provider.of<Displayable>(context);

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.headlineMedium!,
      // Fixed aspect ratio helps ensure the titles fit on the one line
      // that we give them.
      child: AspectRatio(
        aspectRatio: 6 / 1,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: Text(displayable.heading ?? ' '),
              ),
              FittedBox(
                fit: BoxFit.contain,
                child: Text(displayable.units ?? ' '),
              )
            ]),
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayable = Provider.of<Displayable>(context);

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.headlineLarge!,
      // Let the displayable choose to discard some of the available vertical
      // space then scale the text as large as we can in the remainder.
      child: FractionallySizedBox(
        heightFactor: displayable.heightFraction,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(displayable.value ?? ' ', textAlign: TextAlign.center),
        ),
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
    final aspect =
        (constraints.maxWidth / cols) / (constraints.maxHeight / rows);
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
