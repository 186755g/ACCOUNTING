import 'package:flutter/material.dart';

import '../../../core/database/models/app_settings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.isDarkMode,
    required this.settings,
    required this.onLocaleChanged,
    required this.onThemeChanged,
    required this.onProductsPressed,
    required this.onSalesPressed,
    required this.onInventoryPressed,
    required this.onAccountPressed,
    super.key,
  });

  final bool isDarkMode;
  final AppSettings settings;
  final Future<void> Function(Locale) onLocaleChanged;
  final VoidCallback onThemeChanged;
  final VoidCallback onProductsPressed;
  final VoidCallback onSalesPressed;
  final VoidCallback onInventoryPressed;
  final VoidCallback onAccountPressed;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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
                      _buildStats(context, strings, constraints.maxWidth),
                      const SizedBox(height: 28),
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
                      _buildLowerSections(
                        context,
                        strings,
                        constraints.maxWidth,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        strings.demoNotice,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
    final columns = width >= 1000
        ? 4
        : width >= 600
        ? 2
        : 2;
    final ratio = width < 400 ? 1.15 : 1.35;
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: ratio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(
          label: strings.totalSales,
          value: strings.isArabic ? '٢٤٬٨٥٠ ج.م' : 'EGP 24,850',
          icon: Icons.account_balance_wallet_outlined,
          change: strings.salesChange,
        ),
        StatCard(
          label: strings.orders,
          value: strings.isArabic ? '١٢٨' : '128',
          icon: Icons.receipt_long_outlined,
          change: strings.ordersChange,
        ),
        StatCard(
          label: strings.customers,
          value: strings.isArabic ? '٨٦' : '86',
          icon: Icons.people_outline_rounded,
          change: strings.customersChange,
        ),
        StatCard(
          label: strings.lowStock,
          value: strings.isArabic ? '٠٤' : '04',
          icon: Icons.inventory_2_outlined,
          change: strings.inventoryAttention,
          isPositive: false,
        ),
      ],
    );
  }

  Widget _buildTransactions(BuildContext context, AppLocalizations strings) {
    final transactions =
        [
          (
            title: strings.isArabic ? 'بيع مباشر' : 'In-store sale',
            subtitle:
                '${strings.minutesAgo} · ${strings.isArabic ? 'أحمد محمد' : 'Ahmed Mohamed'}',
            amount: strings.isArabic ? '١٬٢٥٠ ج.م' : 'EGP 1,250',
            status: strings.completed,
            isIncome: true,
          ),
          (
            title: strings.isArabic ? 'فاتورة #١٠٢٤' : 'Invoice #1024',
            subtitle:
                '${strings.hourAgo} · ${strings.isArabic ? 'منى علي' : 'Mona Ali'}',
            amount: strings.isArabic ? '٨٥٠ ج.م' : 'EGP 850',
            status: strings.pending,
            isIncome: true,
          ),
          (
            title: strings.isArabic ? 'شراء مخزون' : 'Stock purchase',
            subtitle:
                '${strings.hoursAgo} · ${strings.isArabic ? 'مورد النور' : 'Al Noor supplier'}',
            amount: strings.isArabic ? '٣٬٤٠٠ ج.م' : 'EGP 3,400',
            status: strings.completed,
            isIncome: false,
          ),
        ].where((transaction) {
          if (_query.isEmpty) return true;
          final query = _query.toLowerCase();
          return transaction.title.toLowerCase().contains(query) ||
              transaction.subtitle.toLowerCase().contains(query);
        }).toList();

    if (transactions.isEmpty) {
      return EmptyState(
        title: strings.isArabic ? 'لا توجد نتائج' : 'No results found',
        message: strings.isArabic
            ? 'جرّب البحث بكلمة أخرى.'
            : 'Try searching for something else.',
        icon: Icons.search_off_rounded,
      );
    }

    return Column(
      children: [
        for (var index = 0; index < transactions.length; index++) ...[
          TransactionCard(
            title: transactions[index].title,
            subtitle: transactions[index].subtitle,
            amount: transactions[index].amount,
            status: transactions[index].status,
            isIncome: transactions[index].isIncome,
          ),
          if (index != transactions.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildLowerSections(
    BuildContext context,
    AppLocalizations strings,
    double width,
  ) {
    final products = _buildProducts(context, strings);
    final customers = _buildCustomers(context, strings);
    if (width < 800) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [products, const SizedBox(height: 22), customers],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: products),
        const SizedBox(width: 18),
        Expanded(child: customers),
      ],
    );
  }

  Widget _buildProducts(BuildContext context, AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(context, title: strings.bestSellingProducts),
        const SizedBox(height: 12),
        ProductCard(
          name: strings.isArabic ? 'قهوة مختصة' : 'Specialty coffee',
          category: strings.isArabic ? 'مشروبات' : 'Beverages',
          price: strings.isArabic ? '١٨٠ ج.م' : 'EGP 180',
          stockLabel: strings.isArabic ? 'متبقي ٤' : '4 left',
          icon: Icons.coffee_outlined,
          isLowStock: true,
        ),
        const SizedBox(height: 10),
        ProductCard(
          name: strings.isArabic ? 'كوب حراري' : 'Travel mug',
          category: strings.isArabic ? 'إكسسوارات' : 'Accessories',
          price: strings.isArabic ? '٣٥٠ ج.م' : 'EGP 350',
          stockLabel: strings.isArabic ? 'متوفر ٢٤' : '24 in stock',
          icon: Icons.local_cafe_outlined,
        ),
      ],
    );
  }

  Widget _buildCustomers(BuildContext context, AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(context, title: strings.topCustomers),
        const SizedBox(height: 12),
        CustomerCard(
          name: strings.isArabic ? 'أحمد محمد' : 'Ahmed Mohamed',
          subtitle: strings.isArabic
              ? 'آخر عملية · اليوم'
              : 'Last order · Today',
          amount: strings.isArabic ? '٤٬٥٠٠ ج.م' : 'EGP 4,500',
          initials: strings.isArabic ? 'أم' : 'AM',
        ),
        const SizedBox(height: 10),
        CustomerCard(
          name: strings.isArabic ? 'منى علي' : 'Mona Ali',
          subtitle: strings.isArabic
              ? 'آخر عملية · أمس'
              : 'Last order · Yesterday',
          amount: strings.isArabic ? '٢٬٨٥٠ ج.م' : 'EGP 2,850',
          initials: strings.isArabic ? 'مع' : 'MA',
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
