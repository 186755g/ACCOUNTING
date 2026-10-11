import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/database/models/model_utils.dart' show newModelId;
import '../../../core/localization/app_localizations.dart';

class PartyManagementScreen extends StatefulWidget {
  const PartyManagementScreen({
    required this.database,
    required this.isSupplier,
    super.key,
  });

  final LocalDatabase database;
  final bool isSupplier;

  @override
  State<PartyManagementScreen> createState() => _PartyManagementScreenState();
}

class _PartyManagementScreenState extends State<PartyManagementScreen> {
  List<Object> _parties = [];
  final Map<String, PartyAccountSummary> _summaries = {};
  String _currencyCode = 'EGP';
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    try {
      final parties = widget.isSupplier
          ? await widget.database.suppliers.getAll(orderBy: 'name')
          : await widget.database.customers.getAll(orderBy: 'name');
      final summaries = <String, PartyAccountSummary>{};
      for (final party in parties) {
        summaries[party.id] = widget.isSupplier
            ? await widget.database.partyAccounts.getSupplierSummary(party.id)
            : await widget.database.partyAccounts.getCustomerSummary(party.id);
      }
      final settings = await widget.database.settings.get();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _parties = parties;
        _summaries
          ..clear()
          ..addAll(summaries);
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load party accounts: ${error.runtimeType}');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _editParty([Object? existing]) async {
    final strings = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: existing is Customer
          ? existing.name
          : existing is Supplier
          ? existing.name
          : '',
    );
    final phoneController = TextEditingController(
      text: existing is Customer
          ? existing.phone ?? ''
          : existing is Supplier
          ? existing.phone ?? ''
          : '',
    );
    final addressController = TextEditingController(
      text: existing is Customer
          ? existing.address ?? ''
          : existing is Supplier
          ? existing.address ?? ''
          : '',
    );
    final notesController = TextEditingController(
      text: existing is Customer
          ? existing.notes ?? ''
          : existing is Supplier
          ? existing.notes ?? ''
          : '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null
              ? widget.isSupplier
                    ? strings.addSupplier
                    : strings.addCustomer
              : widget.isSupplier
              ? strings.editSupplier
              : strings.editCustomer,
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: strings.name),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? strings.requiredField
                      : null,
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: strings.phone),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: strings.address),
                ),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: strings.notes),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final now = DateTime.now().toUtc();
              final name = nameController.text.trim();
              final phone = _nullable(phoneController.text);
              final address = _nullable(addressController.text);
              final notes = _nullable(notesController.text);
              if (widget.isSupplier) {
                final before = existing is Supplier ? existing : null;
                final supplier = Supplier(
                  id: before?.id,
                  name: name,
                  phone: phone,
                  address: address,
                  notes: notes,
                  createdAt: before?.createdAt ?? now,
                  updatedAt: now,
                );
                if (before == null) {
                  await widget.database.suppliers.create(supplier);
                } else {
                  await widget.database.suppliers.update(supplier);
                }
              } else {
                final before = existing is Customer ? existing : null;
                final customer = Customer(
                  id: before?.id,
                  name: name,
                  phone: phone,
                  address: address,
                  notes: notes,
                  createdAt: before?.createdAt ?? now,
                  updatedAt: now,
                );
                if (before == null) {
                  await widget.database.customers.create(customer);
                } else {
                  await widget.database.customers.update(customer);
                }
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    if (result == true) await _load();
  }

  Future<void> _showDetails(Object party) async {
    final customer = party is Customer ? party : null;
    final supplier = party is Supplier ? party : null;
    final partyId = customer?.id ?? supplier!.id;
    final strings = AppLocalizations.of(context);
    try {
      final debts = await widget.database.debts.getAll(
        filters: {widget.isSupplier ? 'supplier_id' : 'customer_id': partyId},
        orderBy: 'created_at',
        descending: true,
      );
      final documents = widget.isSupplier
          ? await widget.database.purchases.getAll(
              filters: {'supplier_id': partyId},
              limit: 50,
            )
          : await widget.database.sales.getAll(
              filters: {'customer_id': partyId},
              limit: 50,
            );
      final paymentRows = <(Payment, String)>[];
      for (final document in documents) {
        final documentId = document.id;
        final payments = await widget.database.payments.getAll(
          filters: {widget.isSupplier ? 'purchase_id' : 'sale_id': documentId},
          orderBy: 'date_at',
          descending: true,
        );
        for (final payment in payments) {
          paymentRows.add((payment, strings.transactionPayment));
        }
      }
      final debtOutstanding = <String, int>{};
      for (final debt in debts) {
        debtOutstanding[debt.id] = await widget.database.partyAccounts
            .getOutstandingForDebt(debt.id);
        final payments = await widget.database.payments.getAll(
          filters: {'debt_id': debt.id},
          orderBy: 'date_at',
          descending: true,
        );
        for (final payment in payments) {
          paymentRows.add((payment, strings.recordedDebtPayment));
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(customer?.name ?? supplier!.name),
          content: SizedBox(
            width: 440,
            child: ListView(
              shrinkWrap: true,
              children: [
                if ((customer?.phone ?? supplier?.phone)?.isNotEmpty ?? false)
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(customer?.phone ?? supplier!.phone!),
                  ),
                if ((customer?.address ?? supplier?.address)?.isNotEmpty ??
                    false)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(customer?.address ?? supplier!.address!),
                  ),
                const Divider(),
                Text(
                  strings.transactionHistory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (documents.isEmpty && debts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(strings.noTransactionHistory),
                  ),
                for (final document in documents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.isSupplier
                          ? '${strings.purchaseTitle} ${document.id.substring(0, 8)}'
                          : '${strings.saleNumber} ${document.id.substring(0, 8)}',
                    ),
                    subtitle: Text(
                      (document is Sale
                              ? document.date
                              : (document as Purchase).date)
                          .toLocal()
                          .toString()
                          .split('.')
                          .first,
                    ),
                    trailing: Text(
                      _money(
                        document is Sale
                            ? document.totalMinor
                            : (document as Purchase).totalMinor,
                      ),
                    ),
                  ),
                for (final debt in debts) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${strings.debtHistory} · ${debt.description ?? strings.manualDebt}',
                    ),
                    subtitle: Text(
                      '${strings.outstandingBalance}: '
                      '${_money(debtOutstanding[debt.id]!)}',
                    ),
                    trailing: Text(_money(debt.amountMinor)),
                  ),
                  ...paymentRows
                      .where((entry) => entry.$1.debtId == debt.id)
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.$2),
                          subtitle: Text(
                            entry.$1.date.toLocal().toString().split('.').first,
                          ),
                          trailing: Text('-${_money(entry.$1.amountMinor)}'),
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: [
            if (!widget.isSupplier)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _addDebt(partyId);
                },
                icon: const Icon(Icons.add),
                label: Text(strings.addDebt),
              ),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _recordPayment(partyId);
              },
              icon: const Icon(Icons.payments_outlined),
              label: Text(strings.recordPayment),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.close),
            ),
          ],
        ),
      );
    } catch (error) {
      debugPrint(
        'Failed to load party transaction history: ${error.runtimeType}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _addDebt(String partyId) async {
    final strings = AppLocalizations.of(context);
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.addDebt),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.debtAmount,
                  prefixText: '$_currencyCode ',
                ),
                validator: (value) =>
                    _amountMinor(value) == null ? strings.invalidNumber : null,
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: strings.description),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = _amountMinor(amountController.text)!;
              if (widget.isSupplier) {
                await widget.database.partyAccounts.addSupplierDebt(
                  supplierId: partyId,
                  amountMinor: amount,
                  description: _nullable(descriptionController.text),
                );
              } else {
                await widget.database.partyAccounts.addCustomerDebt(
                  customerId: partyId,
                  amountMinor: amount,
                  description: _nullable(descriptionController.text),
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
    amountController.dispose();
    descriptionController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _recordPayment(String partyId) async {
    final strings = AppLocalizations.of(context);
    final debts = await widget.database.debts.getAll(
      filters: {widget.isSupplier ? 'supplier_id' : 'customer_id': partyId},
      orderBy: 'created_at',
      descending: true,
    );
    final outstanding = <Debt>[];
    for (final debt in debts) {
      if (await widget.database.partyAccounts.getOutstandingForDebt(debt.id) >
          0) {
        outstanding.add(debt);
      }
    }
    if (!mounted) return;
    if (outstanding.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.noOutstandingDebt)));
      return;
    }
    final amountController = TextEditingController();
    String selectedDebtId = outstanding.first.id;
    PaymentMethod method = PaymentMethod.cash;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.recordPayment),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedDebtId,
                decoration: InputDecoration(labelText: strings.debtHistory),
                items: outstanding
                    .map(
                      (debt) => DropdownMenuItem(
                        value: debt.id,
                        child: Text(
                          '${debt.description ?? strings.manualDebt} · '
                          '${_money(debt.amountMinor)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedDebtId = value);
                  }
                },
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: strings.paymentAmount,
                  prefixText: '$_currencyCode ',
                ),
              ),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                decoration: InputDecoration(labelText: strings.paymentMethod),
                items: [
                  DropdownMenuItem(
                    value: PaymentMethod.cash,
                    child: Text(strings.cash),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.card,
                    child: Text(strings.card),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.mobileWallet,
                    child: Text(strings.wallet),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => method = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final amount = _amountMinor(amountController.text);
                if (amount == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(strings.invalidNumber)),
                  );
                  return;
                }
                try {
                  await widget.database.partyAccounts.recordPayment(
                    debtId: selectedDebtId,
                    amountMinor: amount,
                    method: method,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  debugPrint(
                    'Failed to record party debt payment: ${error.runtimeType}',
                  );
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    if (saved == true) await _load();
  }

  int? _amountMinor(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    return (amount * 100).round();
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _money(int minor) =>
      '$_currencyCode ${(minor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final title = widget.isSupplier
        ? strings.supplierManagement
        : strings.customerManagement;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.isSupplier)
            IconButton(
              tooltip: strings.purchaseTitle,
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PurchaseManagementScreen(database: widget.database),
                  ),
                );
                await _load();
              },
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editParty,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          widget.isSupplier ? strings.addSupplier : strings.addCustomer,
        ),
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
          : _parties.isEmpty
          ? Center(
              child: Text(
                widget.isSupplier ? strings.noSuppliers : strings.noCustomers,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _parties.length,
                itemBuilder: (context, index) {
                  final party = _parties[index];
                  final id = party is Customer
                      ? party.id
                      : (party as Supplier).id;
                  final name = party is Customer
                      ? party.name
                      : (party as Supplier).name;
                  final phone = party is Customer
                      ? party.phone
                      : (party as Supplier).phone;
                  final summary = _summaries[id];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          widget.isSupplier
                              ? Icons.local_shipping_outlined
                              : Icons.person_outline,
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        '${phone ?? ''}\n'
                        '${strings.totalPurchases}: '
                        '${_money(summary?.documentTotalMinor ?? 0)} · '
                        '${strings.outstandingBalance}: '
                        '${_money(summary?.outstandingMinor ?? 0)}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: strings.edit,
                        onPressed: () => _editParty(party),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () => _showDetails(party),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class PurchaseManagementScreen extends StatefulWidget {
  const PurchaseManagementScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<PurchaseManagementScreen> createState() =>
      _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends State<PurchaseManagementScreen> {
  final _searchController = TextEditingController();
  List<Purchase> _purchases = [];
  List<Supplier> _suppliers = [];
  Map<String, String> _supplierNames = {};
  Map<String, int> _paidByPurchase = {};
  String _currencyCode = 'EGP';
  String? _supplierId;
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
      final purchases = await widget.database.purchases.getAll(
        filters: _supplierId == null ? const {} : {'supplier_id': _supplierId},
        fromDate: _from,
        toDate: _to,
        limit: 500,
      );
      final suppliers = await widget.database.suppliers.getAll(orderBy: 'name');
      final settings = await widget.database.settings.get();
      final paidRows = await widget.database.transaction((transaction) {
        return transaction.rawQuery('''
          WITH purchase_payments AS (
            SELECT purchase_id, amount_minor
            FROM payments WHERE purchase_id IS NOT NULL
            UNION ALL
            SELECT d.purchase_id, p.amount_minor
            FROM payments p JOIN debts d ON d.id = p.debt_id
            WHERE d.purchase_id IS NOT NULL
          )
          SELECT purchase_id, SUM(amount_minor) AS paid
          FROM purchase_payments GROUP BY purchase_id
        ''');
      });
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _purchases = purchases;
        _suppliers = suppliers;
        _supplierNames = {
          for (final supplier in suppliers) supplier.id: supplier.name,
        };
        _paidByPurchase = {
          for (final row in paidRows)
            row['purchase_id'] as String: (row['paid'] as num).round(),
        };
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load purchases: ${error.runtimeType}');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _createPurchase() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseEntryScreen(database: widget.database),
      ),
    );
    await _load();
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

  List<Purchase> get _visiblePurchases {
    final query = _searchController.text.trim().toLowerCase();
    return _purchases
        .where((purchase) {
          final searchable = [
            purchase.id,
            purchase.notes ?? '',
            _supplierNames[purchase.supplierId] ?? '',
            ...purchase.items.map((item) => item.productName),
          ].join(' ').toLowerCase();
          if (query.isNotEmpty && !searchable.contains(query)) return false;
          final paid = _paidByPurchase[purchase.id] ?? 0;
          final status = purchase.totalMinor <= 0 || paid >= purchase.totalMinor
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
    final visiblePurchases = _visiblePurchases;
    return Scaffold(
      appBar: AppBar(title: Text(strings.purchaseTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPurchase,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(strings.newPurchase),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
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
                            value: _supplierId,
                            hint: Text(strings.supplier),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(strings.allRecords),
                              ),
                              for (final supplier in _suppliers)
                                DropdownMenuItem<String?>(
                                  value: supplier.id,
                                  child: Text(supplier.name),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _supplierId = value);
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
                  child: visiblePurchases.isEmpty
                      ? Center(
                          child: Text(
                            _purchases.isEmpty
                                ? strings.noPurchases
                                : strings.noSearchResults,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: visiblePurchases.length,
                            itemBuilder: (context, index) {
                              final purchase = visiblePurchases[index];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.shopping_bag_outlined),
                                  ),
                                  title: Text(
                                    '${strings.purchaseTitle} ${purchase.id.substring(0, 8)}',
                                  ),
                                  subtitle: Text(
                                    '${purchase.date.toLocal().toString().split('.').first}'
                                    ' · ${purchase.items.length} ${strings.saleItems}',
                                  ),
                                  trailing: Text(_money(purchase.totalMinor)),
                                  onTap: () => _showPurchase(purchase),
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

  Future<void> _showPurchase(Purchase purchase) async {
    final strings = AppLocalizations.of(context);
    final payments = await widget.database.payments.getAll(
      filters: {'purchase_id': purchase.id},
    );
    final debts = await widget.database.debts.getAll(
      filters: {'purchase_id': purchase.id},
    );
    var paidMinor = payments.fold(
      0,
      (sum, payment) => sum + payment.amountMinor,
    );
    var unpaidMinor = 0;
    for (final debt in debts) {
      paidMinor += (await widget.database.payments.getAll(
        filters: {'debt_id': debt.id},
      )).fold(0, (sum, payment) => sum + payment.amountMinor);
      unpaidMinor += await widget.database.partyAccounts.getOutstandingForDebt(
        debt.id,
      );
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.purchaseTitle),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in purchase.items)
                ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    '${strings.quantity}: ${item.quantity} · '
                    '${_money(item.costPriceMinor)}',
                  ),
                  trailing: Text(_money(item.totalMinor)),
                ),
              const Divider(),
              ListTile(
                title: Text(strings.total),
                trailing: Text(_money(purchase.totalMinor)),
              ),
              ListTile(
                title: Text(strings.totalPaid),
                trailing: Text(_money(paidMinor)),
              ),
              ListTile(
                title: Text(strings.unpaidAmount),
                trailing: Text(_money(unpaidMinor)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }
}

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  List<Product> _products = [];
  List<Supplier> _suppliers = [];
  final Map<String, double> _quantities = {};
  final Map<String, TextEditingController> _costControllers = {};
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController();
  String? _supplierId;
  String _currencyCode = 'EGP';
  PaymentMethod _method = PaymentMethod.cash;
  bool _paidManuallySet = false;
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
    for (final controller in _costControllers.values) {
      controller.dispose();
    }
    _discountController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await widget.database.products.browse(activeOnly: true);
      final suppliers = await widget.database.suppliers.getAll(orderBy: 'name');
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _products = products;
        _suppliers = suppliers;
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load purchase entry data: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int get _subtotalMinor => _quantities.entries.fold(0, (sum, entry) {
    final cost = double.tryParse(_costControllers[entry.key]!.text) ?? 0;
    return sum + (entry.value * cost * 100).round();
  });

  int? _minorFromController(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    if (value == null || !value.isFinite || value < 0) return null;
    return (value * 100).round();
  }

  int get _discountMinor => _minorFromController(_discountController) ?? 0;
  int get _totalMinor => _subtotalMinor - _discountMinor;

  void _syncDefaultPayment() {
    if (!_paidManuallySet) {
      _paidController.text = (_totalMinor / 100).toStringAsFixed(2);
    }
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    if (_quantities.isEmpty) {
      _showError(strings.cartEmpty);
      return;
    }
    final discount = _minorFromController(_discountController);
    final paid = _minorFromController(_paidController);
    if (discount == null || paid == null || discount > _subtotalMinor) {
      _showError(strings.invalidNumber);
      return;
    }
    final total = _subtotalMinor - discount;
    if (paid > total) {
      _showError(strings.paymentExceedsTotal);
      return;
    }
    if (paid < total && _supplierId == null) {
      _showError(strings.supplierRequiredForDebt);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final purchaseId = newModelId();
      final items = <PurchaseItem>[];
      for (final entry in _quantities.entries) {
        final product = await widget.database.products.getById(entry.key);
        if (product == null || !product.isActive) {
          throw StateError(strings.productUnavailable);
        }
        final costMinor =
            (_costControllers[product.id]!.text.trim().isEmpty
                ? product.costPriceMinor / 100
                : double.parse(_costControllers[product.id]!.text.trim())) *
            100;
        items.add(
          PurchaseItem(
            purchaseId: purchaseId,
            productId: product.id,
            productName: product.name,
            quantity: entry.value,
            costPriceMinor: costMinor.round(),
          ),
        );
      }
      final purchase = Purchase(
        id: purchaseId,
        supplierId: _supplierId,
        items: items,
        orderDiscountMinor: discount,
      );
      final tenders = paid == 0
          ? const <SaleTender>[]
          : [SaleTender(method: _method, amountMinor: paid)];
      await widget.database.purchases.checkout(purchase, tenders: tenders);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      debugPrint('Failed to record purchase: ${error.runtimeType}');
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(int minor) =>
      '$_currencyCode ${(minor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.newPurchase)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _products.isEmpty
          ? Center(child: Text(_error!))
          : Column(
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  decoration: InputDecoration(labelText: strings.supplier),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.walkInSupplier),
                    ),
                    ..._suppliers.map(
                      (supplier) => DropdownMenuItem<String?>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _supplierId = value),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final product in _products)
                        ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                            '${strings.stockQuantity}: ${product.stockQuantity}',
                          ),
                          leading: IconButton(
                            onPressed: () => setState(() {
                              final quantity =
                                  (_quantities[product.id] ?? 0) - 1;
                              if (quantity <= 0) {
                                _quantities.remove(product.id);
                              } else {
                                _quantities[product.id] = quantity;
                              }
                              _syncDefaultPayment();
                            }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${_quantities[product.id] ?? 0}'),
                              IconButton(
                                onPressed: () => setState(() {
                                  _quantities.update(
                                    product.id,
                                    (value) => value + 1,
                                    ifAbsent: () => 1,
                                  );
                                  _syncDefaultPayment();
                                  _costControllers.putIfAbsent(
                                    product.id,
                                    () => TextEditingController(
                                      text: (product.costPriceMinor / 100)
                                          .toStringAsFixed(2),
                                    ),
                                  );
                                }),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              SizedBox(
                                width: 88,
                                child: TextField(
                                  controller: _costControllers.putIfAbsent(
                                    product.id,
                                    () => TextEditingController(
                                      text: (product.costPriceMinor / 100)
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) =>
                                      setState(_syncDefaultPayment),
                                  decoration: InputDecoration(
                                    labelText: strings.purchasePrice,
                                    prefixText: '$_currencyCode ',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {
                          _syncDefaultPayment();
                        }),
                        decoration: InputDecoration(
                          labelText: strings.discount,
                          prefixText: '$_currencyCode ',
                        ),
                      ),
                      TextField(
                        controller: _paidController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {
                          _paidManuallySet = true;
                        }),
                        decoration: InputDecoration(
                          labelText: strings.paymentAmount,
                          prefixText: '$_currencyCode ',
                          helperText:
                              '${strings.unpaidAmount}: ${_money(_totalMinor - (_minorFromController(_paidController) ?? 0))}',
                        ),
                      ),
                      DropdownButtonFormField<PaymentMethod>(
                        initialValue: _method,
                        decoration: InputDecoration(
                          labelText: strings.paymentMethod,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: PaymentMethod.cash,
                            child: Text(strings.cash),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.card,
                            child: Text(strings.card),
                          ),
                          DropdownMenuItem(
                            value: PaymentMethod.mobileWallet,
                            child: Text(strings.wallet),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _method = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${strings.total}: ${_money(_totalMinor)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.check),
                            label: Text(strings.recordPurchase),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
