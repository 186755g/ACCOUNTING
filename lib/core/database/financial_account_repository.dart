import 'package:sqflite/sqflite.dart';

import 'models/debt.dart';
import 'models/financial_account.dart';
import 'models/model_utils.dart';
import 'models/payment.dart';

String _resolveStableOperationId(String? operationId) {
  final candidate = (operationId ?? newModelId()).trim();
  if (candidate.isEmpty) {
    throw ArgumentError.value(operationId, 'operationId');
  }
  return candidate;
}

bool _matchesFinancialMovementPayload(
  Map<String, Object?> existing,
  Map<String, Object?> candidate,
) =>
    movementPayloadsMatch(existing, candidate);

class FinancialAccountRepository {
  Future<void> _markOperationPending(
    Transaction transaction, {
    required String operationId,
    required String operationType,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    try {
      await transaction.insert(
        'financial_operation_registry',
        {
          'operation_id': operationId,
          'operation_type': operationType.trim(),
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException {
      final existing = await transaction.query(
        'financial_operation_registry',
        where: 'operation_id = ?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (existing.isEmpty) {
        rethrow;
      }
    }
  }

  Future<void> _markOperationCompleted(
    Transaction transaction,
    String operationId,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await transaction.update(
      'financial_operation_registry',
      {
        'status': 'completed',
        'updated_at': now,
      },
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<String> reserveFinancialOperation({
    required String operationType,
    String? operationId,
    Transaction? transaction,
  }) async {
    final db = transaction ?? _database;
    final normalizedType = operationType.trim();
    if (normalizedType.isEmpty) {
      throw ArgumentError.value(operationType, 'operationType');
    }

    final stableOperationId = _resolveStableOperationId(operationId);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    try {
      await db.insert(
        'financial_operation_registry',
        {
          'operation_id': stableOperationId,
          'operation_type': normalizedType,
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return stableOperationId;
    } on DatabaseException {
      final existing = await db.query(
        'financial_operation_registry',
        where: 'operation_id = ?',
        whereArgs: [stableOperationId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return stableOperationId;
      }
      rethrow;
    }
  }

  Future<void> completeFinancialOperation({
    required String operationId,
    Transaction? transaction,
  }) async {
    final db = transaction ?? _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.update(
      'financial_operation_registry',
      {
        'status': 'completed',
        'updated_at': now,
      },
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

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

    final direction = await _paymentMovementDirection(db, payment);
    final candidate = AccountMovement(
      accountId: accountId,
      direction: direction,
      amountMinor: payment.amountMinor,
      date: payment.date,
      description: _paymentMovementDescription(payment),
      reference: payment.reference ?? payment.id,
      sourceType: 'payment',
      sourceId: payment.id,
    );

    final duplicates = await db.query(
      'account_movements',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['payment', payment.id],
      limit: 1,
    );
    if (duplicates.isNotEmpty) {
      final existing = AccountMovement.fromMap(duplicates.single);
      if (_matchesFinancialMovementPayload(existing.toMap(), candidate.toMap())) {
        return existing;
      }
      throw MovementIdentityConflictException(
        kind: 'financial movement',
        sourceType: 'payment',
        sourceId: payment.id,
        existingSummary: '${existing.accountId}:${existing.direction.name}:${existing.amountMinor}',
        requestSummary: '${candidate.accountId}:${candidate.direction.name}:${candidate.amountMinor}',
      );
    }

    await db.insert('account_movements', candidate.toMap());
    return candidate;
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
    final runInTransaction = (Transaction db) async {
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
      if (normalizedSourceType != null &&
          normalizedSourceType.isNotEmpty &&
          normalizedSourceId != null &&
          normalizedSourceId.isNotEmpty) {
        final duplicates = await db.query(
          'account_movements',
          where: 'source_type = ? AND source_id = ?',
          whereArgs: [normalizedSourceType, normalizedSourceId],
          limit: 1,
        );
        if (duplicates.isNotEmpty) {
          final existing = AccountMovement.fromMap(duplicates.single);
          final candidate = AccountMovement(
            accountId: accountId,
            direction: direction,
            amountMinor: amountMinor,
            date: date,
            description: description,
            reference: normalizedReference,
            sourceType: normalizedSourceType,
            sourceId: normalizedSourceId,
          );
          if (_matchesFinancialMovementPayload(existing.toMap(), candidate.toMap())) {
            return existing;
          }
          throw MovementIdentityConflictException(
            kind: 'financial movement',
            sourceType: normalizedSourceType,
            sourceId: normalizedSourceId,
            existingSummary: '${existing.accountId}:${existing.direction.name}:${existing.amountMinor}',
            requestSummary: '${candidate.accountId}:${candidate.direction.name}:${candidate.amountMinor}',
          );
        }
        await _markOperationPending(
          db,
          operationId: normalizedSourceId,
          operationType: normalizedSourceType,
        );
      }

      final movement = AccountMovement(
        accountId: accountId,
        direction: direction,
        amountMinor: amountMinor,
        date: date,
        description: description,
        reference: normalizedReference,
        sourceType: normalizedSourceType,
        sourceId: normalizedSourceId,
      );
      await db.insert('account_movements', movement.toMap());

      if (normalizedSourceType != null &&
          normalizedSourceType.isNotEmpty &&
          normalizedSourceId != null &&
          normalizedSourceId.isNotEmpty) {
        await _markOperationCompleted(db, normalizedSourceId);
      }
      return movement;
    };

    if (transaction != null) {
      return runInTransaction(transaction);
    }
    return _database.transaction(runInTransaction);
  }

  Future<AccountMovement> recordDeposit({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
    String? operationId,
  }) async {
    final normalizedReference = reference?.trim();
    final stableOperationId = _resolveStableOperationId(operationId);
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.credit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Deposit',
      reference: normalizedReference,
      sourceType: 'account_deposit',
      sourceId: sourceId ?? stableOperationId,
    );
  }

  Future<AccountMovement> recordWithdrawal({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
    String? operationId,
  }) async {
    final normalizedReference = reference?.trim();
    final stableOperationId = _resolveStableOperationId(operationId);
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.debit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Withdrawal',
      reference: normalizedReference,
      sourceType: 'account_withdrawal',
      sourceId: sourceId ?? stableOperationId,
    );
  }

  Future<AccountMovement> recordCommission({
    required String accountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceId,
    String? operationId,
  }) async {
    final normalizedReference = reference?.trim();
    final stableOperationId = _resolveStableOperationId(operationId);
    return recordMovement(
      accountId: accountId,
      direction: AccountMovementDirection.debit,
      amountMinor: amountMinor,
      date: date,
      description: description ?? 'Commission',
      reference: normalizedReference,
      sourceType: 'account_commission',
      sourceId: sourceId ?? stableOperationId,
    );
  }

  Future<AccountTransfer> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? operationId,
    String? commissionOperationId,
    int? commissionMinor,
    String? commissionDescription,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('A transfer must use two different accounts.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor');
    }
    if (commissionMinor != null && commissionMinor <= 0) {
      throw ArgumentError.value(commissionMinor, 'commissionMinor');
    }

    final transferDate = (date ?? DateTime.now()).toUtc();
    final transferOperationId = _resolveStableOperationId(operationId);
    final transferReference = reference?.trim();
    final resolvedCommissionOperationId = (commissionMinor != null && commissionMinor > 0)
        ? (commissionOperationId ?? '$transferOperationId:commission')
        : null;
    if (resolvedCommissionOperationId != null && resolvedCommissionOperationId.trim().isEmpty) {
      throw ArgumentError.value(commissionOperationId, 'commissionOperationId');
    }

    return _database.transaction((transaction) async {
      final sourceAccount = await _requireAccount(transaction, fromAccountId);
      final destinationAccount = await _requireAccount(transaction, toAccountId);
      if (!sourceAccount.isActive || !destinationAccount.isActive) {
        throw StateError('A transfer cannot use an inactive account.');
      }

      await _markOperationPending(
        transaction,
        operationId: transferOperationId,
        operationType: 'account_transfer',
      );
      if (resolvedCommissionOperationId != null) {
        await _markOperationPending(
          transaction,
          operationId: resolvedCommissionOperationId,
          operationType: 'account_commission',
        );
      }

      final transferExists = await transaction.query(
        'account_movements',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: ['account_transfer', transferOperationId],
        limit: 2,
      );
      if (transferExists.isNotEmpty) {
        final expectedTransferRows = [
          AccountMovement(
            accountId: fromAccountId,
            direction: AccountMovementDirection.debit,
            amountMinor: amountMinor,
            date: transferDate,
            description: description ?? 'Internal transfer',
            reference: transferReference,
            sourceType: 'account_transfer',
            sourceId: transferOperationId,
          ),
          AccountMovement(
            accountId: toAccountId,
            direction: AccountMovementDirection.credit,
            amountMinor: amountMinor,
            date: transferDate,
            description: description ?? 'Internal transfer',
            reference: transferReference,
            sourceType: 'account_transfer',
            sourceId: transferOperationId,
          ),
        ];
        final existingTransferRows = transferExists;
        final equivalent = expectedTransferRows.every(
          (expected) => existingTransferRows.any(
            (row) => _matchesFinancialMovementPayload(
              AccountMovement.fromMap(row).toMap(),
              expected.toMap(),
            ),
          ),
        );
        if (equivalent) {
          return AccountTransfer(
            sourceAccountId: fromAccountId,
            destinationAccountId: toAccountId,
            amountMinor: amountMinor,
            date: transferDate,
            description: description ?? 'Internal transfer',
            reference: transferReference,
          );
        }
        throw MovementIdentityConflictException(
          kind: 'financial transfer',
          sourceType: 'account_transfer',
          sourceId: transferOperationId,
          existingSummary: 'existing account_transfer rows differ from expected payload',
          requestSummary: '$fromAccountId->$toAccountId:$amountMinor',
        );
      }

      if (resolvedCommissionOperationId != null) {
        final commissionExists = await transaction.query(
          'account_movements',
          where: 'source_type = ? AND source_id = ?',
          whereArgs: ['account_commission', resolvedCommissionOperationId],
          limit: 1,
        );
        if (commissionExists.isNotEmpty) {
          final existing = AccountMovement.fromMap(commissionExists.single);
          final candidate = AccountMovement(
            accountId: fromAccountId,
            direction: AccountMovementDirection.debit,
            amountMinor: commissionMinor!,
            date: transferDate,
            description: commissionDescription ?? 'Transfer commission',
            reference: transferReference,
            sourceType: 'account_commission',
            sourceId: resolvedCommissionOperationId,
          );
          if (_matchesFinancialMovementPayload(existing.toMap(), candidate.toMap())) {
            return AccountTransfer(
              sourceAccountId: fromAccountId,
              destinationAccountId: toAccountId,
              amountMinor: amountMinor,
              date: transferDate,
              description: description ?? 'Internal transfer',
              reference: transferReference,
            );
          }
          throw MovementIdentityConflictException(
            kind: 'financial commission',
            sourceType: 'account_commission',
            sourceId: resolvedCommissionOperationId,
            existingSummary: '${existing.accountId}:${existing.direction.name}:${existing.amountMinor}',
            requestSummary: '${candidate.accountId}:${candidate.direction.name}:${candidate.amountMinor}',
          );
        }
      }

      final sourceMovement = AccountMovement(
        accountId: fromAccountId,
        direction: AccountMovementDirection.debit,
        amountMinor: amountMinor,
        date: transferDate,
        description: description ?? 'Internal transfer',
        reference: transferReference,
        sourceType: 'account_transfer',
        sourceId: transferOperationId,
      );
      final destinationMovement = AccountMovement(
        accountId: toAccountId,
        direction: AccountMovementDirection.credit,
        amountMinor: amountMinor,
        date: transferDate,
        description: description ?? 'Internal transfer',
        reference: transferReference,
        sourceType: 'account_transfer',
        sourceId: transferOperationId,
      );

      await transaction.insert('account_movements', sourceMovement.toMap());
      await transaction.insert('account_movements', destinationMovement.toMap());

      if (resolvedCommissionOperationId != null && commissionMinor != null && commissionMinor > 0) {
        final commissionMovement = AccountMovement(
          accountId: fromAccountId,
          direction: AccountMovementDirection.debit,
          amountMinor: commissionMinor,
          date: transferDate,
          description: commissionDescription ?? 'Transfer commission',
          reference: transferReference,
          sourceType: 'account_commission',
          sourceId: resolvedCommissionOperationId,
        );
        await transaction.insert('account_movements', commissionMovement.toMap());
      }

      await _markOperationCompleted(transaction, transferOperationId);
      if (resolvedCommissionOperationId != null) {
        await _markOperationCompleted(transaction, resolvedCommissionOperationId);
      }

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
