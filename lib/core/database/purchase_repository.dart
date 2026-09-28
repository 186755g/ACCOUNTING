import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';
import 'models/purchase.dart';
import 'models/purchase_item.dart';
import 'inventory_repository.dart';
import 'sqlite_entity_repository.dart';

class PurchaseRepository {
  PurchaseRepository(Database database)
    : _database = database,
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
  final InventoryRepository _inventory;
  final SqliteEntityRepository<_PurchaseRow> _purchases;

  Future<void> create(Purchase purchase) =>
      _database.transaction((transaction) async {
        _validateItems(purchase);
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
      });

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

  Future<void> update(Purchase purchase) => _database.transaction((
    transaction,
  ) async {
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
  });

  Future<bool> delete(String id) => _database.transaction((transaction) async {
    final rows = await transaction.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final purchase = await _hydrate(rows.single, executor: transaction);
    await _applyInventory(purchase, transaction, reverse: true);
    return _purchases.delete(id, transaction: transaction);
  });

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
