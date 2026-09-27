import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';
import 'models/purchase.dart';
import 'models/purchase_item.dart';
import 'sqlite_entity_repository.dart';

class PurchaseRepository {
  PurchaseRepository(Database database)
    : _database = database,
      _purchases = SqliteEntityRepository<_PurchaseRow>(
        database,
        table: 'purchases',
        fromMap: _PurchaseRow.fromMap,
        searchableColumns: const ['id', 'status', 'notes'],
        filterableColumns: const {'id', 'supplier_id', 'user_id', 'status'},
        dateColumn: 'date_at',
      );

  final Database _database;
  final SqliteEntityRepository<_PurchaseRow> _purchases;

  Future<void> create(Purchase purchase) =>
      _database.transaction((transaction) async {
        _validateItems(purchase);
        await _purchases.create(
          _PurchaseRow(purchase.toMap()),
          transaction: transaction,
        );
        for (final item in purchase.items) {
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

  Future<void> update(Purchase purchase) =>
      _database.transaction((transaction) async {
        _validateItems(purchase);
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
      });

  Future<bool> delete(String id) => _purchases.delete(id);

  Future<Purchase> _hydrate(Map<String, Object?> row) async {
    final purchaseId = requiredString(row, 'id');
    final rows = await _database.query(
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
