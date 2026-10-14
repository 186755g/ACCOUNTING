import 'package:sqflite/sqflite.dart';

import 'models/model_utils.dart';
import 'models/product.dart';
import 'inventory_repository.dart';
import 'sqlite_entity_repository.dart';
import 'sync_outbox_repository.dart';
import '../services/installation_identity_store.dart';

enum ProductSortField { name, stock, purchasePrice, sellingPrice, createdDate }

class ProductRepository {
  ProductRepository(
    Database database, {
    required InstallationIdentityStore installationIdentity,
    required SyncOutboxRepository outbox,
  }) : _database = database,
       _installationIdentity = installationIdentity,
       _outbox = outbox,
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
  final InstallationIdentityStore _installationIdentity;
  final SyncOutboxRepository _outbox;
  final InventoryRepository _inventory;
  final SqliteEntityRepository<Product> _repository;

  Future<void> create(Product product) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
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
      if (installationId != null) {
        final payload = <String, Object?>{
          'id': product.id,
          'category_id': product.categoryId,
          'sku': product.sku,
          'barcode': product.barcode,
          'name': product.name,
          'description': product.description,
          'unit': product.unit,
          'cost_price_minor': product.costPriceMinor,
          'selling_price_minor': product.sellingPriceMinor,
          'stock_quantity': product.stockQuantity,
          'low_stock_threshold': product.lowStockThreshold,
          'minimum_stock': product.minimumStock,
          'is_active': product.isActive ? 1 : 0,
          'created_at': dateToDatabase(product.createdAt),
          'updated_at': dateToDatabase(product.updatedAt),
        };
        await _outbox.recordProductChange(
          transaction,
          installationId: installationId,
          productId: product.id,
          operation: 'create',
          payload: payload,
        );
      }
    });
  }

  Future<Product?> getById(String id) => _repository.getById(id);

  Future<void> update(Product product) async {
    final installationId = await _installationIdentity.getOrCreateSafe();
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'products',
        columns: [
          'id',
          'category_id',
          'sku',
          'barcode',
          'name',
          'description',
          'image_path',
          'unit',
          'cost_price_minor',
          'selling_price_minor',
          'stock_quantity',
          'low_stock_threshold',
          'minimum_stock',
          'is_active',
          'created_at',
          'updated_at',
        ],
        where: 'id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError(
          'Cannot update missing products record "${product.id}".',
        );
      }

      final previousQuantity = (rows.single['stock_quantity'] as num).toDouble();
      final previousSnapshot = {
        'id': rows.single['id'],
        'category_id': rows.single['category_id'],
        'sku': rows.single['sku'],
        'barcode': rows.single['barcode'],
        'name': rows.single['name'],
        'description': rows.single['description'],
        'unit': rows.single['unit'],
        'cost_price_minor': rows.single['cost_price_minor'],
        'selling_price_minor': rows.single['selling_price_minor'],
        'stock_quantity': previousQuantity,
        'low_stock_threshold': rows.single['low_stock_threshold'],
        'minimum_stock': rows.single['minimum_stock'],
        'is_active': rows.single['is_active'],
        'created_at': rows.single['created_at'],
        'updated_at': rows.single['updated_at'],
      };

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

      final hasMeaningfulProductChange = previousSnapshot['category_id'] != product.categoryId ||
          previousSnapshot['sku'] != product.sku ||
          previousSnapshot['barcode'] != product.barcode ||
          previousSnapshot['name'] != product.name ||
          previousSnapshot['description'] != product.description ||
          previousSnapshot['unit'] != product.unit ||
          previousSnapshot['cost_price_minor'] != product.costPriceMinor ||
          previousSnapshot['selling_price_minor'] != product.sellingPriceMinor ||
          previousSnapshot['low_stock_threshold'] != product.lowStockThreshold ||
          previousSnapshot['minimum_stock'] != product.minimumStock ||
          previousSnapshot['is_active'] != (product.isActive ? 1 : 0);

      if (installationId != null && hasMeaningfulProductChange) {
        final payload = <String, Object?>{
          'id': product.id,
          'category_id': product.categoryId,
          'sku': product.sku,
          'barcode': product.barcode,
          'name': product.name,
          'description': product.description,
          'unit': product.unit,
          'cost_price_minor': product.costPriceMinor,
          'selling_price_minor': product.sellingPriceMinor,
          'stock_quantity': product.stockQuantity,
          'low_stock_threshold': product.lowStockThreshold,
          'minimum_stock': product.minimumStock,
          'is_active': product.isActive ? 1 : 0,
          'created_at': dateToDatabase(product.createdAt),
          'updated_at': dateToDatabase(product.updatedAt),
        };
        await _outbox.recordProductChange(
          transaction,
          installationId: installationId,
          productId: product.id,
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
        'products',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final deleted = await transaction.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (deleted == 0) return false;
      if (installationId != null) {
        final payload = <String, Object?>{
          'id': rows.single['id'],
          'category_id': rows.single['category_id'],
          'sku': rows.single['sku'],
          'barcode': rows.single['barcode'],
          'name': rows.single['name'],
          'description': rows.single['description'],
          'unit': rows.single['unit'],
          'cost_price_minor': rows.single['cost_price_minor'],
          'selling_price_minor': rows.single['selling_price_minor'],
          'stock_quantity': rows.single['stock_quantity'],
          'low_stock_threshold': rows.single['low_stock_threshold'],
          'minimum_stock': rows.single['minimum_stock'],
          'is_active': rows.single['is_active'],
          'created_at': rows.single['created_at'],
          'updated_at': rows.single['updated_at'],
        };
        await _outbox.recordProductChange(
          transaction,
          installationId: installationId,
          productId: id,
          operation: 'delete',
          payload: payload,
        );
      }
      return true;
    });
  }

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
    int? limit,
    int offset = 0,
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
      limit: limit,
      offset: offset,
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }
}
