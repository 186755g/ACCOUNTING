import 'model_utils.dart';

enum DebtDirection { receivable, payable }

class Debt implements DatabaseEntity {
  Debt({
    String? id,
    this.customerId,
    this.supplierId,
    this.saleId,
    this.purchaseId,
    required this.direction,
    required this.amountMinor,
    required this.dueDate,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newModelId(),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if ((customerId == null) == (supplierId == null)) {
      throw ArgumentError('A debt must belong to exactly one customer or supplier.');
    }
    if (direction == DebtDirection.receivable && customerId == null ||
        direction == DebtDirection.payable && supplierId == null) {
      throw ArgumentError('Debt direction must match its customer or supplier.');
    }
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    if (saleId != null && (purchaseId != null || direction != DebtDirection.receivable)) {
      throw ArgumentError('Sale-originated debt must be a customer receivable.');
    }
    if (purchaseId != null &&
        (customerId != null || direction != DebtDirection.payable)) {
      throw ArgumentError('Purchase-originated debt must be a supplier payable.');
    }
    if (saleId != null && purchaseId != null) {
      throw ArgumentError('A debt cannot originate from both a sale and purchase.');
    }
    if (saleId != null && direction != DebtDirection.receivable) {
      throw ArgumentError('Sale-originated debt must be a customer receivable.');
    }
    if (purchaseId != null && direction != DebtDirection.payable) {
      throw ArgumentError('Purchase-originated debt must be a supplier payable.');
    }
  }

  @override
  final String id;
  final String? customerId;
  final String? supplierId;
  final String? saleId;
  final String? purchaseId;
  final DebtDirection direction;
  final int amountMinor;
  final DateTime dueDate;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'supplier_id': supplierId,
        'sale_id': saleId,
        'purchase_id': purchaseId,
        'direction': direction.name,
        'amount_minor': amountMinor,
        'due_date': dateToDatabase(dueDate),
        'description': description,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory Debt.fromMap(Map<String, Object?> map) {
    final directionName = requiredString(map, 'direction');
    final direction = DebtDirection.values.where(
      (value) => value.name == directionName,
    );
    if (direction.isEmpty) {
      throw FormatException('Unknown debt direction: $directionName');
    }
    return Debt(
      id: requiredString(map, 'id'),
      customerId: nullableString(map, 'customer_id'),
      supplierId: nullableString(map, 'supplier_id'),
      saleId: nullableString(map, 'sale_id'),
      purchaseId: nullableString(map, 'purchase_id'),
      direction: direction.first,
      amountMinor: requiredInt(map, 'amount_minor'),
      dueDate: dateFromDatabase(map['due_date']),
      description: nullableString(map, 'description'),
      createdAt: dateFromDatabase(map['created_at']),
      updatedAt: dateFromDatabase(map['updated_at']),
    );
  }
}
