import 'model_utils.dart';

class AppSettings implements DatabaseEntity {
  AppSettings({
    this.id = '1',
    this.businessName = '',
    this.ownerName = '',
    this.phone = '',
    this.currencyCode = 'EGP',
    this.localeCode = 'ar',
    this.businessType = 'other',
    this.themeMode = 'system',
    this.allowNegativeStock = false,
    this.notifyLowStock = false,
    this.notifyOutOfStock = false,
    this.notifyUnpaidDebts = false,
    this.notifyOverduePayments = false,
    this.notifyDailySales = false,
    DateTime? updatedAt,
  }) : updatedAt = (updatedAt ?? DateTime.now()).toUtc() {
    if (id != '1') throw ArgumentError.value(id, 'id', 'Settings use id "1".');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError.value(currencyCode, 'currencyCode');
    }
    if (!const {'ar', 'en'}.contains(localeCode)) {
      throw ArgumentError.value(localeCode, 'localeCode');
    }
    if (!const {
      'retail',
      'grocery',
      'restaurant',
      'services',
      'other',
    }.contains(businessType)) {
      throw ArgumentError.value(businessType, 'businessType');
    }
    if (!const {'system', 'light', 'dark'}.contains(themeMode)) {
      throw ArgumentError.value(themeMode, 'themeMode');
    }
  }

  @override
  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String currencyCode;
  final String localeCode;
  final String businessType;
  final String themeMode;
  final bool allowNegativeStock;
  final bool notifyLowStock;
  final bool notifyOutOfStock;
  final bool notifyUnpaidDebts;
  final bool notifyOverduePayments;
  final bool notifyDailySales;
  final DateTime updatedAt;

  AppSettings copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? currencyCode,
    String? localeCode,
    String? businessType,
    String? themeMode,
    bool? allowNegativeStock,
    bool? notifyLowStock,
    bool? notifyOutOfStock,
    bool? notifyUnpaidDebts,
    bool? notifyOverduePayments,
    bool? notifyDailySales,
    DateTime? updatedAt,
  }) =>
      AppSettings(
        id: id,
        businessName: businessName ?? this.businessName,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        currencyCode: currencyCode ?? this.currencyCode,
        localeCode: localeCode ?? this.localeCode,
        businessType: businessType ?? this.businessType,
        themeMode: themeMode ?? this.themeMode,
        allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
        notifyLowStock: notifyLowStock ?? this.notifyLowStock,
        notifyOutOfStock: notifyOutOfStock ?? this.notifyOutOfStock,
        notifyUnpaidDebts: notifyUnpaidDebts ?? this.notifyUnpaidDebts,
        notifyOverduePayments:
            notifyOverduePayments ?? this.notifyOverduePayments,
        notifyDailySales: notifyDailySales ?? this.notifyDailySales,
        updatedAt: updatedAt,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'business_name': businessName,
        'owner_name': ownerName,
        'phone': phone,
        'currency_code': currencyCode,
        'locale_code': localeCode,
        'business_type': businessType,
        'theme_mode': themeMode,
        'allow_negative_stock': allowNegativeStock ? 1 : 0,
        'notify_low_stock': notifyLowStock ? 1 : 0,
        'notify_out_of_stock': notifyOutOfStock ? 1 : 0,
        'notify_unpaid_debts': notifyUnpaidDebts ? 1 : 0,
        'notify_overdue_payments': notifyOverduePayments ? 1 : 0,
        'notify_daily_sales': notifyDailySales ? 1 : 0,
        'updated_at': dateToDatabase(updatedAt),
      };

  factory AppSettings.fromMap(Map<String, Object?> map) => AppSettings(
        id: requiredString(map, 'id'),
        businessName: requiredString(map, 'business_name'),
        ownerName: requiredString(map, 'owner_name'),
        phone: requiredString(map, 'phone'),
        currencyCode: requiredString(map, 'currency_code'),
        localeCode: requiredString(map, 'locale_code'),
        businessType: requiredString(map, 'business_type'),
        themeMode: requiredString(map, 'theme_mode'),
        allowNegativeStock: map['allow_negative_stock'] == 1,
        notifyLowStock: map['notify_low_stock'] == 1,
        notifyOutOfStock: map['notify_out_of_stock'] == 1,
        notifyUnpaidDebts: map['notify_unpaid_debts'] == 1,
        notifyOverduePayments: map['notify_overdue_payments'] == 1,
        notifyDailySales: map['notify_daily_sales'] == 1,
        updatedAt: dateFromDatabase(map['updated_at']),
      );
}
