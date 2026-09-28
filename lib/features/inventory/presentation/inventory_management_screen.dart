import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  List<Product> _lowStock = [];
  List<Product> _outOfStock = [];
  List<Product> _products = [];
  List<InventoryMovement> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lowStockRows = await widget.database.inventory
          .getLowStockProducts();
      final outOfStockRows = await widget.database.inventory
          .getOutOfStockProducts();
      final products = await widget.database.products.getAll(orderBy: 'name');
      final history = await widget.database.inventory.getHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _lowStock = lowStockRows.map(Product.fromMap).toList(growable: false);
        _outOfStock = outOfStockRows
            .map(Product.fromMap)
            .toList(growable: false);
        _products = products;
        _history = history;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load inventory: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _adjustStock() async {
    if (_products.isEmpty) return;
    final strings = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    var selectedProductId = _products.first.id;
    final adjustment = await showDialog<_StockAdjustment>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.adjustStock),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    decoration: InputDecoration(labelText: strings.productName),
                    items: _products
                        .map(
                          (product) => DropdownMenuItem(
                            value: product.id,
                            child: Text(product.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedProductId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: strings.adjustmentQuantity,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      final quantity = double.tryParse(value?.trim() ?? '');
                      return quantity == null ||
                              !quantity.isFinite ||
                              quantity == 0
                          ? strings.invalidNumber
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: strings.adjustmentReason,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: InputDecoration(labelText: strings.note),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _StockAdjustment(
                    productId: selectedProductId,
                    quantity: double.parse(quantityController.text.trim()),
                    reason: reasonController.text.trim(),
                    note: noteController.text.trim(),
                  ),
                );
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
    quantityController.dispose();
    reasonController.dispose();
    noteController.dispose();
    if (adjustment == null) return;
    try {
      await widget.database.inventory.adjustStock(
        productId: adjustment.productId,
        quantity: adjustment.quantity,
        reason: adjustment.reason,
        note: adjustment.note,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.stockAdjusted)));
    } catch (error) {
      debugPrint('Failed to adjust stock: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.inventoryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('adjust-inventory-stock'),
        onPressed: _products.isEmpty ? null : _adjustStock,
        icon: const Icon(Icons.tune),
        label: Text(strings.adjustStock),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _section(
                    context,
                    title: strings.outOfStockAlerts,
                    icon: Icons.error_outline,
                    products: _outOfStock,
                    emptyText: strings.noInventoryAlerts,
                  ),
                  const SizedBox(height: 16),
                  _section(
                    context,
                    title: strings.lowStockAlerts,
                    icon: Icons.warning_amber_rounded,
                    products: _lowStock,
                    emptyText: strings.noInventoryAlerts,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    strings.inventoryHistory,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text(strings.noInventoryHistory)),
                    )
                  else
                    ..._history.map(
                      (movement) => Card(
                        child: ListTile(
                          leading: Icon(
                            movement.quantity > 0
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                          ),
                          title: Text(movement.productName),
                          subtitle: Text(
                            '${_reasonLabel(strings, movement.reason)}'
                            ' · ${strings.previousQuantity}: '
                            '${_quantity(movement.previousQuantity)}'
                            ' → ${strings.newQuantity}: '
                            '${_quantity(movement.newQuantity)}'
                            '${movement.note == null ? '' : '\n${movement.note}'}'
                            '\n${movement.date.toLocal().toString().split('.').first}',
                          ),
                          trailing: Text(
                            '${movement.quantity > 0 ? '+' : ''}'
                            '${_quantity(movement.quantity)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Product> products,
    required String emptyText,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (products.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(emptyText),
          ),
        )
      else
        ...products.map(
          (product) => Card(
            child: ListTile(
              leading: Icon(icon, color: Theme.of(context).colorScheme.error),
              title: Text(product.name),
              subtitle: Text(
                '${AppLocalizations.of(context).stockQuantity}: '
                '${_quantity(product.stockQuantity)} ${product.unit}'
                '${product.stockQuantity > 0 ? ' · ${AppLocalizations.of(context).minimumStock}: ${_quantity(product.minimumStock)}' : ''}',
              ),
            ),
          ),
        ),
    ],
  );

  String _reasonLabel(AppLocalizations strings, String reason) =>
      switch (reason) {
        'opening_stock' => strings.openingStock,
        'sale' => strings.saleReason,
        'purchase' => strings.purchaseReason,
        'sale_return' => strings.returnProduct,
        'sale_reversal' => strings.saleReversal,
        'purchase_reversal' => strings.purchaseReversal,
        'sale_adjustment' => strings.saleAdjustment,
        'purchase_adjustment' => strings.purchaseAdjustment,
        'manual_adjustment' => strings.manualAdjustment,
        _ => reason,
      };

  String _quantity(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

class _StockAdjustment {
  const _StockAdjustment({
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.note,
  });

  final String productId;
  final double quantity;
  final String reason;
  final String note;
}
