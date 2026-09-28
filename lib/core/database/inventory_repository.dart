import 'package:sqflite/sqflite.dart';

import 'models/inventory_movement.dart';
import 'models/model_utils.dart';

class InventoryRepository {
  InventoryRepository(this._database);

  final Database _database;

  Future<void> adjustStock({
    required String productId,
    required double quantity,
    required String reason,
    String? note,
    DateTime? date,
  }) async {
    _validateMovement(quantity, reason);
    await _database.transaction((transaction) async {
      await recordStockChange(
        transaction,
        productId: productId,
        quantity: quantity,
        reason: reason.trim(),
        note: _cleanNote(note),
        date: (date ?? DateTime.now()).toUtc(),
        sourceType: 'adjustment',
      );
    });
  }

  Future<List<InventoryMovement>> getHistory({
    String? productId,
    int? limit,
    int offset = 0,
  }) async {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit');
    }
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final rows = await _database.query(
      'inventory_history',
      where: productId == null ? null : 'product_id = ?',
      whereArgs: productId == null ? null : [productId],
      orderBy: 'date_at DESC, rowid DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(InventoryMovement.fromMap).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> getLowStockProducts() => _database.query(
    'products',
    where: 'is_active = 1 AND stock_quantity > 0 AND stock_quantity <= minimum_stock',
    orderBy: 'stock_quantity ASC, name COLLATE NOCASE ASC',
  );

  Future<List<Map<String, Object?>>> getOutOfStockProducts() => _database.query(
    'products',
    where: 'is_active = 1 AND stock_quantity <= 0',
    orderBy: 'name COLLATE NOCASE ASC',
  );

  Future<List<ProductReturn>> getReturns({
    String? saleId,
    int? limit,
    int offset = 0,
  }) async {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit');
    }
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final rows = await _database.query(
      'product_returns',
      where: saleId == null ? null : 'sale_id = ?',
      whereArgs: saleId == null ? null : [saleId],
      orderBy: 'date_at DESC, rowid DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ProductReturn.fromMap).toList(growable: false);
  }

  Future<ProductReturn> returnSaleItem({
    required String saleItemId,
    required double quantity,
    String? note,
    DateTime? date,
  }) async {
    _validateMovement(quantity, 'sale_return');
    final returnedAt = (date ?? DateTime.now()).toUtc();
    final productReturn = await _database.transaction((transaction) async {
      final items = await transaction.rawQuery(
        '''
        SELECT si.sale_id, si.product_id, si.quantity, s.status
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE si.id = ?
        ''',
        [saleItemId],
      );
      if (items.isEmpty) {
        throw StateError('Cannot return a missing sale item.');
      }
      final item = items.single;
      if (item['status'] != 'completed') {
        throw StateError('Only completed sales can be returned.');
      }
      final saleId = requiredString(item, 'sale_id');
      final productId = requiredString(item, 'product_id');
      final soldQuantity = requiredDouble(item, 'quantity');
      final existingReturns = await transaction.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS quantity '
        'FROM product_returns WHERE sale_item_id = ?',
        [saleItemId],
      );
      final alreadyReturned = requiredDouble(
        existingReturns.single,
        'quantity',
      );
      if (alreadyReturned + quantity > soldQuantity + 0.000001) {
        throw StateError('Return quantity exceeds the unreturned quantity.');
      }

      final result = ProductReturn(
        saleId: saleId,
        saleItemId: saleItemId,
        productId: productId,
        quantity: quantity,
        date: returnedAt,
        note: _cleanNote(note),
      );
      await transaction.insert(
        'product_returns',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await recordStockChange(
        transaction,
        productId: productId,
        quantity: quantity,
        reason: 'sale_return',
        note: _cleanNote(note),
        date: returnedAt,
        sourceType: 'return',
        sourceId: result.id,
      );
      return result;
    });
    return productReturn;
  }

  Future<void> recordStockChange(
    Transaction transaction, {
    required String productId,
    required double quantity,
    required String reason,
    required DateTime date,
    String? note,
    String? sourceType,
    String? sourceId,
  }) async {
    _validateMovement(quantity, reason);
    final products = await transaction.query(
      'products',
      columns: ['name', 'stock_quantity'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (products.isEmpty) {
      throw StateError('Cannot change stock for a missing product.');
    }
    final product = products.single;
    final previousQuantity = requiredDouble(product, 'stock_quantity');
    final newQuantity = previousQuantity + quantity;
    if (!newQuantity.isFinite) {
      throw ArgumentError('Stock quantity must be finite.');
    }
    if (newQuantity < -0.000001 && !await _negativeStockAllowed(transaction)) {
      throw StateError(
        'Insufficient stock: this operation would make inventory negative.',
      );
    }
    final normalizedNewQuantity =
        newQuantity.abs() < 0.000001 ? 0.0 : newQuantity;
    await transaction.update(
      'products',
      {
        'stock_quantity': normalizedNewQuantity,
        'updated_at': dateToDatabase(date),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
    final movement = InventoryMovement(
      id: newModelId(),
      productId: productId,
      productName: requiredString(product, 'name'),
      reason: reason.trim(),
      quantity: normalizedNewQuantity - previousQuantity,
      previousQuantity: previousQuantity,
      newQuantity: normalizedNewQuantity,
      date: date.toUtc(),
      note: _cleanNote(note),
      sourceType: sourceType,
      sourceId: sourceId,
    );
    await transaction.insert(
      'inventory_history',
      movement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<bool> _negativeStockAllowed(Transaction transaction) async {
    final rows = await transaction.query(
      'app_settings',
      columns: ['allow_negative_stock'],
      where: "id = '1'",
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['allow_negative_stock'] == 1;
  }

  static void _validateMovement(double quantity, String reason) {
    if (!quantity.isFinite || quantity == 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be finite and non-zero.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be empty.');
    }
  }

  static String? _cleanNote(String? note) {
    final normalized = note?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
