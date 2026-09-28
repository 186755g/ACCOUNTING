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
  List<Sale> _sales = [];
  Map<String, String> _customerNames = {};
  String _currencyCode = 'EGP';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sales = await widget.database.sales.getAll(limit: 100);
      final customers = await widget.database.customers.getAll(
        orderBy: 'name',
      );
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _customerNames = {for (final customer in customers) customer.id: customer.name};
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load sales: $error');
      if (!mounted) return;
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
        builder: (_) => SaleDetailScreen(
          database: widget.database,
          saleId: sale.id,
        ),
      ),
    );
  }

  String _money(int minor) =>
      '$_currencyCode ${(minor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
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
          : _sales.isEmpty
          ? Center(child: Text(strings.noSales))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _sales.length,
                itemBuilder: (context, index) {
                  final sale = _sales[index];
                  final customerName = sale.customerId == null
                      ? strings.walkInCustomer
                      : _customerNames[sale.customerId] ?? strings.customer;
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      isThreeLine: true,
                      onTap: () => _openSale(sale),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
