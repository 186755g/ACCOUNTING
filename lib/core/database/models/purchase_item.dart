import 'model_utils.dart';

class PurchaseItem implements DatabaseEntity {
  PurchaseItem({
    String? id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPriceMinor,
    this.discountMinor = 0,
  }) : id = id ?? newModelId() {
    if (productName.trim().isEmpty) {
      throw ArgumentError.value(productName, 'productName');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    if (costPriceMinor < 0 || discountMinor < 0) {
      throw ArgumentError('Purchase item prices and discount must be non-negative.');
    }
    if (discountMinor > (quantity * costPriceMinor).round()) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }
  }

  @override
  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final double quantity;
  final int costPriceMinor;
  final int discountMinor;

  int get totalMinor => (quantity * costPriceMinor).round() - discountMinor;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'product_name': productName.trim(),
        'quantity': quantity,
        'cost_price_minor': costPriceMinor,
        'discount_minor': discountMinor,
        'total_minor': totalMinor,
      };

  factory PurchaseItem.fromMap(Map<String, Object?> map) => PurchaseItem(
        id: requiredString(map, 'id'),
        purchaseId: requiredString(map, 'purchase_id'),
        productId: requiredString(map, 'product_id'),
        productName: requiredString(map, 'product_name'),
        quantity: requiredDouble(map, 'quantity'),
        costPriceMinor: requiredInt(map, 'cost_price_minor'),
        discountMinor: requiredInt(map, 'discount_minor'),
      );
}
