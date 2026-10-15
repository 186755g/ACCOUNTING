import 'package:sqflite/sqflite.dart';

import '../services/installation_identity_store.dart';
import 'financial_account_repository.dart';
import 'models/model_utils.dart';
import 'models/purchase.dart';
import 'models/purchase_item.dart';
import 'models/debt.dart';
import 'models/payment.dart';
import 'models/sale_tender.dart';
import 'inventory_repository.dart';
import 'sqlite_entity_repository.dart';
import 'sync_outbox_repository.dart';

class PurchaseRepository {
  PurchaseRepository(
    Database database, {
    required this._installationIdentity,
    required this._outbox,
    FinancialAccountRepository? financialAccounts,
  }) : _database = database,
       _financialAccounts = financialAccounts ?? FinancialAccountRepository(database),
       _inventory = InventoryRepository(database),
       _purchases = SqliteEntityRepository<_PurchaseRow>(
         database,
         table: 'purchases',
         fromMap: _PurchaseRow.fromMap,
         searchableColumns: const ['id', 'status', 'notes'],
         filterableColumns: const {'id', 'supplier_id', 'user_id', 'status'},
         dateColumn: 'date_at',
       );

  final Database _database;
  final InstallationIdentityStore _installationIdentity;
  final SyncOutboxRepository _outbox;
  final FinancialAccountRepository _financialAccounts;
  final InventoryRepository _inventory;
  final SqliteEntityRepository<_PurchaseRow> _purchases;

  Future<void> checkout(
    Purchase purchase, {
    required List<SaleTender> tenders,
  }) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      if (purchase.status != 'received') {
        throw ArgumentError('A checkout purchase must have received status.');
      }
      if (tenders.any((tender) => tender.amountMinor <= 0)) {
        throw ArgumentError('Every purchase tender must be greater than zero.');
      }
      final paidMinor = tenders.fold<int>(
        0,
        (total, tender) => total + tender.amountMinor,
      );
      if (paidMinor > purchase.totalMinor) {
        throw ArgumentError('Payment total cannot exceed the purchase total.');
      }
      final unpaidMinor = purchase.totalMinor - paidMinor;
      if (unpaidMinor > 0 && purchase.supplierId == null) {
        throw ArgumentError(
          'A supplier is required for unpaid purchase balance.',
        );
      }

