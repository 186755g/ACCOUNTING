import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';
import 'models/sale.dart';
import 'models/sale_item.dart';
import 'sqlite_entity_repository.dart';

class SaleRepository {
  SaleRepository(Database database)
      : _database = database,
        _sales = SqliteEntityRepository<_SaleRow>(
          database,
          table: 'sales',
          fromMap: _SaleRow.fromMap,
          searchableColumns: const ['id', 'status', 'notes'],
          filterableColumns: const {
            'id',
            'customer_id',
            'user_id',
            'status',
          },
          dateColumn: 'date_at',
        );

  final Database _database;
  final SqliteEntityRepository<_SaleRow> _sales;

  Future<void> create(Sale sale) => _database.transaction((transaction) async {
        _validateItems(sale);
        await _sales.create(_SaleRow(sale.toMap()), transaction: transaction);
        for (final item in sale.items) {
          await transaction.insert(
            'sale_items',
            item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      });

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
        await _sales.update(
          _SaleRow(sale.toMap()),
          transaction: transaction,
        );
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
      });

  Future<bool> delete(String id) => _sales.delete(id);

  Future<Sale> _hydrate(Map<String, Object?> row) async {
    final saleId = requiredString(row, 'id');
    final rows = await _database.query(
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

  factory _SaleRow.fromMap(Map<String, Object?> map) =>
      _SaleRow(Map.of(map));
}
