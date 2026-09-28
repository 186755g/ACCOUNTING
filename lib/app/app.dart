import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/database/database.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/account/presentation/account_profile_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/inventory/presentation/inventory_management_screen.dart';
import '../features/products/presentation/product_management_screen.dart';
import '../features/sales/presentation/sales_screen.dart';

class HesabatiApp extends StatefulWidget {
  const HesabatiApp({
    required this.database,
    required this.initialSettings,
    super.key,
  });

  final LocalDatabase database;
  final AppSettings initialSettings;

  @override
  State<HesabatiApp> createState() => _HesabatiAppState();
}

class _HesabatiAppState extends State<HesabatiApp> {
  late AppSettings _settings = widget.initialSettings;
  late ThemeMode _themeMode = switch (_settings.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> _changeLocale(Locale locale) async {
    final updated = _settings.copyWith(localeCode: locale.languageCode);
    await widget.database.settings.save(updated);
    if (!mounted) return;
    setState(() => _settings = updated);
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  void _updateSettings(AppSettings settings) {
    setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: Locale(_settings.localeCode),
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
      home: Builder(
        builder: (context) => DashboardScreen(
          isDarkMode: _themeMode == ThemeMode.dark,
          settings: _settings,
          onLocaleChanged: _changeLocale,
          onThemeChanged: _toggleTheme,
          onProductsPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    ProductManagementScreen(database: widget.database),
              ),
            );
          },
          onSalesPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SalesScreen(database: widget.database),
              ),
            );
          },
          onInventoryPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    InventoryManagementScreen(database: widget.database),
              ),
            );
          },
          onAccountPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AccountProfileScreen(
                  database: widget.database,
                  initialSettings: _settings,
                  onSaved: _updateSettings,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
