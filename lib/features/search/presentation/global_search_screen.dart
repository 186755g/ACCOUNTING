import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';
import '../../parties/presentation/party_management_screen.dart';
import '../../products/presentation/product_management_screen.dart';
import '../../sales/presentation/sale_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    required this.database,
    this.initialQuery = '',
    super.key,
  });

  final LocalDatabase database;
  final String initialQuery;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Sale> _sales = [];
  List<Purchase> _purchases = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _from?.toUtc();
      final to = _to?.toUtc();
      final results = await Future.wait<Object>([
        widget.database.products.search(
          query,
          fromDate: from,
          toDate: to,
          limit: 100,
        ),
        widget.database.customers.search(
          query,
          fromDate: from,
          toDate: to,
          limit: 100,
        ),
        widget.database.suppliers.search(
          query,
          fromDate: from,
          toDate: to,
          limit: 100,
        ),
        widget.database.sales.search(
          query,
          fromDate: from,
          toDate: to,
          limit: 100,
        ),
        widget.database.purchases.search(
          query,
          fromDate: from,
          toDate: to,
          limit: 100,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _customers = results[1] as List<Customer>;
        _suppliers = results[2] as List<Supplier>;
        _sales = results[3] as List<Sale>;
        _purchases = results[4] as List<Purchase>;
        _loading = false;
        _searched = true;
      });
    } catch (error) {
      debugPrint('Global search failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _searched = true;
      });
    }
  }

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _from == null || _to == null
          ? null
          : DateTimeRange(
              start: _from!,
              end: _to!.subtract(const Duration(days: 1)),
            ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
    });
    if (_controller.text.trim().isNotEmpty) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final hasResults =
        _products.isNotEmpty ||
        _customers.isNotEmpty ||
        _suppliers.isNotEmpty ||
        _sales.isNotEmpty ||
        _purchases.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(strings.globalSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('global-search-query'),
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: strings.searchEverything,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: strings.search,
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _selectRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _from == null || _to == null
                          ? strings.chooseDateRange
                          : '${_date(_from!)} - '
                                '${_date(_to!.subtract(const Duration(days: 1)))}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: !_searched
                ? Center(child: Text(strings.searchEverything))
                : !hasResults && !_loading && _error == null
                ? Center(child: Text(strings.noSearchResults))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _section(strings.productsSection),
                      for (final product in _products)
                        ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.sku ?? ''} · '
                            '${strings.stockQuantity}: ${product.stockQuantity}',
                          ),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ProductManagementScreen(
                                database: widget.database,
                              ),
                            ),
                          ),
                        ),
                      _section(strings.customersSection),
                      for (final customer in _customers)
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(customer.name),
                          subtitle: Text(customer.phone ?? ''),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => PartyManagementScreen(
                                database: widget.database,
                                isSupplier: false,
                              ),
                            ),
                          ),
                        ),
                      _section(strings.suppliersSection),
                      for (final supplier in _suppliers)
                        ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(supplier.name),
                          subtitle: Text(supplier.phone ?? ''),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => PartyManagementScreen(
                                database: widget.database,
                                isSupplier: true,
                              ),
                            ),
                          ),
                        ),
                      _section(strings.salesSection),
                      for (final sale in _sales)
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text('${strings.saleNumber} ${sale.id}'),
                          subtitle: Text(_date(sale.date)),
                          trailing: Text(
                            (sale.totalMinor / 100).toStringAsFixed(2),
                          ),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => SaleDetailScreen(
                                database: widget.database,
                                saleId: sale.id,
                              ),
                            ),
                          ),
                        ),
                      _section(strings.purchasesSection),
                      for (final purchase in _purchases)
                        ListTile(
                          leading: const Icon(Icons.shopping_bag_outlined),
                          title: Text(
                            '${strings.purchaseTitle} ${purchase.id}',
                          ),
                          subtitle: Text(_date(purchase.date)),
                          trailing: Text(
                            (purchase.totalMinor / 100).toStringAsFixed(2),
                          ),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => PurchaseManagementScreen(
                                database: widget.database,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
