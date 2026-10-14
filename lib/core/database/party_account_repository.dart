import 'package:sqflite/sqflite.dart';

import '../services/installation_identity_store.dart';
import 'models/debt.dart';
import 'models/model_utils.dart';
import 'models/payment.dart';
import 'sync_outbox_repository.dart';

class PartyAccountRepository {
  PartyAccountRepository(
    Database database, {
    required InstallationIdentityStore installationIdentity,
    required SyncOutboxRepository outbox,
  }) : _database = database,
       _installationIdentity = installationIdentity,
       _outbox = outbox;

  final Database _database;
  final InstallationIdentityStore _installationIdentity;
  final SyncOutboxRepository _outbox;

  Future<PartyAccountSummary> getCustomerSummary(String customerId) =>
      _getSummary(
        ownerColumn: 'customer_id',
        ownerId: customerId,
        documentsTable: 'sales',
        documentIdColumn: 'sale_id',
        direction: DebtDirection.receivable,
      );

  Future<PartyAccountSummary> getSupplierSummary(String supplierId) =>
      _getSummary(
        ownerColumn: 'supplier_id',
        ownerId: supplierId,
        documentsTable: 'purchases',
        documentIdColumn: 'purchase_id',
        direction: DebtDirection.payable,
      );

  Future<PartyAccountSummary> _getSummary({
    required String ownerColumn,
    required String ownerId,
    required String documentsTable,
    required String documentIdColumn,
    required DebtDirection direction,
  }) async {
    final documents = await _database.rawQuery(
      'SELECT COALESCE(SUM(total_minor), 0) AS total FROM $documentsTable '
      'WHERE $ownerColumn = ?',
      [ownerId],
    );
    final debts = await _database.rawQuery(
      'SELECT COALESCE(SUM(d.amount_minor), 0) AS total, '
      'COALESCE(SUM((SELECT COALESCE(SUM(p.amount_minor), 0) '
      'FROM payments p WHERE p.debt_id = d.id)), 0) AS paid '
      'FROM debts d WHERE d.$ownerColumn = ? AND d.direction = ?',
      [ownerId, direction.name],
    );
    final directPayments = await _database.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM payments '
      'WHERE $documentIdColumn IN '
      '(SELECT id FROM $documentsTable WHERE $ownerColumn = ?)',
      [ownerId],
    );
    final debtRow = debts.single;
    final debtTotal = requiredInt(debtRow, 'total');
    final debtPaid = requiredInt(debtRow, 'paid');
    return PartyAccountSummary(
      documentTotalMinor: requiredInt(documents.single, 'total'),
      totalPaidMinor: requiredInt(directPayments.single, 'total') + debtPaid,
      outstandingMinor: debtTotal - debtPaid,
    );
  }

  Future<Debt> addCustomerDebt({
    required String customerId,
    required int amountMinor,
    String? description,
    DateTime? dueDate,
  }) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    return _database.transaction((transaction) async {
      final debt = Debt(
        customerId: customerId,
        direction: DebtDirection.receivable,
        amountMinor: amountMinor,
        dueDate: (dueDate ?? DateTime.now().add(const Duration(days: 30)))
            .toUtc(),
        description: description,
      );
      await transaction.insert('debts', debt.toMap());
      if (installationId != null) {
        await _outbox.recordDebtChange(
          transaction,
          installationId: installationId,
          debtId: debt.id,
          operation: 'create',
          payload: debt.toMap(),
        );
      }
      return debt;
    });
  }

  Future<Debt> addSupplierDebt({
    required String supplierId,
    required int amountMinor,
    String? description,
    DateTime? dueDate,
  }) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    return _database.transaction((transaction) async {
      final debt = Debt(
        supplierId: supplierId,
        direction: DebtDirection.payable,
        amountMinor: amountMinor,
        dueDate: (dueDate ?? DateTime.now().add(const Duration(days: 30)))
            .toUtc(),
        description: description,
      );
      await transaction.insert('debts', debt.toMap());
      if (installationId != null) {
        await _outbox.recordDebtChange(
          transaction,
          installationId: installationId,
          debtId: debt.id,
          operation: 'create',
          payload: debt.toMap(),
        );
      }
      return debt;
    });
  }

  Future<int> getOutstandingForDebt(String debtId) async {
    final rows = await _database.rawQuery(
      'SELECT d.amount_minor - COALESCE(SUM(p.amount_minor), 0) AS outstanding '
      'FROM debts d LEFT JOIN payments p ON p.debt_id = d.id '
      'WHERE d.id = ? GROUP BY d.id',
      [debtId],
    );
    return rows.isEmpty ? 0 : requiredInt(rows.single, 'outstanding');
  }

  Future<int> getOutstandingForParty({
    required String partyId,
    required DebtDirection direction,
  }) async {
    final ownerColumn = direction == DebtDirection.receivable
        ? 'customer_id'
        : 'supplier_id';
    final rows = await _database.rawQuery(
      'SELECT COALESCE(SUM(d.amount_minor - '
      'COALESCE((SELECT SUM(p.amount_minor) FROM payments p '
      'WHERE p.debt_id = d.id), 0)), 0) AS total '
      'FROM debts d WHERE d.$ownerColumn = ? AND d.direction = ?',
      [partyId, direction.name],
    );
    return requiredInt(rows.single, 'total');
  }

  Future<Payment> recordPayment({
    required String debtId,
    required int amountMinor,
    required PaymentMethod method,
    DateTime? date,
    String? notes,
  }) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Debt was not found.');
      final debt = Debt.fromMap(rows.single);
      final payments = await transaction.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS paid '
        'FROM payments WHERE debt_id = ?',
        [debtId],
      );
      final outstanding = debt.amountMinor - requiredInt(payments.single, 'paid');
      if (amountMinor <= 0 || amountMinor > outstanding) {
        throw ArgumentError(
          'Payment must be positive and no greater than the outstanding debt.',
        );
      }
      final payment = Payment(
        debtId: debtId,
        amountMinor: amountMinor,
        method: method,
        date: date,
        notes: notes,
      );
      await transaction.insert('payments', payment.toMap());
      if (installationId != null) {
        await _outbox.recordPaymentChange(
          transaction,
          installationId: installationId,
          paymentId: payment.id,
          operation: 'create',
          payload: payment.toMap(),
        );
      }
      return payment;
    });
  }
}

class PartyAccountSummary {
  const PartyAccountSummary({
    required this.documentTotalMinor,
    required this.totalPaidMinor,
    required this.outstandingMinor,
  });

  final int documentTotalMinor;
  final int totalPaidMinor;
  final int outstandingMinor;
}
