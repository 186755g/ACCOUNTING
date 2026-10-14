import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';
import 'sale_detail_screen.dart';
import 'sale_pos_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  List<Sale> _sales = [];
  List<Customer> _customers = [];
  Map<String, String> _customerNames = {};
  Map<String, int> _paidBySale = {};
  String _currencyCode = 'EGP';
  String? _customerId;
  String _paymentFilter = 'all';
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final sales = await widget.database.sales.getAll(
        filters: _customerId == null ? const {} : {'customer_id': _customerId},
        fromDate: _from,
        toDate: _to,
        limit: 500,
      );
      final customers = await widget.database.customers.getAll(orderBy: 'name');
      final settings = await widget.database.settings.get();
      final paidRows = await widget.database.transaction((transaction) {
        return transaction.rawQuery('''
          WITH sale_payments AS (
            SELECT sale_id, amount_minor FROM payments WHERE sale_id IS NOT NULL
            UNION ALL
            SELECT d.sale_id, p.amount_minor
            FROM payments p JOIN debts d ON d.id = p.debt_id
            WHERE d.sale_id IS NOT NULL
          )
          SELECT sale_id, SUM(amount_minor) AS paid
          FROM sale_payments GROUP BY sale_id
        ''');
      });
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _sales = sales;
        _customers = customers;
        _customerNames = {
          for (final customer in customers) customer.id: customer.name,
        };
        _paidBySale = {
          for (final row in paidRows)
            row['sale_id'] as String: (row['paid'] as num).round(),
        };
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load sales: ${error.runtimeType}');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openPos() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SalePosScreen(database: widget.database),
      ),
    );
    await _load();
  }

  Future<void> _openSale(Sale sale) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            SaleDetailScreen(database: widget.database, saleId: sale.id),
      ),
    );
  }

  String _money(int minor) =>
      '$_currencyCode ${(minor / 100).toStringAsFixed(2)}';

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
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
    await _load();
  }

  List<Sale> get _visibleSales {
    final query = _searchController.text.trim().toLowerCase();
    return _sales
        .where((sale) {
          final searchable = [
            sale.id,
            sale.notes ?? '',
            _customerNames[sale.customerId] ?? '',
            ...sale.items.map((item) => item.productName),
          ].join(' ').toLowerCase();
          if (query.isNotEmpty && !searchable.contains(query)) return false;
          final paid = _paidBySale[sale.id] ?? 0;
          final status = sale.totalMinor <= 0 || paid >= sale.totalMinor
              ? 'paid'
              : paid <= 0
              ? 'unpaid'
              : 'partial';
          return _paymentFilter == 'all' || status == _paymentFilter;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final visibleSales = _visibleSales;
    return Scaffold(
      appBar: AppBar(title: Text(strings.salesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-sale'),
        onPressed: _openPos,
        icon: const Icon(Icons.point_of_sale),
        label: Text(strings.newSale),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(strings.retry)),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: strings.search,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _from == null
                                  ? strings.dateRange
                                  : '${_dateLabel(_from)} – '
                                        '${_dateLabel(_to!.subtract(const Duration(days: 1)))}',
                            ),
                          ),
                          DropdownButton<String?>(
                            value: _customerId,
                            hint: Text(strings.customer),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(strings.allRecords),
                              ),
                              for (final customer in _customers)
                                DropdownMenuItem<String?>(
                                  value: customer.id,
                                  child: Text(customer.name),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _customerId = value);
                              _load();
                            },
                          ),
                          DropdownButton<String>(
                            value: _paymentFilter,
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(strings.paymentStatus),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text(strings.paidInFull),
                              ),
                              DropdownMenuItem(
                                value: 'partial',
                                child: Text(strings.partiallyPaid),
                              ),
                              DropdownMenuItem(
                                value: 'unpaid',
                                child: Text(strings.unpaidOnly),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _paymentFilter = value ?? 'all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleSales.isEmpty
                      ? Center(
                          child: Text(
                            _sales.isEmpty
                                ? strings.noSales
                                : strings.noSearchResults,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: visibleSales.length,
                            itemBuilder: (context, index) {
                              final sale = visibleSales[index];
                              final customerName = sale.customerId == null
                                  ? strings.walkInCustomer
                                  : _customerNames[sale.customerId] ??
                                        strings.customer;
                              return Card(
                                child: ListTile(
                                  key: ValueKey('sale-${sale.id}'),
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.receipt_long_outlined),
                                  ),
                                  title: Text(
                                    '${strings.saleNumber} ${sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id}',
                                  ),
                                  subtitle: Text(
                                    '$customerName · ${sale.date.toLocal().toString().split('.').first}'
                                    '\n${sale.items.length} ${strings.saleItems}',
                                  ),
                                  trailing: Text(
                                    _money(sale.totalMinor),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  isThreeLine: true,
                                  onTap: () => _openSale(sale),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
