import 'model_utils.dart';

class Product implements DatabaseEntity {
  Product({
    String? id,
    this.categoryId,
    this.sku,
    required this.name,
    this.description,
    required this.costPriceMinor,
    required this.sellingPriceMinor,
    this.stockQuantity = 0,
    this.lowStockThreshold = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newModelId(),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (costPriceMinor < 0) {
      throw ArgumentError.value(costPriceMinor, 'costPriceMinor');
    }
    if (sellingPriceMinor < 0) {
      throw ArgumentError.value(sellingPriceMinor, 'sellingPriceMinor');
    }
    if (!stockQuantity.isFinite || stockQuantity < 0) {
      throw ArgumentError.value(stockQuantity, 'stockQuantity');
    }
    if (!lowStockThreshold.isFinite || lowStockThreshold < 0) {
      throw ArgumentError.value(lowStockThreshold, 'lowStockThreshold');
    }
  }

  @override
  final String id;
  final String? categoryId;
  final String? sku;
  final String name;
  final String? description;
  final int costPriceMinor;
  final int sellingPriceMinor;
  final double stockQuantity;
  final double lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'category_id': categoryId,
        'sku': sku,
        'name': name.trim(),
        'description': description,
        'cost_price_minor': costPriceMinor,
        'selling_price_minor': sellingPriceMinor,
        'stock_quantity': stockQuantity,
        'low_stock_threshold': lowStockThreshold,
        'is_active': isActive ? 1 : 0,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: requiredString(map, 'id'),
        categoryId: nullableString(map, 'category_id'),
        sku: nullableString(map, 'sku'),
        name: requiredString(map, 'name'),
        description: nullableString(map, 'description'),
        costPriceMinor: requiredInt(map, 'cost_price_minor'),
        sellingPriceMinor: requiredInt(map, 'selling_price_minor'),
        stockQuantity: requiredDouble(map, 'stock_quantity'),
        lowStockThreshold: requiredDouble(map, 'low_stock_threshold'),
        isActive: requiredBool(map, 'is_active'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