      await _validateSupplier(purchase, transaction);
      await _createInTransaction(purchase, transaction);
      final createdPayments = <Payment>[];
      for (final tender in tenders) {
        final financialAccountId = await _financialAccounts.resolveAccountIdForPayment(
          tender.method,
          database: transaction,
        );
        final payment = Payment(
          purchaseId: purchase.id,
          amountMinor: tender.amountMinor,
          method: tender.method,
          date: purchase.date,
          financialAccountId: financialAccountId,
        );
        await transaction.insert(
          'payments',
          payment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await _financialAccounts.recordPaymentMovement(
          payment,
          transaction: transaction,
        );
        createdPayments.add(payment);
        if (installationId != null) {
          await _outbox.recordPaymentChange(
            transaction,
            installationId: installationId,
            paymentId: payment.id,
            operation: 'create',
            payload: payment.toMap(),
          );
        }
      }
      Debt? createdDebt;
      if (unpaidMinor > 0) {
        createdDebt = Debt(
          supplierId: purchase.supplierId,
          purchaseId: purchase.id,
          direction: DebtDirection.payable,
          amountMinor: unpaidMinor,
          dueDate: purchase.date.add(const Duration(days: 30)),
          description: 'Unpaid balance for purchase ${purchase.id}',
          createdAt: purchase.date,
          updatedAt: purchase.date,
        );
        await transaction.insert(
          'debts',
          createdDebt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        if (installationId != null) {
          await _outbox.recordDebtChange(
            transaction,
            installationId: installationId,
            debtId: createdDebt.id,
            operation: 'create',
            payload: createdDebt.toMap(),
          );
        }
      }
      if (installationId != null) {
        final payload = <String, Object?>{
          'purchase': purchase.toMap(),
          'items': purchase.items.map((item) => item.toMap()).toList(),
          'payments': createdPayments.map((payment) => payment.toMap()).toList(),
          'debt': createdDebt?.toMap(),
        };
        await _outbox.recordPurchaseChange(
          transaction,
          installationId: installationId,
          purchaseId: purchase.id,
          operation: 'create',
          payload: payload,
        );
      }
    });
  }

  Future<void> create(Purchase purchase) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      _validateItems(purchase);
      await _validateSupplier(purchase, transaction);
      await _purchases.create(
        _PurchaseRow(purchase.toMap()),
        transaction: transaction,
      );
      for (final item in purchase.items) {
        if (purchase.status == 'received') {
          await _inventory.recordStockChange(
            transaction,
            productId: item.productId,
            quantity: item.quantity,
            reason: 'purchase',
            date: purchase.date,
            sourceType: 'purchase',
            sourceId: purchase.id,
          );
        }
        await transaction.insert(
          'purchase_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      if (installationId != null) {
        final payload = <String, Object?>{
          'purchase': purchase.toMap(),
          'items': purchase.items.map((item) => item.toMap()).toList(),
        };
        await _outbox.recordPurchaseChange(
          transaction,
          installationId: installationId,
          purchaseId: purchase.id,
          operation: 'create',
          payload: payload,
        );
      }
    });
  }

  Future<void> _createInTransaction(
    Purchase purchase,
    Transaction transaction,
  ) async {
    _validateItems(purchase);
    await _purchases.create(
      _PurchaseRow(purchase.toMap()),
      transaction: transaction,
    );
    for (final item in purchase.items) {
      await _inventory.recordStockChange(
        transaction,
        productId: item.productId,
        quantity: item.quantity,
        reason: 'purchase',
        date: purchase.date,
        sourceType: 'purchase',
        sourceId: purchase.id,
      );
      await transaction.insert(
        'purchase_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<void> _validateSupplier(
    Purchase purchase,
    Transaction transaction,
  ) async {
    final supplierId = purchase.supplierId;
    if (supplierId == null) return;
    final rows = await transaction.query(
      'suppliers',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Supplier was not found.');
  }

  Future<Purchase?> getById(String id) async {
    final purchase = await _purchases.getById(id);
    return purchase == null ? null : _hydrate(purchase.values);
  }

  Future<List<Purchase>> getAll({
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'date_at',
    bool descending = true,
  }) async {
    final rows = await _purchases.getAll(
      filters: filters,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      descending: descending,
    );
    return Future.wait(rows.map((row) => _hydrate(row.values)));
  }

  Future<List<Purchase>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'date_at',
    bool descending = true,
  }) async {
    final rows = await _purchases.search(
      query,
      filters: filters,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      descending: descending,
    );
    return Future.wait(rows.map((row) => _hydrate(row.values)));
  }

  Future<void> update(Purchase purchase) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      _validateItems(purchase);
      final existing = await transaction.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [purchase.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError(
          'Cannot update missing purchases record "${purchase.id}".',
        );
      }
      final previousPurchase = await _hydrate(
        existing.single,
        executor: transaction,
      );
      await _purchases.update(
        _PurchaseRow(purchase.toMap()),
        transaction: transaction,
      );
      await transaction.delete(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchase.id],
      );
      for (final item in purchase.items) {
        await transaction.insert(
          'purchase_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await _applyInventoryDifference(previousPurchase, purchase, transaction);
      if (installationId != null && _purchaseHasMeaningfulChange(previousPurchase, purchase)) {
        final payload = <String, Object?>{
          'purchase': purchase.toMap(),
          'items': purchase.items.map((item) => item.toMap()).toList(),
        };
        await _outbox.recordPurchaseChange(
          transaction,
          installationId: installationId,
          purchaseId: purchase.id,
          operation: 'update',
          payload: payload,
        );
      }
    });
  }

  Future<bool> delete(String id) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    return _database.transaction((transaction) async {
      final rows = await transaction.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final purchase = await _hydrate(rows.single, executor: transaction);
      final payload = <String, Object?>{
        'purchase': purchase.toMap(),
        'items': purchase.items.map((item) => item.toMap()).toList(),
      };
      await _applyInventory(purchase, transaction, reverse: true);
      final deleted = await _purchases.delete(id, transaction: transaction);
      if (!deleted) return false;
      if (installationId != null) {
        await _outbox.recordPurchaseChange(
          transaction,
          installationId: installationId,
          purchaseId: id,
          operation: 'delete',
          payload: payload,
        );
      }
      return true;
    });
  }

  Future<Purchase> _hydrate(
    Map<String, Object?> row, {
    DatabaseExecutor? executor,
  }) async {
    final purchaseId = requiredString(row, 'id');
    final rows = await (executor ?? _database).query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
      orderBy: 'rowid ASC',
    );
    return Purchase.fromMap(
      row,
      items: rows.map(PurchaseItem.fromMap).toList(growable: false),
    );
  }

  Future<void> _applyInventory(
    Purchase purchase,
    Transaction transaction, {
    bool reverse = false,
  }) async {
    if (purchase.status != 'received') return;
    for (final item in purchase.items) {
      await _inventory.recordStockChange(
        transaction,
        productId: item.productId,
        quantity: reverse ? -item.quantity : item.quantity,
        reason: reverse ? 'purchase_reversal' : 'purchase',
        date: purchase.date,
        sourceType: 'purchase',
        sourceId: purchase.id,
      );
    }
  }

  Future<void> _applyInventoryDifference(
    Purchase previous,
    Purchase updated,
    Transaction transaction,
  ) async {
    final changes = <String, double>{};
    if (previous.status == 'received') {
      for (final item in previous.items) {
        changes.update(
          item.productId,
          (quantity) => quantity - item.quantity,
          ifAbsent: () => -item.quantity,
        );
      }
    }
    if (updated.status == 'received') {
      for (final item in updated.items) {
        changes.update(
          item.productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    for (final entry in changes.entries) {
      if (entry.value.abs() < 0.000001) continue;
      await _inventory.recordStockChange(
        transaction,
        productId: entry.key,
        quantity: entry.value,
        reason: 'purchase_adjustment',
        date: updated.date,
        sourceType: 'purchase',
        sourceId: updated.id,
      );
    }
  }

  bool _purchaseHasMeaningfulChange(Purchase previous, Purchase updated) {
    if (!_mapsEqual(previous.toMap(), updated.toMap())) {
      return true;
    }
    if (previous.items.length != updated.items.length) {
      return true;
    }
    for (var index = 0; index < previous.items.length; index++) {
      if (!_mapsEqual(
        previous.items[index].toMap(),
        updated.items[index].toMap(),
      )) {
        return true;
      }
    }
    return false;
  }

  bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void _validateItems(Purchase purchase) {
    if (purchase.items.isEmpty) {
      throw ArgumentError('A purchase must contain at least one item.');
    }
    if (purchase.items.any((item) => item.purchaseId != purchase.id)) {
      throw ArgumentError('Every purchase item must reference this purchase.');
    }
  }
}

class _PurchaseRow implements DatabaseEntity {
  _PurchaseRow(this.values);

  final Map<String, Object?> values;

  @override
  String get id => requiredString(values, 'id');

  @override
  Map<String, Object?> toMap() => Map.of(values);

  factory _PurchaseRow.fromMap(Map<String, Object?> map) =>
      _PurchaseRow(Map.of(map));
}
