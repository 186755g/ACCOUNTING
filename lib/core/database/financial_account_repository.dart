import 'package:sqflite/sqflite.dart';

import 'models/debt.dart';
import 'models/financial_account.dart';
import 'models/model_utils.dart';
import 'models/payment.dart';

class FinancialAccountRepository {
  FinancialAccountRepository(this._database);

  final Database _database;

  Future<void> create(FinancialAccount account,
      {Transaction? transaction}) async {
    await (transaction ?? _database).insert(
      'financial_accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> update(FinancialAccount account,
      {Transaction? transaction}) async {
    final db = transaction ?? _database;
    final updated = account.copyWith(updatedAt: DateTime.now().toUtc());
    final rows = await db.update(
      'financial_accounts',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    if (rows == 0) {
      throw StateError('Financial account was not found.');
    }
  }

  Future<bool> delete(String accountId, {Transaction? transaction}) async {
    final db = transaction ?? _database;
    final hasMovements = await db.rawQuery(
      'SELECT 1 FROM account_movements WHERE account_id = ? LIMIT 1',
      [accountId],
    );
    if (hasMovements.isNotEmpty) {
      return false;
    }

    final hasReconciliations = await db.rawQuery(
      'SELECT 1 FROM account_reconciliations WHERE account_id = ? LIMIT 1',
      [accountId],
    );
    if (hasReconciliations.isNotEmpty) {
      return false;
    }

    final deleted = await db.delete(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );
    return deleted > 0;
  }

  Future<FinancialAccount?> getById(String id) async {
    final rows = await _database.query(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : FinancialAccount.fromMap(rows.single);
  }

  Future<List<FinancialAccount>> getAll({
    int? limit,
    int offset = 0,
    bool descending = false,
    String orderBy = 'name',
  }) async {
    final rows = await _database.query(
      'financial_accounts',
      limit: limit,
      offset: offset,
      orderBy: '$orderBy ${descending ? 'DESC' : 'ASC'}',
    );
    return rows.map(FinancialAccount.fromMap).toList(growable: false);
  }

  Future<int> getBalance(String accountId, {DateTime? asOf}) async {
    final account = await getById(accountId);
    if (account == null) {
      throw StateError('Financial account was not found.');
    }

    final referenceDate = (asOf ?? DateTime.now()).toUtc();
    final rows = await _database.rawQuery(
      '''
      SELECT COALESCE(?, 0) + COALESCE((
        SELECT SUM(
          CASE direction
            WHEN 'credit' THEN amount_minor
            ELSE -amount_minor
          END)
        FROM account_movements
        WHERE account_id = ? AND date_at <= ?
      ), 0) AS balance
      ''',
      [account.openingBalanceMinor, accountId, dateToDatabase(referenceDate)],
    );
    return requiredInt(rows.single, 'balance');
  }

  Future<String?> resolveAccountIdForPayment(
    PaymentMethod method, {
    DatabaseExecutor? database,
  }) async {
    final accountType = switch (method) {
      PaymentMethod.cash => FinancialAccountType.cash,
      PaymentMethod.bankTransfer => FinancialAccountType.bank,
      PaymentMethod.card => FinancialAccountType.card,
      PaymentMethod.mobileWallet => FinancialAccountType.mobileWallet,
      PaymentMethod.other => null,
    };
    if (accountType == null) {
      return null;
    }

    final executor = database ?? _database;
    final rows = await executor.query(
      'financial_accounts',
      where: 'type = ? AND is_active = ?',
      whereArgs: [accountType.name, 1],
      orderBy: 'name COLLATE NOCASE',
      limit: 1,
    );
    return rows.isEmpty ? null : requiredString(rows.single, 'id');
  }

  Future<AccountMovement?> recordPaymentMovement(
    Payment payment, {
    Transaction? transaction,
  }) async {
    final db = transaction ?? _database;
    final accountId = (payment.financialAccountId ?? await resolveAccountIdForPayment(payment.method, database: db))?.trim();
    if (accountId == null || accountId.isEmpty) {
      return null;
    }

    final duplicates = await db.query(
      'account_movements',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['payment', payment.id],
      limit: 1,
    );
    if (duplicates.isNotEmpty) {
      return AccountMovement.fromMap(duplicates.single);
    }

    final direction = await _paymentMovementDirection(db, payment);
    final movement = AccountMovement(
      accountId: accountId,
      direction: direction,
      amountMinor: payment.amountMinor,
      date: payment.date,
      description: _paymentMovementDescription(payment),
      reference: payment.reference ?? payment.id,
      sourceType: 'payment',
      sourceId: payment.id,
    );
    await db.insert('account_movements', movement.toMap());
    return movement;
  }

  Future<AccountMovement> recordMovement({
    required String accountId,
    required AccountMovementDirection direction,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceType,
    String? sourceId,
    Transaction? transaction,
  }) async {
    final db = transaction ?? _database;
    final account = await _requireAccount(db, accountId);
    if (!account.isActive) {
      throw StateError('Financial account is inactive and cannot receive movements.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor');
    }

    final normalizedReference = reference?.trim();
    final normalizedSourceType = sourceType?.trim();
    final normalizedSourceId = sourceId?.trim();
    if ((normalizedReference != null && normalizedReference.isNotEmpty) ||
        (normalizedSourceType != null && normalizedSourceType.isNotEmpty)) {
      final duplicateWhere = <String>[];
      final duplicateArgs = <Object?>[];
      if (normalizedReference != null && normalizedReference.isNotEmpty) {
        duplicateWhere.add('reference = ?');
        duplicateArgs.add(normalizedReference);
      }
      if (normalizedSourceType != null && normalizedSourceType.isNotEmpty) {
        duplicateWhere.add('source_type = ? AND source_id = ?');
        duplicateArgs
          ..add(normalizedSourceType)
          ..add(normalizedSourceId ?? normalizedReference ?? accountId);
      }
      final duplicates = await db.query(
        'account_movements',
        where: duplicateWhere.join(' OR '),
        whereArgs: duplicateArgs,
        limit: 1,
      );
      if (duplicates.isNotEmpty) {
        throw StateError('A duplicate financial movement already exists.');
      }
    }

    final movement = AccountMovement(
      accountId: accountId,
      direction: direction,
      amountMinor: amountMinor,
      date: date,
      description: description,
      reference: normalizedReference,
      sourceType: normalizedSourceType,
      sourceId: normalizedSourceId ?? normalizedReference ?? sourceType,
    );
    await db.insert('account_movements', movement.toMap());
    return movement;
  }

  Future<AccountMovement> recordDeposit({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
  }) async {
    final normalizedReference = reference?.trim();
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.credit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Deposit',
      reference: normalizedReference,
      sourceType: 'account_deposit',
      sourceId: sourceId ?? normalizedReference ?? 'deposit-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  Future<AccountMovement> recordWithdrawal({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
  }) async {
    final normalizedReference = reference?.trim();
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.debit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Withdrawal',
      reference: normalizedReference,
      sourceType: 'account_withdrawal',
      sourceId: sourceId ?? normalizedReference ?? 'withdrawal-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  Future<AccountMovement> recordCommission({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
  }) async {
    final normalizedReference = reference?.trim();
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.debit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Commission',
      reference: normalizedReference,
      sourceType: 'account_commission',
      sourceId: sourceId ?? normalizedReference ?? 'commission-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  Future<AccountTransfer> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('A transfer must use two different accounts.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor');
    }

    final transferDate = (date ?? DateTime.now()).toUtc();
    final transferReference = (reference ?? 'transfer-${DateTime.now().toUtc().microsecondsSinceEpoch}').trim();
    if (transferReference.isEmpty) {
      throw ArgumentError.value(reference, 'reference');
    }

    return _database.transaction((transaction) async {
      final sourceAccount = await _requireAccount(transaction, fromAccountId);
      final destinationAccount = await _requireAccount(transaction, toAccountId);
      if (!sourceAccount.isActive || !destinationAccount.isActive) {
        throw StateError('A transfer cannot use an inactive account.');
      }

      final duplicateRooms = await transaction.query(
        'account_movements',
        where: 'reference = ? AND source_type = ?',
        whereArgs: [transferReference, 'account_transfer'],
        limit: 1,
      );
      if (duplicateRooms.isNotEmpty) {
        throw StateError('A duplicate transfer already exists.');
      }

      final sourceMovement = AccountMovement(
        accountId: fromAccountId,
        direction: AccountMovementDirection.debit,
        amountMinor: amountMinor,
        date: transferDate,
        description: description ?? 'Internal transfer',
        reference: transferReference,
        sourceType: 'account_transfer',
        sourceId: transferReference,
      );
      final destinationMovement = AccountMovement(
        accountId: toAccountId,
        direction: AccountMovementDirection.credit,
        amountMinor: amountMinor,
        date: transferDate,
        description: description ?? 'Internal transfer',
        reference: transferReference,
        sourceType: 'account_transfer',
        sourceId: transferReference,
      );

      await transaction.insert('account_movements', sourceMovement.toMap());
      await transaction.insert('account_movements', destinationMovement.toMap());

      return AccountTransfer(
        sourceAccountId: fromAccountId,
        destinationAccountId: toAccountId,
        amountMinor: amountMinor,
        date: transferDate,
        description: description ?? 'Internal transfer',
        reference: transferReference,
      );
    });
  }

