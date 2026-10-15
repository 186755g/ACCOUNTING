import 'package:sqflite/sqflite.dart';

import 'models/inventory_movement.dart';
import 'models/model_utils.dart';

bool _matchesInventoryMovementPayload(
  Map<String, Object?> existing,
  Map<String, Object?> candidate,
) =>
    movementPayloadsMatch(existing, candidate);

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
    required int refundMinor,
    String? note,
    DateTime? date,
  }) async {
    _validateMovement(quantity, 'sale_return');
    if (refundMinor < 0) {
      throw ArgumentError.value(refundMinor, 'refundMinor');
    }
    final returnedAt = (date ?? DateTime.now()).toUtc();
    final productReturn = await _database.transaction((transaction) async {
      final items = await transaction.rawQuery(
        '''
        SELECT si.sale_id, si.product_id, si.quantity, si.cost_price_minor,
          s.status
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
        'SELECT COALESCE(SUM(quantity), 0) AS quantity, '
        'COALESCE(SUM(returned_cost_minor), 0) AS returned_cost '
        'FROM product_returns WHERE sale_item_id = ?',
        [saleItemId],
      );
      final alreadyReturned = requiredDouble(
        existingReturns.single,
        'quantity',
      );
      final returnedCostMinor = requiredInt(
        existingReturns.single,
        'returned_cost',
      );
      if (alreadyReturned + quantity > soldQuantity + 0.000001) {
        throw StateError('Return quantity exceeds the unreturned quantity.');
      }
      final saleTotals = await transaction.rawQuery(
        '''
        SELECT s.total_minor,
          COALESCE((
            SELECT SUM(pr.refund_minor) FROM product_returns pr
            WHERE pr.sale_id = s.id
          ), 0) AS refunded_minor
        FROM sales s WHERE s.id = ?
        ''',
        [saleId],
      );
      final saleTotal = requiredInt(saleTotals.single, 'total_minor');
      final refundedMinor = requiredInt(saleTotals.single, 'refunded_minor');
      if (refundedMinor + refundMinor > saleTotal) {
        throw StateError('Refund total cannot exceed the original sale total.');
      }
      final costPriceMinor = requiredInt(item, 'cost_price_minor');
      final newReturnedCostMinor =
          ((alreadyReturned + quantity) * costPriceMinor).round() -
          returnedCostMinor;

      final result = ProductReturn(
        saleId: saleId,
        saleItemId: saleItemId,
        productId: productId,
        quantity: quantity,
        refundMinor: refundMinor,
        returnedCostMinor: newReturnedCostMinor,
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
    final normalizedNewQuantity = newQuantity.abs() < 0.000001
        ? 0.0
        : newQuantity;
    final normalizedSourceType = (sourceType ?? '').trim();
    final normalizedSourceId = (sourceId ?? '').trim();
    if (normalizedSourceType.isNotEmpty && normalizedSourceId.isNotEmpty) {
      final duplicates = await transaction.query(
        'inventory_history',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: [normalizedSourceType, normalizedSourceId],
        limit: 1,
      );
      if (duplicates.isNotEmpty) {
        final existing = InventoryMovement.fromMap(duplicates.single);
        final candidate = InventoryMovement(
          id: newModelId(),
          productId: productId,
          productName: requiredString(product, 'name'),
          reason: reason.trim(),
          quantity: normalizedNewQuantity - previousQuantity,
          previousQuantity: previousQuantity,
          newQuantity: normalizedNewQuantity,
          date: date.toUtc(),
          note: _cleanNote(note),
          sourceType: normalizedSourceType,
          sourceId: normalizedSourceId,
        );
        if (_matchesInventoryMovementPayload(existing.toMap(), candidate.toMap())) {
          return;
        }
        throw MovementIdentityConflictException(
          kind: 'inventory movement',
          sourceType: normalizedSourceType,
          sourceId: normalizedSourceId,
          existingSummary: '${existing.productId}:${existing.reason}:${existing.quantity}',
          requestSummary: '$productId:${reason.trim()}:${normalizedNewQuantity - previousQuantity}',
        );
      }
    }
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
      sourceType: normalizedSourceType.isEmpty ? null : normalizedSourceType,
      sourceId: normalizedSourceId.isEmpty ? null : normalizedSourceId,
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
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Must be finite and non-zero.',
      );
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
