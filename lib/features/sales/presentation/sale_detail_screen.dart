import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

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
  final GlobalKey _receiptKey = GlobalKey();
  Sale? _sale;
  String? _customerName;
  List<Payment> _payments = [];
  int _unpaidMinor = 0;
  String _currencyCode = 'EGP';
  bool _printingReceipt = false;
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
      final payments = [
        ...await widget.database.payments.getAll(
          filters: {'sale_id': sale.id},
          orderBy: 'date_at',
        ),
      ];
      final debts = await widget.database.debts.getAll(
        filters: {'sale_id': sale.id},
      );
      for (final debt in debts) {
        payments.addAll(
          await widget.database.payments.getAll(
            filters: {'debt_id': debt.id},
            orderBy: 'date_at',
          ),
        );
      }
      var unpaidMinor = 0;
      for (final debt in debts) {
        unpaidMinor += await widget.database.partyAccounts
            .getOutstandingForDebt(debt.id);
      }
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _customerName = customer?.name;
        _payments = payments;
        _unpaidMinor = unpaidMinor;
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load sale details: ${error.runtimeType}');
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

  Future<void> _shareReceipt(AppLocalizations strings, Sale sale) async {
    final receipt = <String>[
      strings.saleDetails,
      '${strings.saleNumber} ${sale.id}',
      sale.date.toLocal().toString().split('.').first,
      '${strings.customer}: ${_customerName ?? strings.walkInCustomer}',
      '',
      ...sale.items.map(
        (item) =>
            '${item.productName} × ${_quantity(item.quantity)}'
            ' — ${_money(item.totalMinor)}',
      ),
      '',
      '${strings.subtotal}: ${_money(sale.subtotalMinor)}',
      '${strings.discount}: -${_money(sale.totalDiscountMinor)}',
      '${strings.total}: ${_money(sale.totalMinor)}',
      ..._payments.map(
        (payment) =>
            '${_paymentLabel(strings, payment.method)}: '
            '${_money(payment.amountMinor)}',
      ),
      if (_unpaidMinor > 0) '${strings.unpaidDebt}: ${_money(_unpaidMinor)}',
    ].join('\n');
    try {
      await SharePlus.instance.share(
        ShareParams(text: receipt, subject: '${strings.saleNumber} ${sale.id}'),
      );
    } catch (error) {
      debugPrint('Failed to share sale receipt: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _printReceipt(AppLocalizations strings, Sale sale) async {
    try {
      setState(() => _printingReceipt = true);
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _receiptKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('The sale receipt is not ready to print.');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('Could not render the sale receipt for printing.');
        }
        final receiptImage = pw.MemoryImage(bytes.buffer.asUint8List());
        final pageFormat = PdfPageFormat.a4;
        final document = pw.Document();
        document.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(24),
            build: (_) => pw.Center(
              child: pw.Image(
                receiptImage,
                width: pageFormat.width - 48,
                height: pageFormat.height - 48,
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        );
        await Printing.layoutPdf(
          name: 'sale-${sale.id}.pdf',
          onLayout: (_) async => document.save(),
        );
      } finally {
        image.dispose();
      }
    } catch (error) {
      debugPrint('Failed to print sale receipt: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _printingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final sale = _sale;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.saleDetails),
        actions: [
          if (sale != null)
            IconButton(
              tooltip: strings.printReceipt,
              onPressed: () => _printReceipt(strings, sale),
              icon: const Icon(Icons.print_outlined),
            ),
          if (sale != null)
            IconButton(
              tooltip: strings.shareReceipt,
              onPressed: () => _shareReceipt(strings, sale),
              icon: const Icon(Icons.share_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : sale == null
          ? Center(child: Text(strings.saleNotFound))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RepaintBoundary(
                  key: _receiptKey,
                  child: Card(
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
                          _detailRow(
                            strings.subtotal,
                            _money(sale.subtotalMinor),
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            strings.discount,
                            '-${_money(sale.totalDiscountMinor)}',
                          ),
                          const SizedBox(height: 8),
                          _detailRow(strings.total, _money(sale.totalMinor)),
                          const SizedBox(height: 8),
                          if (!_printingReceipt)
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
