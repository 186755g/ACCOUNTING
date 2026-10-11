import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../reports/presentation/reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.loadDashboard,
    required this.isDarkMode,
    required this.settings,
    required this.onLocaleChanged,
    required this.onThemeChanged,
    required this.onProductsPressed,
    required this.onNewSalePressed,
    required this.onSalesPressed,
    required this.onInventoryPressed,
    required this.onAccountPressed,
    required this.onCustomersPressed,
    required this.onSuppliersPressed,
    required this.onPurchasesPressed,
    required this.onReportsPressed,
    required this.onAnalyticsPressed,
    required this.onExpensesPressed,
    required this.onSearchPressed,
    required this.onSalePressed,
    super.key,
  });

  final DashboardDataLoader loadDashboard;
  final bool isDarkMode;
  final AppSettings settings;
  final Future<void> Function(Locale) onLocaleChanged;
  final VoidCallback onThemeChanged;
  final VoidCallback onProductsPressed;
  final VoidCallback onNewSalePressed;
  final VoidCallback onSalesPressed;
  final VoidCallback onInventoryPressed;
  final VoidCallback onAccountPressed;
  final VoidCallback onCustomersPressed;
  final VoidCallback onSuppliersPressed;
  final VoidCallback onPurchasesPressed;
  final VoidCallback onReportsPressed;
  final VoidCallback onAnalyticsPressed;
  final VoidCallback onExpensesPressed;
  final ValueChanged<String> onSearchPressed;
  final ValueChanged<String> onSalePressed;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  DashboardSummary? _summary;
  List<FinancialPeriod> _trend = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await widget.loadDashboard(DateTime.now());
      if (!mounted) return;
      setState(() {
        _summary = data.summary;
        _trend = data.trend;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      debugPrint('Failed to load dashboard summary: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _showMoreMenu() async {
    final strings = AppLocalizations.of(context);
    final destination = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuItem(
                'purchases',
                strings.purchaseTitle,
                Icons.shopping_bag_outlined,
              ),
              _menuItem(
                'suppliers',
                strings.supplierManagement,
                Icons.local_shipping_outlined,
              ),
              _menuItem(
                'expenses',
                strings.expenses,
                Icons.receipt_long_outlined,
              ),
              _menuItem(
                'inventory',
                strings.inventory,
                Icons.warehouse_outlined,
              ),
              _menuItem(
                'analytics',
                strings.analytics,
                Icons.insights_outlined,
              ),
              _menuItem('reports', strings.reports, Icons.analytics_outlined),
              _menuItem('settings', strings.settings, Icons.settings_outlined),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (destination) {
      case 'purchases':
        widget.onPurchasesPressed();
      case 'suppliers':
        widget.onSuppliersPressed();
      case 'expenses':
        widget.onExpensesPressed();
      case 'inventory':
        widget.onInventoryPressed();
      case 'analytics':
        widget.onAnalyticsPressed();
      case 'reports':
        widget.onReportsPressed();
      case 'settings':
        widget.onAccountPressed();
    }
  }

  Future<void> _showQuickActions() async {
    final strings = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  strings.quickActions,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            _menuItem(
              'new-sale',
              strings.newSale,
              Icons.point_of_sale_outlined,
            ),
            _menuItem(
              'add-product',
              strings.addProduct,
              Icons.add_box_outlined,
            ),
            _menuItem(
              'add-expense',
              strings.addExpense,
              Icons.receipt_long_outlined,
            ),
            _menuItem(
              'receive-payment',
              strings.receivePayment,
              Icons.payments_outlined,
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'new-sale':
        widget.onNewSalePressed();
      case 'add-product':
        widget.onProductsPressed();
      case 'add-expense':
        widget.onExpensesPressed();
      case 'receive-payment':
        widget.onCustomersPressed();
    }
  }

  Widget _menuItem(String value, String label, IconData icon) => ListTile(
    key: ValueKey(value),
    leading: Icon(icon),
    title: Text(label),
    onTap: () => Navigator.pop(context, value),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Directionality(
      textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 24,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/app_icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                key: const ValueKey('app-logo'),
              ),
              const SizedBox(width: 11),
              Text(strings.appName),
            ],
          ),
          actions: [
            IconButton(
              tooltip: strings.viewMode,
              onPressed: widget.onThemeChanged,
              icon: Icon(
                widget.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            TextButton(
              onPressed: () async => widget.onLocaleChanged(
                strings.isArabic ? const Locale('en') : const Locale('ar'),
              ),
              child: Text(strings.language),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('quick-action-menu'),
          onPressed: _showQuickActions,
          icon: const Icon(Icons.add),
          label: Text(strings.quickActions),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: strings.home,
            ),
            NavigationDestination(
              key: const ValueKey('open-products'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: strings.productsTitle,
            ),
            NavigationDestination(
              key: const ValueKey('open-sales'),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: strings.salesTitle,
            ),
            NavigationDestination(
              key: const ValueKey('open-customers'),
              icon: const Icon(Icons.people_outline),
              label: strings.customers,
            ),
            NavigationDestination(
              key: const ValueKey('open-business-management'),
              icon: const Icon(Icons.more_horiz),
              label: strings.more,
            ),
          ],
          onDestinationSelected: (index) {
            switch (index) {
              case 1:
                widget.onProductsPressed();
              case 2:
                widget.onSalesPressed();
              case 3:
                widget.onCustomersPressed();
              case 4:
                _showMoreMenu();
            }
          },
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 600 ? 18.0 : 32.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcome(context, strings, constraints.maxWidth),
                      const SizedBox(height: 24),
                      if (_loadError != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.error_outline),
                            title: Text(_loadError!),
                            trailing: IconButton(
                              onPressed: _loadDashboard,
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        )
                      else if (_loading)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(strings.loading),
                        ),
                      _buildStats(context, strings, constraints.maxWidth),
                      const SizedBox(height: 28),
                      _buildSectionHeading(
                        context,
                        title: strings.salesOverTime,
                        trailing: TextButton(
                          onPressed: widget.onAnalyticsPressed,
                          child: Text(strings.analytics),
                        ),
                      ),
                      FinancialTrendChart(
                        periods: _trend,
                        currencyCode: widget.settings.currencyCode,
                        salesLabel: strings.salesOverTimeLabel,
                        profitLabel: strings.profitOverTimeLabel,
                        expensesLabel: strings.expensesOverTimeLabel,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeading(
                        context,
                        title: strings.recentTransactions,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            strings.today,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTransactions(context, strings),
                      const SizedBox(height: 28),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.onReportsPressed,
                            icon: const Icon(Icons.description_outlined),
                            label: Text(strings.reports),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onAnalyticsPressed,
                            icon: const Icon(Icons.insights_outlined),
                            label: Text(strings.analytics),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcome(
    BuildContext context,
    AppLocalizations strings,
    double width,
  ) {
    final compact = width < 650;
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.dashboard,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 6),
        Text(
          strings.greeting,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          strings.dashboardSubtitle,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );

    final search = SizedBox(
      width: compact ? double.infinity : 300,
      child: AppTextField(
        controller: _searchController,
        hint: strings.search,
        prefixIcon: Icons.search_rounded,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value.trim()),
        onSubmitted: widget.onSearchPressed,
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [greeting, const SizedBox(height: 18), search],
      );
    }

    return Row(
      children: [
        Expanded(child: greeting),
        const SizedBox(width: 24),
        search,
      ],
    );
  }

  Widget _buildStats(
    BuildContext context,
    AppLocalizations strings,
    double width,
  ) {
    final summary = _summary;
    final financial = summary?.financial;
    String money(int minor) =>
        '${widget.settings.currencyCode} ${(minor / 100).toStringAsFixed(2)}';
    final columns = width >= 1000 ? 4 : 2;
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: width < 400 ? 1.25 : 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(
          label: strings.todaySales,
          value: financial == null ? '—' : money(financial.netSalesMinor),
          icon: Icons.account_balance_wallet_outlined,
        ),
        StatCard(
          label: strings.dashboardTodayProfit,
          value: financial == null ? '—' : money(financial.grossProfitMinor),
          icon: Icons.trending_up,
        ),
        StatCard(
          label: strings.dashboardTodayExpenses,
          value: financial == null ? '—' : money(financial.expensesMinor),
          icon: Icons.payments_outlined,
        ),
        StatCard(
          label: strings.dashboardTodayNetProfit,
          value: financial == null ? '—' : money(financial.netProfitMinor),
          icon: Icons.account_balance,
        ),
        StatCard(
          label: strings.totalProducts,
          value: summary == null ? '—' : '${summary.productCount}',
          icon: Icons.inventory_2_outlined,
        ),
        StatCard(
          label: strings.lowStock,
          value: summary == null ? '—' : '${summary.lowStockCount}',
          icon: Icons.inventory_2_outlined,
          isPositive: false,
        ),
        StatCard(
          label: strings.customerOutstanding,
          value: summary == null
              ? '—'
              : money(summary.customerOutstandingMinor),
          icon: Icons.person_outline,
        ),
        StatCard(
          label: strings.supplierOutstanding,
          value: summary == null
              ? '—'
              : money(summary.supplierOutstandingMinor),
          icon: Icons.local_shipping_outlined,
        ),
      ],
    );
  }

  Widget _buildTransactions(BuildContext context, AppLocalizations strings) {
    final sales = (_summary?.recentSales ?? [])
        .where(
          (sale) =>
              _query.isEmpty ||
              sale.id.toLowerCase().contains(_query.toLowerCase()) ||
              (sale.customerName ?? '').toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList(growable: false);

    if (sales.isEmpty) {
      return EmptyState(
        title: _query.isEmpty ? strings.noRecentSales : strings.noSearchResults,
        message: strings.isArabic
            ? 'ستظهر المبيعات المسجلة هنا.'
            : 'Recorded sales will appear here.',
        icon: Icons.search_off_rounded,
      );
    }

    return Column(
      children: [
        for (final sale in sales)
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text(
                '${strings.saleNumber} '
                '${sale.id.substring(0, sale.id.length < 8 ? sale.id.length : 8)}',
              ),
              subtitle: Text(
                '${sale.customerName?.isNotEmpty == true ? sale.customerName : strings.walkInCustomer}'
                ' · ${sale.date.toLocal().toString().split('.').first}',
              ),
              trailing: Text(
                '${widget.settings.currencyCode} '
                '${(sale.totalMinor / 100).toStringAsFixed(2)}',
              ),
              onTap: () => widget.onSalePressed(sale.id),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeading(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    );
  }
}
