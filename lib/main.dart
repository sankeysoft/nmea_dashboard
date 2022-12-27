// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'state/data_set.dart';
import 'state/settings.dart';
import 'ui/theme.dart';
import 'ui/page_data_table.dart';

void main() {
  runApp(const NmeaDashboardApp());
}


/// The root widget for the application.
class NmeaDashboardApp extends StatelessWidget {
  const NmeaDashboardApp({super.key});

  // The root of the application needs to asynchronously load setttings
  // before deciding the theme and delegating the to a themed application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Settings.create(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final settings = snapshot.data!;
            return MultiProvider(providers: [
              ChangeNotifierProvider<Settings>(create: (_) => settings),
              ChangeNotifierProvider<NetworkSettings>(
                  create: (_) => settings.network),
              ChangeNotifierProvider<UiSettings>(create: (_) => settings.ui),
              ChangeNotifierProvider<PageSettings>(
                  create: (_) => settings.pages),
              ChangeNotifierProvider<DerivedDataSettings>(
                  create: (_) => settings.derived),
              ChangeNotifierProvider<DataSet>(
                  create: (_) => DataSet(settings.network, settings.derived)),
            ], child: _ThemedApp());
          } else {
            return _LoadingPage();
          }
        });
  }
}

/// A simple stateless page to display while settings are loading.
class _LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    //TODO: Make this not ugly
    return MaterialApp(
        title: 'NMEA Dashboard',
        theme: ThemeData.dark(),
        home: const Text("Loading..."));
  }
}

/// The main functional application. Assumes settings can be provided.
class _ThemedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uiSettings = Provider.of<UiSettings>(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: MaterialApp(
          title: 'NMEA Dashboard',
          theme: createThemeData(uiSettings),
          home: _HomePage(),
        ));
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
    controller.animateToPage(intent.page,
        duration: const Duration(milliseconds: 400), curve: Curves.ease);
    return null;
  }
}

class _HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dataSettings = Provider.of<PageSettings>(context);
    final initialIdx = dataSettings.selectedPageIndex ?? 0;
    final controller = PageController(initialPage: initialIdx, keepPage: false);
    // Even though we tell the controlled to not keep page it doesn't use the
    // initialIdx correctly. Force a transition post-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.jumpToPage(initialIdx);
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
                    return ChangeNotifierProvider<KeyedDataPageSpec>.value(
                        value: pageSpec,
                        child: const DataTablePage());
                  }).toList()),
            )));
  }
}
