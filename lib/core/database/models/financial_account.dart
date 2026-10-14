import 'model_utils.dart';

enum FinancialAccountType { cash, bank, card, mobileWallet, other }
enum AccountMovementDirection { credit, debit }

class FinancialAccount implements DatabaseEntity {
  FinancialAccount({
    String? id,
    required this.name,
    this.type = FinancialAccountType.cash,
    this.accountNumber,
    this.notes,
    this.openingBalanceMinor = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newModelId(),
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
  }

  @override
  final String id;
  final String name;
  final FinancialAccountType type;
  final String? accountNumber;
  final String? notes;
  final int openingBalanceMinor;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name.trim(),
        'type': type.name,
        'account_number': accountNumber,
        'notes': notes,
        'opening_balance_minor': openingBalanceMinor,
        'is_active': isActive ? 1 : 0,
        'created_at': dateToDatabase(createdAt),
        'updated_at': dateToDatabase(updatedAt),
      };

  factory FinancialAccount.fromMap(Map<String, Object?> map) => FinancialAccount(
        id: requiredString(map, 'id'),
        name: requiredString(map, 'name'),
        type: FinancialAccountType.values.firstWhere(
          (value) => value.name == requiredString(map, 'type'),
          orElse: () => FinancialAccountType.other,
        ),
        accountNumber: nullableString(map, 'account_number'),
        notes: nullableString(map, 'notes'),
        openingBalanceMinor: requiredInt(map, 'opening_balance_minor'),
        isActive: requiredBool(map, 'is_active'),
        createdAt: dateFromDatabase(map['created_at']),
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}

class AccountMovement implements DatabaseEntity {
  AccountMovement({
    String? id,
    required this.accountId,
    required this.direction,
    required this.amountMinor,
    DateTime? date,
    this.description,
    this.reference,
    this.sourceType,
    this.sourceId,
    DateTime? createdAt,
  })  : id = id ?? newModelId(),
        date = (date ?? DateTime.now()).toUtc(),
        createdAt = (createdAt ?? DateTime.now()).toUtc() {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
  }

  @override
  final String id;
  final String accountId;
  final AccountMovementDirection direction;
  final int amountMinor;
  final DateTime date;
  final String? description;
  final String? reference;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'direction': direction.name,
        'amount_minor': amountMinor,
        'date_at': dateToDatabase(date),
        'description': description,
        'reference': reference,
        'source_type': sourceType,
        'source_id': sourceId,
        'created_at': dateToDatabase(createdAt),
      };

  factory AccountMovement.fromMap(Map<String, Object?> map) {
    final directionName = requiredString(map, 'direction');
    final direction = AccountMovementDirection.values.firstWhere(
      (value) => value.name == directionName,
      orElse: () => AccountMovementDirection.credit,
    );
    return AccountMovement(
      id: requiredString(map, 'id'),
      accountId: requiredString(map, 'account_id'),
      direction: direction,
      amountMinor: requiredInt(map, 'amount_minor'),
      date: dateFromDatabase(map['date_at']),
      description: nullableString(map, 'description'),
      reference: nullableString(map, 'reference'),
      sourceType: nullableString(map, 'source_type'),
      sourceId: nullableString(map, 'source_id'),
      createdAt: dateFromDatabase(map['created_at']),
    );
  }
}

class AccountReconciliation implements DatabaseEntity {
  AccountReconciliation({
    String? id,
    required this.accountId,
    required this.date,
    required this.bookBalanceMinor,
    required this.actualBalanceMinor,
    this.note,
    DateTime? createdAt,
  })  : id = id ?? newModelId(),
        varianceMinor = actualBalanceMinor - bookBalanceMinor,
        status = (actualBalanceMinor == bookBalanceMinor) ? 'matched' : 'variance',
        createdAt = (createdAt ?? DateTime.now()).toUtc() {
    if (accountId.trim().isEmpty) throw ArgumentError.value(accountId, 'accountId');
  }

  @override
  final String id;
  final String accountId;
  final DateTime date;
  final int bookBalanceMinor;
  final int actualBalanceMinor;
  final int varianceMinor;
  final String status;
  final String? note;
  final DateTime createdAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'date_at': dateToDatabase(date),
        'book_balance_minor': bookBalanceMinor,
        'actual_balance_minor': actualBalanceMinor,
        'variance_minor': varianceMinor,
        'status': status,
        'note': note,
        'created_at': dateToDatabase(createdAt),
      };

  factory AccountReconciliation.fromMap(Map<String, Object?> map) =>
      AccountReconciliation(
        id: requiredString(map, 'id'),
        accountId: requiredString(map, 'account_id'),
        date: dateFromDatabase(map['date_at']),
        bookBalanceMinor: requiredInt(map, 'book_balance_minor'),
        actualBalanceMinor: requiredInt(map, 'actual_balance_minor'),
        note: nullableString(map, 'note'),
        createdAt: dateFromDatabase(map['created_at']),
      );
}
