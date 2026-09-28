import 'model_utils.dart';

class Product implements DatabaseEntity {
  Product({
    String? id,
    this.categoryId,
    this.sku,
    this.barcode,
    required this.name,
    this.description,
    this.imagePath,
    this.unit = 'piece',
    required this.costPriceMinor,
    required this.sellingPriceMinor,
    this.stockQuantity = 0,
    double lowStockThreshold = 0,
    double? minimumStock,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? newModelId(),
       lowStockThreshold = minimumStock ?? lowStockThreshold,
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    if (unit.trim().isEmpty) throw ArgumentError.value(unit, 'unit');
    if (costPriceMinor < 0) {
      throw ArgumentError.value(costPriceMinor, 'costPriceMinor');
    }
    if (sellingPriceMinor < 0) {
      throw ArgumentError.value(sellingPriceMinor, 'sellingPriceMinor');
    }
    if (!stockQuantity.isFinite) {
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
  final String? barcode;
  final String name;
  final String? description;
  final String? imagePath;
  final String unit;
  final int costPriceMinor;
  final int sellingPriceMinor;
  final double stockQuantity;
  final double lowStockThreshold;
  double get minimumStock => lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'category_id': categoryId,
    'sku': sku,
    'barcode': barcode,
    'name': name.trim(),
    'description': description,
    'image_path': imagePath,
    'unit': unit.trim(),
    'cost_price_minor': costPriceMinor,
    'selling_price_minor': sellingPriceMinor,
    'stock_quantity': stockQuantity,
    'low_stock_threshold': lowStockThreshold,
    'minimum_stock': lowStockThreshold,
    'is_active': isActive ? 1 : 0,
    'created_at': dateToDatabase(createdAt),
    'updated_at': dateToDatabase(updatedAt),
  };

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: requiredString(map, 'id'),
    categoryId: nullableString(map, 'category_id'),
    sku: nullableString(map, 'sku'),
    barcode: nullableString(map, 'barcode'),
    name: requiredString(map, 'name'),
    description: nullableString(map, 'description'),
    imagePath: nullableString(map, 'image_path'),
    unit: map['unit'] is String ? map['unit']! as String : 'piece',
    costPriceMinor: requiredInt(map, 'cost_price_minor'),
    sellingPriceMinor: requiredInt(map, 'selling_price_minor'),
    stockQuantity: requiredDouble(map, 'stock_quantity'),
    minimumStock: map['minimum_stock'] is num
        ? (map['minimum_stock']! as num).toDouble()
        : requiredDouble(map, 'low_stock_threshold'),
    isActive: requiredBool(map, 'is_active'),
    createdAt: dateFromDatabase(map['created_at']),
    updatedAt: dateFromDatabase(map['updated_at']),
  );
}
