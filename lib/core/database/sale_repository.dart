import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';
import 'models/debt.dart';
import 'models/payment.dart';
import 'models/sale.dart';
import 'models/sale_item.dart';
import 'models/sale_tender.dart';
import 'inventory_repository.dart';
import 'sqlite_entity_repository.dart';

class SaleRepository {
  SaleRepository(Database database)
    : _database = database,
      _inventory = InventoryRepository(database),
      _sales = SqliteEntityRepository<_SaleRow>(
        database,
        table: 'sales',
        fromMap: _SaleRow.fromMap,
        searchableColumns: const ['id', 'status', 'notes'],
        filterableColumns: const {'id', 'customer_id', 'user_id', 'status'},
        dateColumn: 'date_at',
      );

  final Database _database;
  final InventoryRepository _inventory;
  final SqliteEntityRepository<_SaleRow> _sales;

  Future<void> create(Sale sale) => _database.transaction((transaction) async {
    await _createInTransaction(sale, transaction);
  });

  Future<Sale> checkout(
    Sale sale, {
    required List<SaleTender> tenders,
  }) => _database.transaction((transaction) async {
    if (sale.status != 'completed') {
      throw ArgumentError('A checkout sale must have completed status.');
    }
    if (tenders.any((tender) => tender.amountMinor <= 0)) {
      throw ArgumentError('Every sale tender must be greater than zero.');
    }
    final paidMinor = tenders.fold<int>(
      0,
      (total, tender) => total + tender.amountMinor,
    );
    if (paidMinor > sale.totalMinor) {
      throw ArgumentError('Payment total cannot exceed the sale total.');
    }
    final unpaidMinor = sale.totalMinor - paidMinor;
    if (unpaidMinor > 0 && sale.customerId == null) {
      throw ArgumentError('A customer is required for unpaid sale balance.');
    }

    await _createInTransaction(sale, transaction);
    for (final tender in tenders) {
      await transaction.insert(
        'payments',
        Payment(
          saleId: sale.id,
          amountMinor: tender.amountMinor,
          method: tender.method,
          date: sale.date,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    if (unpaidMinor > 0) {
      await transaction.insert(
        'debts',
        Debt(
          customerId: sale.customerId,
          saleId: sale.id,
          direction: DebtDirection.receivable,
          amountMinor: unpaidMinor,
          dueDate: sale.date.add(const Duration(days: 30)),
          description: 'Unpaid balance for sale ${sale.id}',
          createdAt: sale.date,
          updatedAt: sale.date,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    return sale;
  });

  Future<void> _createInTransaction(Sale sale, Transaction transaction) async {
    _validateItems(sale);
    await _sales.create(_SaleRow(sale.toMap()), transaction: transaction);
    for (final item in sale.items) {
      if (sale.status == 'completed') {
        await _inventory.recordStockChange(
          transaction,
          productId: item.productId,
          quantity: -item.quantity,
          reason: 'sale',
          date: sale.date,
          sourceType: 'sale',
          sourceId: sale.id,
        );
      }
      await transaction.insert(
        'sale_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<Sale?> getById(String id) async {
    final row = await _sales.getById(id);
    if (row == null) return null;
    return _hydrate(row.values);
  }

  Future<List<Sale>> getAll({
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'date_at',
    bool descending = true,
  }) async {
    final rows = await _sales.getAll(
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

  Future<List<Sale>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'date_at',
    bool descending = true,
  }) async {
    final rows = await _sales.search(
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

  Future<void> update(Sale sale) => _database.transaction((transaction) async {
    _validateItems(sale);
    final existing = await transaction.query(
      'sales',
      where: 'id = ?',
      whereArgs: [sale.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw StateError('Cannot update missing sales record "${sale.id}".');
    }
    final previousSale = await _hydrate(existing.single, executor: transaction);
    final returnedItems = await transaction.query(
      'product_returns',
      columns: ['sale_item_id'],
      where: 'sale_id = ?',
      whereArgs: [sale.id],
      limit: 1,
    );
    if (returnedItems.isNotEmpty) {
      throw StateError('A sale with returned items cannot be edited.');
    }
    await _sales.update(_SaleRow(sale.toMap()), transaction: transaction);
    await transaction.delete(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [sale.id],
    );
    for (final item in sale.items) {
      await transaction.insert(
        'sale_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    await _applyInventoryDifference(previousSale, sale, transaction);
  });

  Future<bool> delete(String id) => _database.transaction((transaction) async {
    final rows = await transaction.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final sale = await _hydrate(rows.single, executor: transaction);
    await _applyInventory(sale, transaction, reverse: true);
    return _sales.delete(id, transaction: transaction);
  });

  Future<Sale> _hydrate(
    Map<String, Object?> row, {
    DatabaseExecutor? executor,
  }) async {
    final saleId = requiredString(row, 'id');
    final rows = await (executor ?? _database).query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'rowid ASC',
    );
    return Sale.fromMap(
      row,
      items: rows.map(SaleItem.fromMap).toList(growable: false),
    );
  }

  Future<void> _applyInventory(
    Sale sale,
    Transaction transaction, {
    bool reverse = false,
  }) async {
    if (sale.status != 'completed') return;
    for (final item in sale.items) {
      await _inventory.recordStockChange(
        transaction,
        productId: item.productId,
        quantity: reverse ? item.quantity : -item.quantity,
        reason: reverse ? 'sale_reversal' : 'sale',
        date: sale.date,
        sourceType: 'sale',
        sourceId: sale.id,
      );
    }
  }

  Future<void> _applyInventoryDifference(
    Sale previous,
    Sale updated,
    Transaction transaction,
  ) async {
    final changes = <String, double>{};
    if (previous.status == 'completed') {
      for (final item in previous.items) {
        changes.update(
          item.productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    if (updated.status == 'completed') {
      for (final item in updated.items) {
        changes.update(
          item.productId,
          (quantity) => quantity - item.quantity,
          ifAbsent: () => -item.quantity,
        );
      }
    }
    for (final entry in changes.entries) {
      if (entry.value.abs() < 0.000001) continue;
      await _inventory.recordStockChange(
        transaction,
        productId: entry.key,
        quantity: entry.value,
        reason: 'sale_adjustment',
        date: updated.date,
        sourceType: 'sale',
        sourceId: updated.id,
      );
    }
  }

  void _validateItems(Sale sale) {
    if (sale.items.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }
    if (sale.items.any((item) => item.saleId != sale.id)) {
      throw ArgumentError('Every sale item must reference this sale.');
    }
  }
}

class _SaleRow implements DatabaseEntity {
  _SaleRow(this.values);

  final Map<String, Object?> values;

  @override
  String get id => requiredString(values, 'id');

  @override
  Map<String, Object?> toMap() => Map.of(values);

  factory _SaleRow.fromMap(Map<String, Object?> map) => _SaleRow(Map.of(map));
}
