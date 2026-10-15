import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen> {
  bool _loading = true;
  String? _error;
  List<FinancialAccount> _accounts = const [];
  final Map<String, int> _balances = {};
  String? _selectedReconciliationAccountId;
  DateTime _reconciliationDate = DateTime.now();
  final TextEditingController _actualBalanceController =
      TextEditingController();
  String _currencyCode = 'EGP';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _actualBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final settings = await widget.database.settings.get();
      final accounts = await widget.database.financialAccounts.getAll(
        orderBy: 'name',
      );
      final balances = <String, int>{};
      for (final account in accounts) {
        try {
          balances[account.id] = await widget.database.financialAccounts
              .getBalance(account.id);
        } catch (_) {
          balances[account.id] = account.openingBalanceMinor;
        }
      }
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _balances
          ..clear()
          ..addAll(balances);
        _currencyCode = settings?.currencyCode ?? 'EGP';
        _selectedReconciliationAccountId ??= accounts.isNotEmpty
            ? accounts.first.id
            : null;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Failed to load financial accounts: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _formatMoney(int minor) {
    final strings = AppLocalizations.of(context);
    final locale = strings.isArabic ? 'ar_EG' : 'en_US';
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: _currencyCode,
      decimalDigits: 2,
    );
    return formatter.format(minor / 100);
  }

  String _typeLabel(FinancialAccountType type) {
    final strings = AppLocalizations.of(context);
    switch (type) {
      case FinancialAccountType.cash:
        return strings.cash;
      case FinancialAccountType.bank:
        return strings.bank;
      case FinancialAccountType.card:
        return strings.card;
      case FinancialAccountType.mobileWallet:
        return strings.mobileWallet;
      case FinancialAccountType.other:
        return strings.other;
    }
  }

  Future<void> _showAddAccountDialog() async {
    final strings = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final noteController = TextEditingController();
    final openingBalanceController = TextEditingController(text: '0');
    var selectedType = FinancialAccountType.bank;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.addAccount),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: strings.name),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? strings.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FinancialAccountType>(
                    value: selectedType,
                    decoration: InputDecoration(labelText: strings.accountType),
                    items: FinancialAccountType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_typeLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: accountNumberController,
                    decoration: InputDecoration(
                      labelText: strings.accountNumber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: openingBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: strings.openingBalance,
                    ),
                    validator: (value) {
                      final parsed = _parseMinor(value ?? '');
                      if (parsed == null) {
                        return strings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: strings.notes),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final account = FinancialAccount(
                  name: nameController.text.trim(),
                  type: selectedType,
                  accountNumber: accountNumberController.text.trim().isEmpty
                      ? null
                      : accountNumberController.text.trim(),
                  notes: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                  openingBalanceMinor:
                      _parseMinor(openingBalanceController.text) ?? 0,
                );
                try {
                  await widget.database.financialAccounts.create(account);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (error) {
                  debugPrint(
                    'Failed to create financial account: ${error.runtimeType}',
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

    nameController.dispose();
    accountNumberController.dispose();
    noteController.dispose();
    openingBalanceController.dispose();

    if (saved == true) {
      await _loadAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.accountCreated)));
    }
  }

  Future<void> _showMovementDialog(
    FinancialAccount account, {
    required String title,
    required String action,
    required String descriptionLabel,
    required String referenceLabel,
  }) async {
    final strings = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    var movementDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: strings.amount,
                      prefixText: '$_currencyCode ',
                    ),
                    validator: (value) {
                      final parsed = _parseMinor(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return strings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: movementDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => movementDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: strings.date),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMd(strings.isArabic ? 'ar_EG' : 'en_US')
                                .format(movementDate),
                          ),
                          const Icon(Icons.calendar_today_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: descriptionLabel),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: InputDecoration(labelText: referenceLabel),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final amountMinor = _parseMinor(amountController.text) ?? 0;
                  switch (action) {
                    case 'deposit':
                      await widget.database.financialAccounts.recordDeposit(
                        accountId: account.id,
                        amountMinor: amountMinor,
                        date: movementDate,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        reference: referenceController.text.trim().isEmpty
                            ? null
                            : referenceController.text.trim(),
                      );
                      break;
                    case 'withdrawal':
                      await widget.database.financialAccounts.recordWithdrawal(
                        accountId: account.id,
                        amountMinor: amountMinor,
                        date: movementDate,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        reference: referenceController.text.trim().isEmpty
                            ? null
                            : referenceController.text.trim(),
                      );
                      break;
                    case 'commission':
                      await widget.database.financialAccounts.recordCommission(
                        accountId: account.id,
                        amountMinor: amountMinor,
                        date: movementDate,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        reference: referenceController.text.trim().isEmpty
                            ? null
                            : referenceController.text.trim(),
                      );
                      break;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (error) {
                  debugPrint(
                    'Failed to record financial movement: ${error.runtimeType}',
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
    descriptionController.dispose();
    referenceController.dispose();

    if (confirmed == true) {
      await _loadAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.operationSaved)));
    }
  }

  Future<void> _showTransferDialog(FinancialAccount sourceAccount) async {
    final strings = AppLocalizations.of(context);
    final availableTargets = _accounts
        .where((account) => account.id != sourceAccount.id)
        .toList();
    if (availableTargets.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.noTransferTargets)));
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final commissionController = TextEditingController(text: '0');
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    var destinationId = availableTargets.first.id;
    var movementDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.transfer),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: destinationId,
                    decoration: InputDecoration(
                      labelText: strings.destinationAccount,
                    ),
                    items: availableTargets
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => destinationId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: strings.amount,
                      prefixText: '$_currencyCode ',
                    ),
                    validator: (value) {
                      final parsed = _parseMinor(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return strings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commissionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: strings.transferCommission,
                      prefixText: '$_currencyCode ',
                    ),
                    validator: (value) {
                      final parsed = _parseMinor(value ?? '');
                      if (parsed == null || parsed < 0) {
                        return strings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: movementDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => movementDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: strings.date),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMd(strings.isArabic ? 'ar_EG' : 'en_US')
                                .format(movementDate),
                          ),
                          const Icon(Icons.calendar_today_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: strings.description),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceController,
                    decoration: InputDecoration(labelText: strings.reference),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final amountMinor = _parseMinor(amountController.text) ?? 0;
                  final commissionMinor =
                      _parseMinor(commissionController.text) ?? 0;
                  final description = descriptionController.text.trim();
                  final reference = referenceController.text.trim();
                  await widget.database.financialAccounts
                      .transferBetweenAccounts(
                        fromAccountId: sourceAccount.id,
                        toAccountId: destinationId,
                        amountMinor: amountMinor,
                        date: movementDate,
                        description: description.isEmpty ? null : description,
                        reference: reference.isEmpty ? null : reference,
                      );
                  if (commissionMinor > 0) {
                    await widget.database.financialAccounts.recordCommission(
                      accountId: sourceAccount.id,
                      amountMinor: commissionMinor,
                      date: movementDate,
                      description: description.isEmpty
                          ? strings.transferCommission
                          : '${strings.transferCommission} - $description',
                      reference: reference.isEmpty
                          ? 'transfer-commission-${DateTime.now().toUtc().microsecondsSinceEpoch}'
                          : 'transfer-commission-$reference',
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } catch (error) {
                  debugPrint(
                    'Failed to transfer between financial accounts: ${error.runtimeType}',
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
    commissionController.dispose();
    descriptionController.dispose();
    referenceController.dispose();

    if (confirmed == true) {
      await _loadAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.transferSaved)));
    }
  }

  Future<void> _showAccountDetails(FinancialAccount account) async {
    final strings = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${strings.accountType}: ${_typeLabel(account.type)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (account.accountNumber != null &&
                  account.accountNumber!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${strings.accountNumber}: ${account.accountNumber}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${strings.currentBalance}: ${_formatMoney(_balances[account.id] ?? account.openingBalanceMinor)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await _showMovementDialog(
                        account,
                        title: strings.deposit,
                        action: 'deposit',
                        descriptionLabel: strings.description,
                        referenceLabel: strings.reference,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(strings.deposit),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await _showMovementDialog(
                        account,
                        title: strings.withdrawal,
                        action: 'withdrawal',
                        descriptionLabel: strings.description,
                        referenceLabel: strings.reference,
                      );
                    },
                    icon: const Icon(Icons.remove),
                    label: Text(strings.withdrawal),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await _showMovementDialog(
                        account,
                        title: strings.commission,
                        action: 'commission',
                        descriptionLabel: strings.description,
                        referenceLabel: strings.reference,
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(strings.commission),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await _showTransferDialog(account);
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(strings.transfer),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                strings.accountMovements,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<AccountMovement>>(
                  future: widget.database.financialAccounts.getMovements(
                    accountId: account.id,
                    limit: 30,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    }
                    final movements =
                        snapshot.data ?? const <AccountMovement>[];
                    if (movements.isEmpty) {
                      return Center(child: Text(strings.noAccountMovements));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: movements.length,
                      itemBuilder: (context, index) {
                        final movement = movements[index];
                        final signedAmount =
                            movement.direction ==
                                AccountMovementDirection.credit
                            ? movement.amountMinor
                            : -movement.amountMinor;
                        final sign = signedAmount >= 0 ? '+' : '-';
                        final titleText =
                            movement.description ??
                            (movement.direction ==
                                    AccountMovementDirection.credit
                                ? strings.deposit
                                : strings.withdrawal);
                        return ListTile(
                          leading: Icon(
                            movement.direction ==
                                    AccountMovementDirection.credit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color:
                                movement.direction ==
                                    AccountMovementDirection.credit
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(titleText),
                          subtitle: Text(
                            '${DateFormat.yMd(strings.isArabic ? 'ar_EG' : 'en_US').format(movement.date)}\n${movement.reference ?? strings.noReference}',
                          ),
                          trailing: Text(
                            '$sign${_formatMoney(signedAmount.abs())}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: signedAmount >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _parseMinor(String input) {
    final parsed = double.tryParse(input.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return null;
    }
    return (parsed * 100).round();
  }

  Widget _accountsTab() {
    final strings = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh),
              label: Text(strings.retry),
            ),
          ],
        ),
      );
    }
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: 12),
            Text(strings.noFinancialAccounts),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final balance = _balances[account.id] ?? account.openingBalanceMinor;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_typeLabel(account.type)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (account.accountNumber != null &&
                      account.accountNumber!.trim().isNotEmpty)
                    Text('${strings.accountNumber}: ${account.accountNumber}'),
                  const SizedBox(height: 8),
                  Text(
                    '${strings.currentBalance}: ${_formatMoney(balance)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showAccountDetails(account),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(strings.viewDetails),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showMovementDialog(
                          account,
                          title: strings.deposit,
                          action: 'deposit',
                          descriptionLabel: strings.description,
                          referenceLabel: strings.reference,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.deposit),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showMovementDialog(
                          account,
                          title: strings.withdrawal,
                          action: 'withdrawal',
                          descriptionLabel: strings.description,
                          referenceLabel: strings.reference,
                        ),
                        icon: const Icon(Icons.remove),
                        label: Text(strings.withdrawal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _reconciliationTab() {
    final strings = AppLocalizations.of(context);
    if (_accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.noFinancialAccounts),
        ),
      );
    }

    final account = _accounts.firstWhere(
      (item) => item.id == (_selectedReconciliationAccountId ?? item.id),
      orElse: () => _accounts.first,
    );

    final selectedAccount = account;
    final bookBalanceFuture = widget.database.financialAccounts.getBalance(
      selectedAccount.id,
      asOf: _reconciliationDate,
    );
    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: selectedAccount.id,
            decoration: InputDecoration(labelText: strings.account),
            items: _accounts
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedReconciliationAccountId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _reconciliationDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _reconciliationDate = picked);
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: strings.date),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.yMd(strings.isArabic ? 'ar_EG' : 'en_US')
                        .format(_reconciliationDate),
                  ),
                  const Icon(Icons.calendar_today_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _actualBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: strings.actualBalance),
          ),
          const SizedBox(height: 16),
          FutureBuilder<int>(
            future: bookBalanceFuture,
            builder: (context, snapshot) {
              final bookBalance = snapshot.data ?? 0;
              final actualAmount =
                  _parseMinor(_actualBalanceController.text) ?? 0;
              final variance = actualAmount - bookBalance;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strings.bookBalance}: ${_formatMoney(bookBalance)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${strings.actualBalance}: ${_formatMoney(actualAmount)}',
                      ),
                      const SizedBox(height: 8),
                      Text('${strings.difference}: ${_formatMoney(variance)}'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final parsedActual = _parseMinor(_actualBalanceController.text);
              if (parsedActual == null || parsedActual < 0) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(strings.invalidNumber)));
                return;
              }
              try {
                await widget.database.financialAccounts.reconcileDaily(
                  accountId: selectedAccount.id,
                  date: _reconciliationDate,
                  actualBalanceMinor: parsedActual,
                  note: strings.reconciliationNote,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.reconciliationSaved)),
                );
                setState(() {});
              } catch (error) {
                debugPrint(
                  'Failed to reconcile financial account: ${error.runtimeType}',
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: Text(strings.saveReconciliation),
          ),
          const SizedBox(height: 20),
          Text(
            strings.previousReconciliations,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<AccountReconciliation>>(
            future: widget.database.financialAccounts.getReconciliations(
              accountId: selectedAccount.id,
              limit: 10,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              }
              final reconciliations =
                  snapshot.data ?? const <AccountReconciliation>[];
              if (reconciliations.isEmpty) {
                return Text(strings.noReconciliations);
              }
              return Column(
                children: reconciliations.map((item) {
                  final delta = item.actualBalanceMinor - item.bookBalanceMinor;
                  return ListTile(
                    leading: Icon(
                      item.status == 'matched'
                          ? Icons.check_circle
                          : Icons.warning_amber_outlined,
                      color: item.status == 'matched'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      DateFormat.yMd(strings.isArabic ? 'ar_EG' : 'en_US')
                          .format(item.date),
                    ),
                    subtitle: Text(
                      '${strings.bookBalance}: ${_formatMoney(item.bookBalanceMinor)}',
                    ),
                    trailing: Text(
                      _formatMoney(delta),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Directionality(
      textDirection: strings.isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(strings.financialAccounts),
            bottom: TabBar(
              tabs: [
                Tab(text: strings.accountsTab),
                Tab(text: strings.reconciliationTab),
              ],
            ),
            actions: [
              IconButton(
                tooltip: strings.addAccount,
                onPressed: _showAddAccountDialog,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: TabBarView(children: [_accountsTab(), _reconciliationTab()]),
        ),
      ),
    );
  }
}
