import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/database/models/model_utils.dart' show newModelId;
import '../../../core/localization/app_localizations.dart';
import 'sale_detail_screen.dart';

class SalePosScreen extends StatefulWidget {
  const SalePosScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<SalePosScreen> createState() => _SalePosScreenState();
}

class _SalePosScreenState extends State<SalePosScreen> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  List<Product> _products = [];
  List<Customer> _customers = [];
  final Map<String, double> _cart = {};
  String? _customerId;
  String _query = '';
  String _currencyCode = 'EGP';
  _TenderChoice _tenderChoice = _TenderChoice.cash;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await widget.database.products.browse(
        query: _query,
        activeOnly: true,
      );
      final customers = await widget.database.customers.getAll(orderBy: 'name');
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _products = products;
        _customers = customers;
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load point-of-sale data: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int get _subtotalMinor {
    var total = 0;
    for (final entry in _cart.entries) {
      final product = _product(entry.key);
      if (product != null) {
        total += (entry.value * product.sellingPriceMinor).round();
      }
    }
    return total;
  }

  int? get _parsedDiscountMinor {
    final amount = double.tryParse(_discountController.text.trim());
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return (amount * 100).round();
  }

  int get _discountMinor => _parsedDiscountMinor ?? 0;
  int get _totalMinor => _subtotalMinor - _discountMinor;

  Product? _product(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _addProduct(Product product) {
    setState(() {
      _cart.update(product.id, (quantity) => quantity + 1, ifAbsent: () => 1);
    });
  }

  void _changeQuantity(String productId, double amount) {
    setState(() {
      final quantity = (_cart[productId] ?? 0) + amount;
      if (quantity <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = quantity;
      }
    });
  }

  Future<void> _completeSale() async {
    final strings = AppLocalizations.of(context);
    if (_saving) return;
    if (_cart.isEmpty) {
      _showError(strings.cartEmpty);
      return;
    }
    if (_parsedDiscountMinor == null) {
      _showError(strings.invalidNumber);
      return;
    }
    if (_discountMinor > _subtotalMinor) {
      _showError(strings.discountExceedsSubtotal);
      return;
    }
    if (_tenderChoice == _TenderChoice.unpaid && _customerId == null) {
      _showError(strings.customerRequiredForDebt);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saleId = newModelId();
      final items = <SaleItem>[];
      for (final entry in _cart.entries) {
        final product = await widget.database.products.getById(entry.key);
        if (product == null || !product.isActive) {
          throw StateError(strings.productUnavailable);
        }
        items.add(
          SaleItem(
            saleId: saleId,
            productId: product.id,
            productName: product.name,
            quantity: entry.value,
            sellingPriceMinor: product.sellingPriceMinor,
            costPriceMinor: product.costPriceMinor,
          ),
        );
      }
      final sale = Sale(
        id: saleId,
        customerId: _customerId,
        items: items,
        orderDiscountMinor: _discountMinor,
      );
      final tenders = sale.totalMinor == 0
          ? const <SaleTender>[]
          : switch (_tenderChoice) {
              _TenderChoice.cash => [
                SaleTender(
                  method: PaymentMethod.cash,
                  amountMinor: sale.totalMinor,
                ),
              ],
              _TenderChoice.card => [
                SaleTender(
                  method: PaymentMethod.card,
                  amountMinor: sale.totalMinor,
                ),
              ],
              _TenderChoice.wallet => [
                SaleTender(
                  method: PaymentMethod.mobileWallet,
                  amountMinor: sale.totalMinor,
                ),
              ],
              _TenderChoice.unpaid => const <SaleTender>[],
            };
      await widget.database.sales.checkout(sale, tenders: tenders);
      if (!mounted) return;
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                SaleDetailScreen(database: widget.database, saleId: sale.id),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Failed to record point-of-sale transaction: $error');
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.newSale)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _products.isEmpty
          ? Center(child: Text(_error!))
          : LayoutBuilder(
              builder: (context, constraints) {
                final cart = _buildCart(context, strings);
                final catalog = _buildCatalog(context, strings);
                if (constraints.maxWidth >= 700) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: catalog),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: cart),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 2, child: catalog),
                    const Divider(height: 1),
                    Expanded(flex: 3, child: cart),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCatalog(
    BuildContext context,
    AppLocalizations strings,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          key: const ValueKey('pos-product-search'),
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _query = value;
              _loading = true;
            });
            _load();
          },
          decoration: InputDecoration(
            hintText: strings.searchProducts,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: _products.isEmpty
            ? Center(child: Text(strings.noProducts))
            : ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return ListTile(
                    key: ValueKey('pos-product-${product.id}'),
                    title: Text(product.name),
                    subtitle: Text(
                      '${strings.stockQuantity}: ${product.stockQuantity} ${product.unit}'
                      ' · ${_money(product.sellingPriceMinor, _currencyCode)}',
                    ),
                    trailing: IconButton(
                      tooltip: strings.addToCart,
                      onPressed: () => _addProduct(product),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    onTap: () => _addProduct(product),
                  );
                },
              ),
      ),
    ],
  );

  Widget _buildCart(BuildContext context, AppLocalizations strings) {
    final cartRows = <Widget>[];
    for (final entry in _cart.entries) {
      final product = _product(entry.key);
      if (product == null) continue;
      cartRows.add(
        ListTile(
          key: ValueKey('cart-${product.id}'),
          title: Text(product.name),
          subtitle: Text(
            _money(
              (product.sellingPriceMinor * entry.value).round(),
              _currencyCode,
            ),
          ),
          leading: IconButton(
            tooltip: strings.decreaseQuantity,
            onPressed: () => _changeQuantity(product.id, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_quantity(entry.value)),
              IconButton(
                tooltip: strings.increaseQuantity,
                onPressed: () => _changeQuantity(product.id, 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${strings.cart} (${_cart.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(child: Text(strings.cartEmpty))
              : ListView(children: cartRows),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              DropdownButtonFormField<String?>(
                key: const ValueKey('pos-customer'),
                initialValue: _customerId,
                decoration: InputDecoration(labelText: strings.customer),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(strings.walkInCustomer),
                  ),
                  ..._customers.map(
                    (customer) => DropdownMenuItem<String?>(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _customerId = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('pos-discount'),
                controller: _discountController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.discount,
                  prefixText: '$_currencyCode ',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<_TenderChoice>(
                key: const ValueKey('pos-payment-method'),
                initialValue: _tenderChoice,
                decoration: InputDecoration(labelText: strings.paymentMethod),
                items: [
                  DropdownMenuItem(
                    value: _TenderChoice.cash,
                    child: Text(strings.cash),
                  ),
                  DropdownMenuItem(
                    value: _TenderChoice.card,
                    child: Text(strings.card),
                  ),
                  DropdownMenuItem(
                    value: _TenderChoice.wallet,
                    child: Text(strings.wallet),
                  ),
                  DropdownMenuItem(
                    value: _TenderChoice.unpaid,
                    child: Text(strings.unpaidDebt),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _tenderChoice = value);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${strings.total}: ${_money(_totalMinor, _currencyCode)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('complete-sale'),
                    onPressed: _saving || _cart.isEmpty ? null : _completeSale,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(strings.recordSale),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _quantity(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : '$quantity';

  String _money(int minor, String currency) =>
      '$currency ${(minor / 100).toStringAsFixed(2)}';
}

enum _TenderChoice { cash, card, wallet, unpaid }
