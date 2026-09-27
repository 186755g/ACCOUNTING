import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations delegate is not configured.');
    return value!;
  }

  bool get isArabic => locale.languageCode == 'ar';

  String get appName => isArabic ? 'حساباتي' : 'Hesabati';
  String get welcome =>
      isArabic ? 'مرحباً بك في حساباتي' : 'Welcome to Hesabati';
  String get phaseOne => isArabic
      ? 'تم إعداد بنية التطبيق. ستظهر وحدات المبيعات والمخزون في المراحل القادمة.'
      : 'The application foundation is ready. Sales and inventory modules will be added in later phases.';
  String get language => isArabic ? 'English' : 'العربية';
  String get dashboard => isArabic ? 'لوحة التحكم' : 'Dashboard';
  String get greeting => isArabic ? 'صباح الخير' : 'Good morning';
  String get dashboardSubtitle => isArabic
      ? 'إليك ملخص نشاط متجرك اليوم'
      : 'Here is your store activity at a glance';
  String get today => isArabic ? 'اليوم' : 'Today';
  String get totalSales => isArabic ? 'إجمالي المبيعات' : 'Total sales';
  String get orders => isArabic ? 'الطلبات' : 'Orders';
  String get customers => isArabic ? 'العملاء' : 'Customers';
  String get lowStock => isArabic ? 'منتجات قاربت على النفاد' : 'Low stock items';
  String get salesChange => isArabic ? '١٢٪ هذا الشهر' : '+12% this month';
  String get ordersChange => isArabic ? '٨٪ هذا الشهر' : '+8% this month';
  String get customersChange => isArabic ? '٥٪ هذا الشهر' : '+5% this month';
  String get inventoryAttention => isArabic ? 'تحتاج إلى متابعة' : 'Needs attention';
  String get recentTransactions =>
      isArabic ? 'أحدث العمليات' : 'Recent transactions';
  String get viewAll => isArabic ? 'عرض الكل' : 'View all';
  String get bestSellingProducts =>
      isArabic ? 'المنتجات الأكثر مبيعاً' : 'Popular products';
  String get topCustomers => isArabic ? 'أبرز العملاء' : 'Top customers';
  String get sales => isArabic ? 'المبيعات' : 'Sales';
  String get inventory => isArabic ? 'المخزون' : 'Inventory';
  String get reports => isArabic ? 'التقارير' : 'Reports';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get search => isArabic ? 'ابحث عن عملية أو عميل' : 'Search activity';
  String get completed => isArabic ? 'مكتملة' : 'Completed';
  String get pending => isArabic ? 'قيد الانتظار' : 'Pending';
  String get minutesAgo => isArabic ? 'منذ ١٥ دقيقة' : '15 min ago';
  String get hourAgo => isArabic ? 'منذ ساعة' : '1 hour ago';
  String get hoursAgo => isArabic ? 'منذ ٣ ساعات' : '3 hours ago';
  String get todaySales => isArabic ? 'مبيعات اليوم' : "Today's sales";
  String get monthlyRevenue =>
      isArabic ? 'الإيرادات هذا الشهر' : 'Revenue this month';
  String get viewMode => isArabic ? 'تغيير المظهر' : 'Toggle appearance';
  String get account => isArabic ? 'حساب المتجر' : 'Store account';
  String get profileTitle => isArabic ? 'ملف النشاط التجاري' : 'Business profile';
  String get offlineProfileNotice => isArabic
      ? 'ملفك محفوظ على هذا الجهاز ويعمل دون اتصال بالإنترنت.'
      : 'Your profile is saved on this device and works offline.';
  String get businessName => isArabic ? 'اسم النشاط التجاري' : 'Business name';
  String get ownerName => isArabic ? 'اسم المالك' : 'Owner name';
  String get phone => isArabic ? 'رقم الهاتف' : 'Phone number';
  String get currency => isArabic ? 'العملة' : 'Currency';
  String get languageLabel => isArabic ? 'لغة التطبيق' : 'App language';
  String get businessType => isArabic ? 'نوع النشاط' : 'Business type';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get profileSaved =>
      isArabic ? 'تم حفظ الملف الشخصي' : 'Profile saved';
  String get profileSaveFailed => isArabic
      ? 'تعذر حفظ الملف الشخصي. حاول مرة أخرى.'
      : 'Could not save the profile. Please try again.';
  String get egyptianPound => isArabic ? 'جنيه مصري' : 'Egyptian pound';
  String get usDollar => isArabic ? 'دولار أمريكي' : 'US dollar';
  String get euro => isArabic ? 'يورو' : 'Euro';
  String get saudiRiyal => isArabic ? 'ريال سعودي' : 'Saudi riyal';
  String get uaeDirham => isArabic ? 'درهم إماراتي' : 'UAE dirham';
  String get arabicLanguage => isArabic ? 'العربية' : 'Arabic';
  String get englishLanguage => isArabic ? 'الإنجليزية' : 'English';
  String get retailBusiness => isArabic ? 'متجر تجزئة' : 'Retail';
  String get groceryBusiness => isArabic ? 'بقالة' : 'Grocery';
  String get restaurantBusiness => isArabic ? 'مطعم' : 'Restaurant';
  String get servicesBusiness => isArabic ? 'خدمات' : 'Services';
  String get otherBusiness => isArabic ? 'أخرى' : 'Other';
  String get demoNotice => isArabic
      ? 'أرقام توضيحية — ستظهر بيانات متجرك بعد إضافة العمليات.'
      : 'Sample figures — your store data will appear as you add activity.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.contains(locale);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
