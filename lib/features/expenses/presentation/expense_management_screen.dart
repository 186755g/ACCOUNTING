import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  List<Expense> _expenses = [];
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
      final expenses = await widget.database.expenses.getAll(
        orderBy: 'date_at',
        descending: true,
        limit: 500,
      );
      final settings = await widget.database.settings.get();
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load expenses: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addExpense() async {
    final strings = AppLocalizations.of(context);
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var method = PaymentMethod.cash;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.addExpenseTitle),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('expense-category'),
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: strings.expenseCategory,
                    ),
                    validator: _requiredValidator(strings),
                  ),
                  TextFormField(
                    key: const ValueKey('expense-description'),
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: strings.description),
                    validator: _requiredValidator(strings),
                  ),
                  TextFormField(
                    key: const ValueKey('expense-amount'),
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: strings.amount,
                      prefixText: '$_currencyCode ',
                    ),
                    validator: (value) => _amountMinor(value) == null
                        ? strings.invalidNumber
                        : null,
                  ),
                  DropdownButtonFormField<PaymentMethod>(
                    key: const ValueKey('expense-payment-method'),
                    initialValue: method,
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
                      if (value != null) {
                        setDialogState(() => method = value);
                      }
                    },
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
              key: const ValueKey('save-expense'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now().toUtc();
                final expense = Expense(
                  category: categoryController.text.trim(),
                  description: descriptionController.text.trim(),
                  amountMinor: _amountMinor(amountController.text)!,
                  date: now,
                );
                try {
                  await widget.database.transaction((transaction) async {
                    await transaction.insert('expenses', expense.toMap());
                    await transaction.insert(
                      'payments',
                      Payment(
                        expenseId: expense.id,
                        amountMinor: expense.amountMinor,
                        method: method,
                        date: now,
                      ).toMap(),
                    );
                  });
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  debugPrint('Failed to record expense: ${error.runtimeType}');
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
    categoryController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.expenseSaved)));
    }
  }

  String? Function(String?) _requiredValidator(AppLocalizations strings) =>
      (value) =>
          value == null || value.trim().isEmpty ? strings.requiredField : null;

  int? _amountMinor(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 90000000000000) {
      return null;
    }
    final minor = (amount * 100).round();
    return minor > 0 ? minor : null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.expenses)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-expense'),
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: Text(strings.addExpense),
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
          : _expenses.isEmpty
          ? Center(child: Text(strings.noExpenses))
          : ListView.builder(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 88),
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(expense.description),
                    subtitle: Text(
                      '${expense.category} · '
                      '${expense.date.toLocal().toString().split('.').first}',
                    ),
                    trailing: Text(
                      '$_currencyCode '
                      '${(expense.amountMinor / 100).toStringAsFixed(2)}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
