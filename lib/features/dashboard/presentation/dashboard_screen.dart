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
    required this.onSalesPressed,
    required this.onInventoryPressed,
    required this.onAccountPressed,
    required this.onCustomersPressed,
    required this.onSuppliersPressed,
    required this.onPurchasesPressed,
    required this.onReportsPressed,
    required this.onAnalyticsPressed,
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
  final VoidCallback onSalesPressed;
  final VoidCallback onInventoryPressed;
  final VoidCallback onAccountPressed;
  final VoidCallback onCustomersPressed;
  final VoidCallback onSuppliersPressed;
  final VoidCallback onPurchasesPressed;
  final VoidCallback onReportsPressed;
  final VoidCallback onAnalyticsPressed;
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
      debugPrint('Failed to load dashboard summary: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 21,
                  color: Colors.white,
                ),
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
            IconButton(
              key: const ValueKey('open-products'),
              tooltip: strings.productsTitle,
              onPressed: widget.onProductsPressed,
              icon: const Icon(Icons.inventory_2_outlined),
            ),
            IconButton(
              key: const ValueKey('open-inventory'),
              tooltip: strings.inventory,
              onPressed: widget.onInventoryPressed,
              icon: const Icon(Icons.warehouse_outlined),
            ),
            IconButton(
              key: const ValueKey('open-sales'),
              tooltip: strings.salesTitle,
              onPressed: widget.onSalesPressed,
              icon: const Icon(Icons.point_of_sale_outlined),
            ),
            IconButton(
              key: const ValueKey('open-reports'),
              tooltip: strings.reports,
              onPressed: widget.onReportsPressed,
              icon: const Icon(Icons.analytics_outlined),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('open-business-management'),
              tooltip: strings.businessManagement,
              onSelected: (value) {
                switch (value) {
                  case 'customers':
                    widget.onCustomersPressed();
                  case 'suppliers':
                    widget.onSuppliersPressed();
                  case 'purchases':
                    widget.onPurchasesPressed();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'customers',
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text(strings.customerManagement),
                  ),
                ),
                PopupMenuItem(
                  value: 'suppliers',
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(strings.supplierManagement),
                  ),
                ),
                PopupMenuItem(
                  value: 'purchases',
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(strings.purchaseTitle),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_horiz),
            ),
            IconButton(
              tooltip: strings.account,
              onPressed: widget.onAccountPressed,
              padding: const EdgeInsetsDirectional.only(start: 8, end: 20),
              icon: CircleAvatar(
                radius: 19,
                backgroundColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  widget.settings.ownerName.isEmpty
                      ? '?'
                      : widget.settings.ownerName.characters.first,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
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
