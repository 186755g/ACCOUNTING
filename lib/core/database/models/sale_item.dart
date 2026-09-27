import 'model_utils.dart';

class SaleItem implements DatabaseEntity {
  SaleItem({
    String? id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.sellingPriceMinor,
    required this.costPriceMinor,
    this.discountMinor = 0,
  }) : id = id ?? newModelId() {
    if (productName.trim().isEmpty) {
      throw ArgumentError.value(productName, 'productName');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    if (sellingPriceMinor < 0 || costPriceMinor < 0 || discountMinor < 0) {
      throw ArgumentError('Sale item prices and discount must be non-negative.');
    }
    if (discountMinor > (quantity * sellingPriceMinor).round()) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }
  }

  @override
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final int sellingPriceMinor;
  final int costPriceMinor;
  final int discountMinor;

  int get subtotalMinor => (quantity * sellingPriceMinor).round();
  int get totalMinor => (quantity * sellingPriceMinor).round() - discountMinor;
  int get costTotalMinor => (quantity * costPriceMinor).round();
  int get grossProfitMinor => totalMinor - costTotalMinor;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'product_name': productName.trim(),
        'quantity': quantity,
        'selling_price_minor': sellingPriceMinor,
        'cost_price_minor': costPriceMinor,
        'discount_minor': discountMinor,
        'total_minor': totalMinor,
      };

  factory SaleItem.fromMap(Map<String, Object?> map) => SaleItem(
        id: requiredString(map, 'id'),
        saleId: requiredString(map, 'sale_id'),
        productId: requiredString(map, 'product_id'),
        productName: requiredString(map, 'product_name'),
        quantity: requiredDouble(map, 'quantity'),
        sellingPriceMinor: requiredInt(map, 'selling_price_minor'),
        costPriceMinor: requiredInt(map, 'cost_price_minor'),
        discountMinor: requiredInt(map, 'discount_minor'),
      );
}