  Future<AccountReconciliation> reconcileDaily({
    required String accountId,
    required DateTime date,
    required int actualBalanceMinor,
    String? note,
  }) async {
    final account = await getById(accountId);
    if (account == null) {
      throw StateError('Financial account was not found.');
    }
    final bookBalanceMinor = await getBalance(accountId, asOf: date);
    final reconciliation = AccountReconciliation(
      accountId: accountId,
      date: date,
      bookBalanceMinor: bookBalanceMinor,
      actualBalanceMinor: actualBalanceMinor,
      note: note,
    );
    await _database.insert('account_reconciliations', reconciliation.toMap());
    return reconciliation;
  }

  Future<List<AccountMovement>> getMovements({
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    clauses.add('account_id = ?');
    args.add(accountId);
    if (fromDate != null) {
      clauses.add('date_at >= ?');
      args.add(dateToDatabase(fromDate));
    }
    if (toDate != null) {
      clauses.add('date_at < ?');
      args.add(dateToDatabase(toDate));
    }

    final rows = await _database.query(
      'account_movements',
      where: clauses.join(' AND '),
      whereArgs: args,
      limit: limit,
      offset: offset,
      orderBy: 'date_at DESC, created_at DESC',
    );
    return rows.map(AccountMovement.fromMap).toList(growable: false);
  }

  Future<List<AccountReconciliation>> getReconciliations({
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    clauses.add('account_id = ?');
    args.add(accountId);
    if (fromDate != null) {
      clauses.add('date_at >= ?');
      args.add(dateToDatabase(fromDate));
    }
    if (toDate != null) {
      clauses.add('date_at < ?');
      args.add(dateToDatabase(toDate));
    }

    final rows = await _database.query(
      'account_reconciliations',
      where: clauses.join(' AND '),
      whereArgs: args,
      limit: limit,
      offset: offset,
      orderBy: 'date_at DESC, created_at DESC',
    );
    return rows.map(AccountReconciliation.fromMap).toList(growable: false);
  }

  Future<AccountMovementDirection> _paymentMovementDirection(
    DatabaseExecutor database,
    Payment payment,
  ) async {
    if (payment.saleId != null) {
      return AccountMovementDirection.credit;
    }
    if (payment.purchaseId != null || payment.expenseId != null) {
      return AccountMovementDirection.debit;
    }
    if (payment.debtId != null) {
      final rows = await database.query(
        'debts',
        where: 'id = ?',
        whereArgs: [payment.debtId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Payment debt was not found.');
      }
      final debt = Debt.fromMap(rows.single);
      return debt.direction == DebtDirection.receivable
          ? AccountMovementDirection.credit
          : AccountMovementDirection.debit;
    }
    throw StateError('Payment is not associated with a known ledger entry.');
  }

  String _paymentMovementDescription(Payment payment) {
    if (payment.notes != null && payment.notes!.trim().isNotEmpty) {
      return payment.notes!.trim();
    }
    if (payment.saleId != null) return 'Sale payment';
    if (payment.purchaseId != null) return 'Purchase payment';
    if (payment.expenseId != null) return 'Expense payment';
    if (payment.debtId != null) return 'Debt payment';
    return 'Cash movement';
  }

  Future<FinancialAccount> _requireAccount(
    DatabaseExecutor database,
    String accountId,
  ) async {
    final rows = await database.query(
      'financial_accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Financial account was not found.');
    }
    return FinancialAccount.fromMap(rows.single);
  }
}
