import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

class HesabatiApp extends StatefulWidget {
  const HesabatiApp({super.key});

  @override
  State<HesabatiApp> createState() => _HesabatiAppState();
}

class _HesabatiAppState extends State<HesabatiApp> {
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.light;

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: DashboardScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onLocaleChanged: _changeLocale,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}
