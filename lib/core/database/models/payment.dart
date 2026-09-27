import 'model_utils.dart';

enum PaymentMethod { cash, card, bankTransfer, mobileWallet, other }

class Payment implements DatabaseEntity {
  Payment({
    String? id,
    this.saleId,
    this.purchaseId,
    this.debtId,
    this.expenseId,
    this.userId,
    required this.amountMinor,
    required this.method,
    DateTime? date,
    this.reference,
    this.notes,
  })  : id = id ?? newModelId(),
        date = (date ?? DateTime.now()).toUtc() {
    final linkedRecords = [
      saleId,
      purchaseId,
      debtId,
      expenseId,
    ].where((value) => value != null).length;
    if (linkedRecords != 1) {
      throw ArgumentError('A payment must reference exactly one business record.');
    }
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
  }

  @override
  final String id;
  final String? saleId;
  final String? purchaseId;
  final String? debtId;
  final String? expenseId;
  final String? userId;
  final int amountMinor;
  final PaymentMethod method;
  final DateTime date;
  final String? reference;
  final String? notes;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'sale_id': saleId,
        'purchase_id': purchaseId,
        'debt_id': debtId,
        'expense_id': expenseId,
        'user_id': userId,
        'amount_minor': amountMinor,
        'method': method.name,
        'date_at': dateToDatabase(date),
        'reference': reference,
        'notes': notes,
      };

  factory Payment.fromMap(Map<String, Object?> map) {
    final methodName = requiredString(map, 'method');
    final methods = PaymentMethod.values.where(
      (value) => value.name == methodName,
    );
    if (methods.isEmpty) {
      throw FormatException('Unknown payment method: $methodName');
    }
    return Payment(
      id: requiredString(map, 'id'),
      saleId: nullableString(map, 'sale_id'),
      purchaseId: nullableString(map, 'purchase_id'),
      debtId: nullableString(map, 'debt_id'),
      expenseId: nullableString(map, 'expense_id'),
      userId: nullableString(map, 'user_id'),
      amountMinor: requiredInt(map, 'amount_minor'),
      method: methods.first,
      date: dateFromDatabase(map['date_at']),
      reference: nullableString(map, 'reference'),
      notes: nullableString(map, 'notes'),
    );
  }
}
