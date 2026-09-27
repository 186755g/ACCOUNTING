import 'model_utils.dart';
import 'sale_item.dart';

class Sale implements DatabaseEntity {
  Sale({
    String? id,
    this.customerId,
    this.userId,
    required List<SaleItem> items,
    this.orderDiscountMinor = 0,
    this.status = 'completed',
    this.notes,
    DateTime? date,
  })  : id = id ?? newModelId(),
        items = List.unmodifiable(items),
        date = (date ?? DateTime.now()).toUtc() {
    if (items.isEmpty) throw ArgumentError('A sale must contain at least one item.');
    if (items.any((item) => item.saleId != this.id)) {
      throw ArgumentError('Every sale item must reference this sale.');
    }
    if (orderDiscountMinor < 0 || orderDiscountMinor > itemsTotalMinor) {
      throw ArgumentError.value(orderDiscountMinor, 'orderDiscountMinor');
    }
  }

  @override
  final String id;
  final String? customerId;
  final String? userId;
  final List<SaleItem> items;
  final int orderDiscountMinor;
  final String status;
  final String? notes;
  final DateTime date;

  int get subtotalMinor => items.fold(0, (sum, item) => sum + item.subtotalMinor);
  int get lineDiscountMinor =>
      items.fold(0, (sum, item) => sum + item.discountMinor);
  int get itemsTotalMinor => items.fold(0, (sum, item) => sum + item.totalMinor);
  int get totalDiscountMinor => lineDiscountMinor + orderDiscountMinor;
  int get totalMinor => itemsTotalMinor - orderDiscountMinor;
  int get costTotalMinor =>
      items.fold(0, (sum, item) => sum + item.costTotalMinor);
  int get grossProfitMinor => totalMinor - costTotalMinor;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'user_id': userId,
        'date_at': dateToDatabase(date),
        'subtotal_minor': subtotalMinor,
        'discount_minor': totalDiscountMinor,
        'total_minor': totalMinor,
        'order_discount_minor': orderDiscountMinor,
        'status': status,
        'notes': notes,
      };

  factory Sale.fromMap(
    Map<String, Object?> map, {
    required List<SaleItem> items,
  }) {
    final loadedItems = List<SaleItem>.unmodifiable(items);
    final subtotal = requiredInt(map, 'subtotal_minor');
    final discount = requiredInt(map, 'discount_minor');
    final total = requiredInt(map, 'total_minor');
    final orderDiscount = requiredInt(map, 'order_discount_minor');
    if (loadedItems.isNotEmpty) {
      final computedSubtotal =
          loadedItems.fold(0, (sum, item) => sum + item.subtotalMinor);
      final computedDiscount =
          loadedItems.fold(0, (sum, item) => sum + item.discountMinor) +
              orderDiscount;
      final computedTotal =
          loadedItems.fold(0, (sum, item) => sum + item.totalMinor) -
              orderDiscount;
      if (subtotal != computedSubtotal ||
          discount != computedDiscount ||
          total != computedTotal) {
        throw FormatException('Stored sale totals do not match its sale items.');
      }
    }
    return Sale(
      id: requiredString(map, 'id'),
      customerId: nullableString(map, 'customer_id'),
      userId: nullableString(map, 'user_id'),
      items: loadedItems,
      orderDiscountMinor: orderDiscount,
      status: requiredString(map, 'status'),
      notes: nullableString(map, 'notes'),
      date: dateFromDatabase(map['date_at']),
    );
  }
}
