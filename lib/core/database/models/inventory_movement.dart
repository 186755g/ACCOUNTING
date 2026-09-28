import 'model_utils.dart';

class InventoryMovement implements DatabaseEntity {
  InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reason,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.date,
    this.note,
    this.sourceType,
    this.sourceId,
  }) {
    if (quantity == 0 ||
        !quantity.isFinite ||
        !previousQuantity.isFinite ||
        !newQuantity.isFinite ||
        (previousQuantity + quantity - newQuantity).abs() > 0.000001) {
      throw ArgumentError('Inventory movement quantities are inconsistent.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason');
    }
  }

  @override
  final String id;
  final String productId;
  final String productName;
  final String reason;
  final double quantity;
  final double previousQuantity;
  final double newQuantity;
  final DateTime date;
  final String? note;
  final String? sourceType;
  final String? sourceId;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'reason': reason,
    'quantity': quantity,
    'previous_quantity': previousQuantity,
    'new_quantity': newQuantity,
    'date_at': dateToDatabase(date),
    'note': note,
    'source_type': sourceType,
    'source_id': sourceId,
  };

  factory InventoryMovement.fromMap(Map<String, Object?> map) =>
      InventoryMovement(
        id: requiredString(map, 'id'),
        productId: requiredString(map, 'product_id'),
        productName: requiredString(map, 'product_name'),
        reason: requiredString(map, 'reason'),
        quantity: requiredDouble(map, 'quantity'),
        previousQuantity: requiredDouble(map, 'previous_quantity'),
        newQuantity: requiredDouble(map, 'new_quantity'),
        date: dateFromDatabase(map['date_at']),
        note: nullableString(map, 'note'),
        sourceType: nullableString(map, 'source_type'),
        sourceId: nullableString(map, 'source_id'),
      );
}

class ProductReturn implements DatabaseEntity {
  ProductReturn({
    String? id,
    required this.saleId,
    required this.saleItemId,
    required this.productId,
    required this.quantity,
    DateTime? date,
    this.note,
  }) : id = id ?? newModelId(),
       date = (date ?? DateTime.now()).toUtc() {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity');
    }
  }

  @override
  final String id;
  final String saleId;
  final String saleItemId;
  final String productId;
  final double quantity;
  final DateTime date;
  final String? note;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'sale_id': saleId,
    'sale_item_id': saleItemId,
    'product_id': productId,
    'quantity': quantity,
    'date_at': dateToDatabase(date),
    'note': note,
  };

  factory ProductReturn.fromMap(Map<String, Object?> map) => ProductReturn(
    id: requiredString(map, 'id'),
    saleId: requiredString(map, 'sale_id'),
    saleItemId: requiredString(map, 'sale_item_id'),
    productId: requiredString(map, 'product_id'),
    quantity: requiredDouble(map, 'quantity'),
    date: dateFromDatabase(map['date_at']),
    note: nullableString(map, 'note'),
  );
}
