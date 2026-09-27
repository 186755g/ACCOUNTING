import 'model_utils.dart';
import 'purchase_item.dart';

class Purchase implements DatabaseEntity {
  Purchase({
    String? id,
    this.supplierId,
    this.userId,
    required List<PurchaseItem> items,
    this.orderDiscountMinor = 0,
    this.status = 'received',
    this.notes,
    DateTime? date,
  }) : id = id ?? newModelId(),
       items = List.unmodifiable(items),
       date = (date ?? DateTime.now()).toUtc() {
    if (items.isEmpty) {
      throw ArgumentError('A purchase must contain at least one item.');
    }
    if (items.any((item) => item.purchaseId != this.id)) {
      throw ArgumentError('Every purchase item must reference this purchase.');
    }
    if (orderDiscountMinor < 0 || orderDiscountMinor > itemsTotalMinor) {
      throw ArgumentError.value(orderDiscountMinor, 'orderDiscountMinor');
    }
  }

  @override
  final String id;
  final String? supplierId;
  final String? userId;
  final List<PurchaseItem> items;
  final int orderDiscountMinor;
  final String status;
  final String? notes;
  final DateTime date;

  int get subtotalMinor => items.fold(
    0,
    (sum, item) => sum + (item.quantity * item.costPriceMinor).round(),
  );
  int get lineDiscountMinor =>
      items.fold(0, (sum, item) => sum + item.discountMinor);
  int get itemsTotalMinor =>
      items.fold(0, (sum, item) => sum + item.totalMinor);
  int get totalDiscountMinor => lineDiscountMinor + orderDiscountMinor;
  int get totalMinor => itemsTotalMinor - orderDiscountMinor;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'supplier_id': supplierId,
    'user_id': userId,
    'date_at': dateToDatabase(date),
    'subtotal_minor': subtotalMinor,
    'discount_minor': totalDiscountMinor,
    'total_minor': totalMinor,
    'order_discount_minor': orderDiscountMinor,
    'status': status,
    'notes': notes,
  };

  factory Purchase.fromMap(
    Map<String, Object?> map, {
    required List<PurchaseItem> items,
  }) {
    final loadedItems = List<PurchaseItem>.unmodifiable(items);
    final subtotal = requiredInt(map, 'subtotal_minor');
    final discount = requiredInt(map, 'discount_minor');
    final total = requiredInt(map, 'total_minor');
    final orderDiscount = requiredInt(map, 'order_discount_minor');
    if (loadedItems.isNotEmpty) {
      final computedSubtotal = loadedItems.fold(
        0,
        (sum, item) => sum + (item.quantity * item.costPriceMinor).round(),
      );
      final computedDiscount =
          loadedItems.fold(0, (sum, item) => sum + item.discountMinor) +
          orderDiscount;
      final computedTotal =
          loadedItems.fold(0, (sum, item) => sum + item.totalMinor) -
          orderDiscount;
      if (subtotal != computedSubtotal ||
          discount != computedDiscount ||
          total != computedTotal) {
        throw FormatException(
          'Stored purchase totals do not match its purchase items.',
        );
      }
    }
    return Purchase(
      id: requiredString(map, 'id'),
      supplierId: nullableString(map, 'supplier_id'),
      userId: nullableString(map, 'user_id'),
      items: loadedItems,
      orderDiscountMinor: orderDiscount,
      status: requiredString(map, 'status'),
      notes: nullableString(map, 'notes'),
      date: dateFromDatabase(map['date_at']),
    );
  }
}
