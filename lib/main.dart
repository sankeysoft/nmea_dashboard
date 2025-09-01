// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/history.dart';
import 'package:nmea_dashboard/state/log_set.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/view_help.dart';
import 'package:nmea_dashboard/ui/theme.dart';
import 'package:nmea_dashboard/ui/pages/data_table.dart';

/// The minimum time for which we display the loading screen.
const Duration loadingScreenTime = Duration(seconds: 1);

/// A standard overlay used before and after loading.
const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.black,
  systemNavigationBarIconBrightness: Brightness.light,
);

void main() {
  final logSet = LogSet();
  Logger.root.onRecord.listen((record) => logSet.add(record));
  runApp(NmeaDashboardApp(logSet));
}

/// The root widget for the application.
class NmeaDashboardApp extends StatelessWidget {
  final LogSet _logSet;

  const NmeaDashboardApp(this._logSet, {super.key});

  // The root of the application needs to asynchronously load setttings
  // before deciding the theme and delegating the to a themed application.
  @override
  Widget build(BuildContext context) {
    /// Display the loading screen for at least the minimum time, potentially
    /// it could be diplayed longer if loading the setting takes a while.
    return FutureBuilder(
      future: Future.wait([
        Settings.create(),
        HistoryManagerImpl.create(),
        Future.delayed(loadingScreenTime),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final settings = snapshot.data![0];
          final historyManager = snapshot.data![1];
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<LogSet>(create: (_) => _logSet),
              ChangeNotifierProvider<Settings>(create: (_) => settings),
              ChangeNotifierProvider<NetworkSettings>(create: (_) => settings.network),
              ChangeNotifierProvider<UiSettings>(create: (_) => settings.ui),
              ChangeNotifierProvider<PageSettings>(create: (_) => settings.pages),
              ChangeNotifierProvider<DerivedDataSettings>(create: (_) => settings.derived),
              ChangeNotifierProvider<DataSet>(
                create: (_) => DataSet(settings.network, settings.derived, historyManager),
              ),
            ],
            child: _ThemedApp(),
          );
        } else {
          return _LoadingPage();
        }
      },
    );
  }
}

/// A simple stateless page to display while settings are loading.
class _LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'NMEA Dashboard',
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("NMEA Dashboard", style: TextStyle(fontSize: 40)),
                const SizedBox(height: 30),
                Image.asset("assets/rounded_icon.png"),
                const SizedBox(height: 60),
                const SizedBox(width: 250, child: LinearProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The main functional application. Assumes settings can be provided.
class _ThemedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uiSettings = Provider.of<UiSettings>(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'NMEA Dashboard',
        theme: createThemeData(uiSettings),
        home: _HomePage(),
      ),
    );
  }
}

/// An intent to select one of the data pages.
class SelectPageIntent extends Intent {
  final int page;
  const SelectPageIntent(this.page);
}

/// Selects a data page using the supplied `PageController`.
class SelectPageAction extends Action<SelectPageIntent> {
  final PageController controller;

  SelectPageAction(this.controller);

  @override
  Object? invoke(SelectPageIntent intent) {
    controller.animateToPage(
      intent.page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.ease,
    );
    return null;
  }
}

class _HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dataSettings = Provider.of<PageSettings>(context);
    final uiSettings = Provider.of<UiSettings>(context);
    final initialIdx = dataSettings.selectedPageIndex ?? 0;
    final controller = PageController(initialPage: initialIdx, keepPage: false);
    // Even though we tell the controller to not keep page it doesn't use the
    // initialIdx correctly. Force a transition post-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.jumpToPage(initialIdx);
      if (uiSettings.firstRun) {
        uiSettings.clearFirstRun();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ViewHelpPage(title: 'Welcome to NMEA Dashboard', filename: 'help_overview.md'),
          ),
        );
      }
    });
    controller.addListener(() {
      // Record the page selection whenever we finish transitioning
      final currentPosition = controller.page;
      if (currentPosition == currentPosition!.roundToDouble()) {
        dataSettings.selectPage(currentPosition.round());
      }
    });

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        CharacterActivator('1'): SelectPageIntent(0),
        CharacterActivator('2'): SelectPageIntent(1),
        CharacterActivator('3'): SelectPageIntent(2),
        CharacterActivator('4'): SelectPageIntent(3),
        CharacterActivator('5'): SelectPageIntent(4),
        CharacterActivator('6'): SelectPageIntent(5),
        CharacterActivator('7'): SelectPageIntent(6),
        CharacterActivator('8'): SelectPageIntent(7),
        CharacterActivator('9'): SelectPageIntent(8),
      },
      child: Actions(
        actions: {SelectPageIntent: SelectPageAction(controller)},
        child: Focus(
          autofocus: true,
          child: PageView(
            controller: controller,
            children: dataSettings.dataPageSpecs.map((pageSpec) {
              return ChangeNotifierProvider<DataPageSpec>.value(
                value: pageSpec,
                child: const DataTablePage(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
