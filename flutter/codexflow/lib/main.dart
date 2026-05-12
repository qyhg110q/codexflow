import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n/app_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'navigation/app_navigation.dart';
import 'state/app_model.dart';
import 'theme/palette.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(CodexFlowApp(prefs: prefs));
}

class CodexFlowApp extends StatelessWidget {
  const CodexFlowApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppModel>(
      create: (_) => AppModel(prefs)..bootstrap(),
      child: Consumer<AppModel>(
        builder: (context, model, _) {
          final l10n = AppLocalizations.of(model.languageCode);
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'CodexFlow',
            locale: l10n.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Palette.canvas,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Palette.softBlue,
                primary: Palette.softBlue,
                secondary: Palette.accent,
                surface: Palette.canvas,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Palette.canvas,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Palette.mutedInk),
                titleTextStyle: roundedTextStyle(
                  size: 17,
                  weight: FontWeight.w600,
                ),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              navigationBarTheme: NavigationBarThemeData(
                height: 68,
                backgroundColor: Palette.canvas.appOpacity(0.88),
                indicatorColor: Palette.ink.appOpacity(0.07),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  return roundedTextStyle(
                    size: 11,
                    weight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? Palette.ink
                        : Palette.mutedInk,
                  );
                }),
              ),
              dividerColor: Colors.transparent,
            ),
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  Timer? _timer;

  static const _pages = <Widget>[DashboardScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!mounted) {
          return;
        }
        unawaited(context.read<AppModel>().refreshDashboard());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context.watch<AppModel>().languageCode);
    return Scaffold(
      backgroundColor: Palette.canvas,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            label: l10n.t('nav.sessions'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_rounded),
            label: l10n.t('nav.settings'),
          ),
        ],
      ),
    );
  }
}
