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
  String get lowStock =>
      isArabic ? 'منتجات قاربت على النفاد' : 'Low stock items';
  String get salesChange => isArabic ? '١٢٪ هذا الشهر' : '+12% this month';
  String get ordersChange => isArabic ? '٨٪ هذا الشهر' : '+8% this month';
  String get customersChange => isArabic ? '٥٪ هذا الشهر' : '+5% this month';
  String get inventoryAttention =>
      isArabic ? 'تحتاج إلى متابعة' : 'Needs attention';
  String get recentTransactions =>
      isArabic ? 'أحدث العمليات' : 'Recent transactions';
  String get viewAll => isArabic ? 'عرض الكل' : 'View all';
  String get bestSellingProducts =>
      isArabic ? 'المنتجات الأكثر مبيعاً' : 'Popular products';
  String get topCustomers => isArabic ? 'أبرز العملاء' : 'Top customers';
  String get sales => isArabic ? 'المبيعات' : 'Sales';
  String get salesTitle => isArabic ? 'المبيعات' : 'Sales';
  String get customer => isArabic ? 'العميل' : 'Customer';
  String get total => isArabic ? 'الإجمالي' : 'Total';
  String get newSale => isArabic ? 'بيع جديد' : 'New sale';
  String get noSales => isArabic ? 'لا توجد مبيعات بعد' : 'No sales yet';
  String get saleDetails => isArabic ? 'تفاصيل البيع' : 'Sale details';
  String get saleNotFound =>
      isArabic ? 'لم يتم العثور على البيع' : 'Sale not found';
  String get saleNumber => isArabic ? 'فاتورة رقم' : 'Sale #';
  String get saleItems => isArabic ? 'منتجات' : 'items';
  String get cart => isArabic ? 'سلة البيع' : 'Cart';
  String get cartEmpty =>
      isArabic ? 'أضف منتجات لبدء البيع' : 'Add products to start a sale';
  String get addToCart => isArabic ? 'أضف إلى السلة' : 'Add to cart';
  String get increaseQuantity =>
      isArabic ? 'زيادة الكمية' : 'Increase quantity';
  String get decreaseQuantity =>
      isArabic ? 'تقليل الكمية' : 'Decrease quantity';
  String get walkInCustomer =>
      isArabic ? 'عميل نقدي / بدون عميل' : 'Walk-in customer';
  String get paymentMethod => isArabic ? 'طريقة الدفع' : 'Payment method';
  String get cash => isArabic ? 'نقداً' : 'Cash';
  String get card => isArabic ? 'بطاقة' : 'Card';
  String get wallet => isArabic ? 'محفظة إلكترونية' : 'Wallet';
  String get unpaidDebt => isArabic ? 'آجل / دين' : 'Unpaid / debt';
  String get discount => isArabic ? 'الخصم' : 'Discount';
  String get discountExceedsSubtotal => isArabic
      ? 'لا يمكن أن يتجاوز الخصم إجمالي المنتجات.'
      : 'Discount cannot exceed the items subtotal.';
  String get customerRequiredForDebt => isArabic
      ? 'اختر عميلاً لتسجيل المبلغ كدين.'
      : 'Select a customer to record an unpaid balance.';
  String get productUnavailable => isArabic
      ? 'أحد المنتجات لم يعد متاحاً. حدّث السلة وحاول مرة أخرى.'
      : 'A product is no longer available. Refresh the cart and try again.';
  String get recordSale => isArabic ? 'تسجيل البيع' : 'Record sale';
  String get subtotal => isArabic ? 'الإجمالي قبل الخصم' : 'Subtotal';
  String get lineDiscount => isArabic ? 'خصم المنتج' : 'Item discount';
  String get costAtSale =>
      isArabic ? 'تكلفة المنتجات وقت البيع' : 'Cost at sale';
  String get payments => isArabic ? 'المدفوعات' : 'Payments';
  String get noPaymentsRecorded =>
      isArabic ? 'لم يتم تسجيل دفعة' : 'No payments recorded';
  String get bankTransfer => isArabic ? 'تحويل بنكي' : 'Bank transfer';
  String get otherPaymentMethod => isArabic ? 'أخرى' : 'Other';
  String get inventory => isArabic ? 'المخزون' : 'Inventory';
  String get inventoryTitle =>
      isArabic ? 'إدارة المخزون' : 'Inventory management';
  String get inventoryHistory =>
      isArabic ? 'سجل حركة المخزون' : 'Inventory history';
  String get lowStockAlerts =>
      isArabic ? 'تنبيهات المخزون المنخفض' : 'Low-stock alerts';
  String get outOfStockAlerts =>
      isArabic ? 'تنبيهات نفاد المخزون' : 'Out-of-stock alerts';
  String get noInventoryAlerts =>
      isArabic ? 'لا توجد تنبيهات مخزون' : 'No inventory alerts';
  String get noInventoryHistory =>
      isArabic ? 'لا توجد حركات مخزون بعد' : 'No inventory history yet';
  String get adjustStock => isArabic ? 'تسوية المخزون' : 'Adjust stock';
  String get adjustmentReason => isArabic ? 'سبب التسوية' : 'Adjustment reason';
  String get adjustmentQuantity =>
      isArabic ? 'تغيير الكمية (+/-)' : 'Quantity change (+/-)';
  String get previousQuantity =>
      isArabic ? 'الكمية السابقة' : 'Previous quantity';
  String get newQuantity => isArabic ? 'الكمية الجديدة' : 'New quantity';
  String get inventoryDate => isArabic ? 'التاريخ' : 'Date';
  String get note => isArabic ? 'ملاحظة' : 'Note';
  String get returnProduct => isArabic ? 'مرتجع بيع' : 'Sale return';
  String get openingStock => isArabic ? 'رصيد افتتاحي' : 'Opening stock';
  String get saleReversal => isArabic ? 'إلغاء بيع' : 'Sale reversal';
  String get purchaseReversal => isArabic ? 'إلغاء شراء' : 'Purchase reversal';
  String get saleReason => isArabic ? 'بيع' : 'Sale';
  String get purchaseReason => isArabic ? 'شراء' : 'Purchase';
  String get manualAdjustment => isArabic ? 'تسوية يدوية' : 'Manual adjustment';
  String get saleAdjustment => isArabic ? 'تسوية بيع' : 'Sale adjustment';
  String get purchaseAdjustment =>
      isArabic ? 'تسوية شراء' : 'Purchase adjustment';
  String get allowNegativeStock =>
      isArabic ? 'السماح بالمخزون السالب' : 'Allow negative stock';
  String get allowNegativeStockDescription => isArabic
      ? 'عند إيقافه، تُرفض المبيعات أو التسويات التي تتجاوز الكمية المتاحة.'
      : 'When disabled, sales and adjustments that exceed available stock are rejected.';
  String get stockAdjusted => isArabic ? 'تمت تسوية المخزون' : 'Stock adjusted';
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
  String get profileTitle =>
      isArabic ? 'ملف النشاط التجاري' : 'Business profile';
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
  String get profileSaved => isArabic ? 'تم حفظ الملف الشخصي' : 'Profile saved';
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
  String get productsTitle => isArabic ? 'المنتجات' : 'Products';
  String get categoriesTitle => isArabic ? 'التصنيفات' : 'Categories';
  String get manageProducts => isArabic ? 'إدارة المنتجات' : 'Manage products';
  String get addProduct => isArabic ? 'إضافة منتج' : 'Add product';
  String get editProduct => isArabic ? 'تعديل المنتج' : 'Edit product';
  String get duplicateProduct => isArabic ? 'نسخ المنتج' : 'Duplicate product';
  String get productName => isArabic ? 'اسم المنتج' : 'Product name';
  String get sku => isArabic ? 'رمز المنتج (SKU)' : 'SKU';
  String get barcode => isArabic ? 'الباركود' : 'Barcode';
  String get purchasePrice => isArabic ? 'سعر الشراء' : 'Purchase price';
  String get sellingPrice => isArabic ? 'سعر البيع' : 'Selling price';
  String get stockQuantity => isArabic ? 'الكمية بالمخزون' : 'Stock quantity';
  String get minimumStock => isArabic ? 'حد المخزون الأدنى' : 'Minimum stock';
  String get unit => isArabic ? 'الوحدة' : 'Unit';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get productImagePath =>
      isArabic ? 'مسار صورة المنتج' : 'Product image path';
  String get imagePathHint => isArabic
      ? 'أدخل مسار الصورة على هذا الجهاز'
      : 'Enter the image path on this device';
  String get selectCategory => isArabic ? 'التصنيف' : 'Category';
  String get noCategory => isArabic ? 'بدون تصنيف' : 'No category';
  String get activeProduct => isArabic ? 'منتج نشط' : 'Active product';
  String get active => isArabic ? 'نشط' : 'Active';
  String get inactive => isArabic ? 'غير نشط' : 'Inactive';
  String get searchProducts => isArabic
      ? 'ابحث بالاسم أو SKU أو الباركود'
      : 'Search name, SKU or barcode';
  String get allCategories => isArabic ? 'كل التصنيفات' : 'All categories';
  String get lowStockOnly => isArabic ? 'المخزون المنخفض' : 'Low stock';
  String get sortBy => isArabic ? 'ترتيب حسب' : 'Sort by';
  String get sortName => isArabic ? 'الاسم' : 'Name';
  String get sortStock => isArabic ? 'الكمية' : 'Stock';
  String get sortPurchasePrice => isArabic ? 'سعر الشراء' : 'Purchase price';
  String get sortSellingPrice => isArabic ? 'سعر البيع' : 'Selling price';
  String get sortCreatedDate => isArabic ? 'تاريخ الإضافة' : 'Date added';
  String get ascending => isArabic ? 'تصاعدي' : 'Ascending';
  String get descending => isArabic ? 'تنازلي' : 'Descending';
  String get noProducts => isArabic ? 'لا توجد منتجات' : 'No products';
  String get noCategories => isArabic ? 'لا توجد تصنيفات' : 'No categories';
  String get addCategory => isArabic ? 'إضافة تصنيف' : 'Add category';
  String get editCategory => isArabic ? 'تعديل التصنيف' : 'Edit category';
  String get categoryName => isArabic ? 'اسم التصنيف' : 'Category name';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get confirmDeleteProduct => isArabic
      ? 'هل تريد حذف هذا المنتج؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Delete this product? This action cannot be undone.';
  String get confirmDeleteCategory => isArabic
      ? 'هل تريد حذف هذا التصنيف؟ ستبقى المنتجات المرتبطة به بدون تصنيف.'
      : 'Delete this category? Its products will remain uncategorized.';
  String get productSaved => isArabic ? 'تم حفظ المنتج' : 'Product saved';
  String get categorySaved => isArabic ? 'تم حفظ التصنيف' : 'Category saved';
  String get recordDeleted => isArabic ? 'تم الحذف' : 'Deleted';
  String get duplicateValueError => isArabic
      ? 'رمز المنتج أو الباركود مستخدم بالفعل.'
      : 'The SKU or barcode is already in use.';
  String get duplicateCategoryError => isArabic
      ? 'يوجد تصنيف بهذا الاسم بالفعل.'
      : 'A category with this name already exists.';
  String get requiredField =>
      isArabic ? 'هذا الحقل مطلوب' : 'This field is required';
  String get invalidNumber =>
      isArabic ? 'أدخل رقماً صالحاً' : 'Enter a valid number';
  String get invalidNonNegative =>
      isArabic ? 'يجب أن يكون الرقم صفراً أو أكثر' : 'Must be zero or greater';
  String get createdDate => isArabic ? 'تاريخ الإضافة' : 'Created';
  String get updatedDate => isArabic ? 'آخر تحديث' : 'Updated';
  String get imageUnavailable =>
      isArabic ? 'الصورة غير متاحة' : 'Image unavailable';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
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
