import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/database/database.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/services/local_alert_service.dart';
import '../features/account/presentation/account_profile_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/expenses/presentation/expense_management_screen.dart';
import '../features/inventory/presentation/inventory_management_screen.dart';
import '../features/parties/presentation/party_management_screen.dart';
import '../features/products/presentation/product_management_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/search/presentation/global_search_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/sales/presentation/sale_detail_screen.dart';
import '../features/sales/presentation/sale_pos_screen.dart';

class HesabatiApp extends StatefulWidget {
  const HesabatiApp({
    required this.database,
    required this.initialSettings,
    this.dashboardDataLoader,
    this.alertService,
    super.key,
  });

  final LocalDatabase database;
  final AppSettings initialSettings;
  final DashboardDataLoader? dashboardDataLoader;
  final BusinessAlertService? alertService;

  @override
  State<HesabatiApp> createState() => _HesabatiAppState();
}

class _HesabatiAppState extends State<HesabatiApp> with WidgetsBindingObserver {
  late LocalDatabase _database = widget.database;
  late BusinessAlertService _alerts =
      widget.alertService ?? LocalAlertService(_database);
  late AppSettings _settings = widget.initialSettings;
  late ThemeMode _themeMode = switch (_settings.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  Timer? _alertRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureAlertRefresh(_settings);
    _refreshAlerts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureAlertRefresh(_settings);
      _refreshAlerts();
    } else {
      _alertRefreshTimer?.cancel();
      _alertRefreshTimer = null;
    }
  }

  void _configureAlertRefresh(AppSettings settings) {
    final enabled =
        settings.notifyLowStock ||
        settings.notifyOutOfStock ||
        settings.notifyUnpaidDebts ||
        settings.notifyOverduePayments ||
        settings.notifyDailySales;
    if (enabled && _alertRefreshTimer == null) {
      _alertRefreshTimer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => _refreshAlerts(),
      );
    } else if (!enabled) {
      _alertRefreshTimer?.cancel();
      _alertRefreshTimer = null;
    }
  }

  Future<void> _refreshAlerts() async {
    try {
      await _alerts.refresh();
    } catch (error) {
      debugPrint(
        'Could not refresh local business alerts: ${error.runtimeType}',
      );
    }
  }

  Future<void> _changeLocale(Locale locale) async {
    final updated = _settings.copyWith(localeCode: locale.languageCode);
    await _database.settings.save(updated);
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
    _configureAlertRefresh(settings);
    _refreshAlerts();
  }

  Future<void> _replaceDatabase(LocalDatabase database) async {
    final settings = await database.settings.get();
    if (settings == null) {
      throw StateError('Restored database has no app settings.');
    }
    if (!mounted) return;
    setState(() {
      _database = database;
      _alerts = LocalAlertService(database);
      _settings = settings;
      _themeMode = switch (settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
    _configureAlertRefresh(settings);
    await _refreshAlerts();
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
          loadDashboard:
              widget.dashboardDataLoader ??
              (now) => FinancialService(_database).getDashboardData(now: now),
          isDarkMode: _themeMode == ThemeMode.dark,
          settings: _settings,
          onLocaleChanged: _changeLocale,
          onThemeChanged: _toggleTheme,
          onProductsPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ProductManagementScreen(database: _database),
              ),
            );
          },
          onNewSalePressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SalePosScreen(database: _database),
              ),
            );
          },
          onSalesPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SalesScreen(database: _database),
              ),
            );
          },
          onCustomersPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PartyManagementScreen(
                  database: _database,
                  isSupplier: false,
                ),
              ),
            );
          },
          onSuppliersPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PartyManagementScreen(
                  database: _database,
                  isSupplier: true,
                ),
              ),
            );
          },
          onPurchasesPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PurchaseManagementScreen(database: _database),
              ),
            );
          },
          onInventoryPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => InventoryManagementScreen(database: _database),
              ),
            );
          },
          onReportsPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ReportsScreen(database: _database),
              ),
            );
          },
          onAnalyticsPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ReportsScreen(database: _database),
              ),
            );
          },
          onExpensesPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ExpenseManagementScreen(database: _database),
              ),
            );
          },
          onSearchPressed: (query) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => GlobalSearchScreen(
                  database: _database,
                  initialQuery: query,
                ),
              ),
            );
          },
          onSalePressed: (saleId) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    SaleDetailScreen(database: _database, saleId: saleId),
              ),
            );
          },
          onAccountPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AccountProfileScreen(
                  database: _database,
                  initialSettings: _settings,
                  onSaved: _updateSettings,
                  alerts: _alerts,
                  onDatabaseRestored: _replaceDatabase,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
