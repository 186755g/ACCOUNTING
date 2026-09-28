import 'package:sqflite/sqflite.dart';

import 'models/product.dart';
import 'inventory_repository.dart';
import 'sqlite_entity_repository.dart';

enum ProductSortField { name, stock, purchasePrice, sellingPrice, createdDate }

class ProductRepository {
  ProductRepository(Database database)
    : _database = database,
      _inventory = InventoryRepository(database),
      _repository = SqliteEntityRepository<Product>(
        database,
        table: 'products',
        fromMap: Product.fromMap,
        searchableColumns: const ['name', 'sku', 'barcode', 'description'],
        filterableColumns: const {
          'id',
          'category_id',
          'sku',
          'barcode',
          'is_active',
          'stock_quantity',
          'cost_price_minor',
          'selling_price_minor',
        },
        dateColumn: 'created_at',
      );

  final Database _database;
  final InventoryRepository _inventory;
  final SqliteEntityRepository<Product> _repository;

  Future<void> create(Product product) => _database.transaction((transaction) async {
    final values = product.toMap()..['stock_quantity'] = 0.0;
    await transaction.insert(
      'products',
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    if (product.stockQuantity != 0) {
      await _inventory.recordStockChange(
        transaction,
        productId: product.id,
        quantity: product.stockQuantity,
        reason: 'opening_stock',
        date: product.createdAt,
        sourceType: 'product',
        sourceId: product.id,
      );
    }
  });

  Future<Product?> getById(String id) => _repository.getById(id);

  Future<void> update(Product product) => _database.transaction((transaction) async {
    final rows = await transaction.query(
      'products',
      columns: ['stock_quantity'],
      where: 'id = ?',
      whereArgs: [product.id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Cannot update missing products record "${product.id}".');
    }
    final previousQuantity = (rows.single['stock_quantity'] as num).toDouble();
    final values = product.toMap()..['stock_quantity'] = previousQuantity;
    await transaction.update(
      'products',
      values,
      where: 'id = ?',
      whereArgs: [product.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final quantityChange = product.stockQuantity - previousQuantity;
    if (quantityChange != 0) {
      await _inventory.recordStockChange(
        transaction,
        productId: product.id,
        quantity: quantityChange,
        reason: 'manual_adjustment',
        note: 'Stock changed while editing product.',
        date: product.updatedAt,
        sourceType: 'product',
        sourceId: product.id,
      );
    }
  });

  Future<bool> delete(String id) => _repository.delete(id);

  Future<List<Product>> getAll({
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) => _repository.getAll(
    filters: filters,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );

  Future<List<Product>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
    String orderBy = 'id',
    bool descending = false,
  }) => _repository.search(
    query,
    filters: filters,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );

  Future<List<Product>> browse({
    String query = '',
    String? categoryId,
    bool lowStockOnly = false,
    bool activeOnly = false,
    ProductSortField sortBy = ProductSortField.name,
    bool descending = false,
  }) async {
    final clauses = <String>[];
    final arguments = <Object?>[];
    if (categoryId != null) {
      clauses.add('category_id = ?');
      arguments.add(categoryId);
    }
    if (lowStockOnly) {
      clauses.add('stock_quantity <= minimum_stock');
    }
    if (activeOnly) {
      clauses.add('is_active = 1');
    }
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      final escapedQuery = normalizedQuery
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      clauses.add('''
        (name LIKE ? ESCAPE '\\' COLLATE NOCASE
        OR COALESCE(sku, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
        OR COALESCE(barcode, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
        OR COALESCE(description, '') LIKE ? ESCAPE '\\' COLLATE NOCASE)
      ''');
      arguments.addAll(List.filled(4, '%$escapedQuery%'));
    }

    final orderColumn = switch (sortBy) {
      ProductSortField.name => 'name COLLATE NOCASE',
      ProductSortField.stock => 'stock_quantity',
      ProductSortField.purchasePrice => 'cost_price_minor',
      ProductSortField.sellingPrice => 'selling_price_minor',
      ProductSortField.createdDate => 'created_at',
    };
    final rows = await _database.query(
      'products',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: '$orderColumn ${descending ? 'DESC' : 'ASC'}, id ASC',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }
}
