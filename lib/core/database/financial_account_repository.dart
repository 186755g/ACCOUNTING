import 'package:sqflite/sqflite.dart';

import 'models/financial_account.dart';
import 'models/model_utils.dart';

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

  Future<AccountMovement> recordMovement({
    required String accountId,
    required AccountMovementDirection direction,
    required int amountMinor,
    DateTime? date,
    String? description,
    String? reference,
    String? sourceType,
    String? sourceId,
  }) async {
    final account = await getById(accountId);
    if (account == null) {
      throw StateError('Financial account was not found.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor');
    }

    final movement = AccountMovement(
      accountId: accountId,
      direction: direction,
      amountMinor: amountMinor,
      date: date,
      description: description,
      reference: reference,
      sourceType: sourceType,
      sourceId: sourceId,
    );
    await _database.insert('account_movements', movement.toMap());
    return movement;
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
}
