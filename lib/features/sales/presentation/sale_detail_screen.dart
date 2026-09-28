import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({
    required this.database,
    required this.saleId,
    super.key,
  });

  final LocalDatabase database;
  final String saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
  String? _customerName;
  List<Payment> _payments = [];
  int _unpaidMinor = 0;
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
      final sale = await widget.database.sales.getById(widget.saleId);
      if (sale == null) throw StateError('Sale was not found.');
      final customer = sale.customerId == null
          ? null
          : await widget.database.customers.getById(sale.customerId!);
      final payments = await widget.database.payments.getAll(
        filters: {'sale_id': sale.id},
        orderBy: 'date_at',
      );
      final debts = await widget.database.debts.getAll(
        filters: {'sale_id': sale.id},
      );
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _customerName = customer?.name;
        _payments = payments;
        _unpaidMinor = debts.fold(0, (sum, debt) => sum + debt.amountMinor);
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load sale details: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _money(int minor) =>
      '$_currencyCode ${(minor / 100).toStringAsFixed(2)}';

  String _paymentLabel(AppLocalizations strings, PaymentMethod method) =>
      switch (method) {
        PaymentMethod.cash => strings.cash,
        PaymentMethod.card => strings.card,
        PaymentMethod.mobileWallet => strings.wallet,
        PaymentMethod.bankTransfer => strings.bankTransfer,
        PaymentMethod.other => strings.otherPaymentMethod,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final sale = _sale;
    return Scaffold(
      appBar: AppBar(title: Text(strings.saleDetails)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : sale == null
          ? Center(child: Text(strings.saleNotFound))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${strings.saleNumber} ${sale.id}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sale.date.toLocal().toString().split('.').first,
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 28),
                        _detailRow(
                          strings.customer,
                          _customerName ?? strings.walkInCustomer,
                        ),
                        const SizedBox(height: 10),
                        for (final item in sale.items) ...[
                          _detailRow(
                            '${item.productName} × ${_quantity(item.quantity)}',
                            _money(item.totalMinor),
                          ),
                          if (item.discountMinor > 0)
                            _detailRow(
                              strings.lineDiscount,
                              '-${_money(item.discountMinor)}',
                            ),
                        ],
                        const Divider(height: 24),
                        _detailRow(strings.subtotal, _money(sale.subtotalMinor)),
                        const SizedBox(height: 8),
                        _detailRow(
                          strings.discount,
                          '-${_money(sale.totalDiscountMinor)}',
                        ),
                        const SizedBox(height: 8),
                        _detailRow(strings.total, _money(sale.totalMinor)),
                        const SizedBox(height: 8),
                        _detailRow(
                          strings.costAtSale,
                          _money(sale.costTotalMinor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.payments,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_payments.isEmpty && _unpaidMinor == 0)
                          Text(strings.noPaymentsRecorded)
                        else ...[
                          for (final payment in _payments)
                            _detailRow(
                              _paymentLabel(strings, payment.method),
                              _money(payment.amountMinor),
                            ),
                          if (_unpaidMinor > 0)
                            _detailRow(
                              strings.unpaidDebt,
                              _money(_unpaidMinor),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, textAlign: TextAlign.end),
      ],
    ),
  );

  String _quantity(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : '$quantity';
}
