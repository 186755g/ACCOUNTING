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
  String get home => isArabic ? 'الرئيسية' : 'Home';
  String get more => isArabic ? 'المزيد' : 'More';
  String get quickActions => isArabic ? 'إجراء سريع' : 'Quick actions';
  String get addExpense => isArabic ? 'إضافة مصروف' : 'Add expense';
  String get receivePayment => isArabic ? 'استلام دفعة' : 'Receive payment';
  String get addExpenseTitle =>
      isArabic ? 'إضافة مصروف جديد' : 'Add new expense';
  String get noExpenses => isArabic ? 'لا توجد مصروفات بعد' : 'No expenses yet';
  String get expenseSaved => isArabic ? 'تم حفظ المصروف' : 'Expense saved';
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
  String get shareReceipt => isArabic ? 'مشاركة الإيصال' : 'Share receipt';
  String get printReceipt => isArabic ? 'طباعة الإيصال' : 'Print receipt';
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
  String get supplier => isArabic ? 'المورد' : 'Supplier';
  String get businessManagement =>
      isArabic ? 'إدارة النشاط' : 'Business management';
  String get name => isArabic ? 'الاسم' : 'Name';
  String get address => isArabic ? 'العنوان' : 'Address';
  String get notes => isArabic ? 'ملاحظات' : 'Notes';
  String get quantity => isArabic ? 'الكمية' : 'Quantity';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get supplierManagement =>
      isArabic ? 'إدارة الموردين' : 'Supplier management';
  String get customerManagement =>
      isArabic ? 'إدارة العملاء' : 'Customer management';
  String get addCustomer => isArabic ? 'إضافة عميل' : 'Add customer';
  String get editCustomer => isArabic ? 'تعديل العميل' : 'Edit customer';
  String get addSupplier => isArabic ? 'إضافة مورد' : 'Add supplier';
  String get editSupplier => isArabic ? 'تعديل المورد' : 'Edit supplier';
  String get noCustomers => isArabic ? 'لا يوجد عملاء بعد' : 'No customers yet';
  String get noSuppliers =>
      isArabic ? 'لا يوجد موردون بعد' : 'No suppliers yet';
  String get totalPurchases =>
      isArabic ? 'إجمالي التعاملات' : 'Total purchases';
  String get totalPaid => isArabic ? 'إجمالي المدفوع' : 'Total paid';
  String get outstandingBalance => isArabic ? 'الرصيد المستحق' : 'Outstanding';
  String get transactionHistory =>
      isArabic ? 'سجل التعاملات' : 'Transaction history';
  String get transactionPayment =>
      isArabic ? 'دفعة على معاملة' : 'Transaction payment';
  String get noTransactionHistory =>
      isArabic ? 'لا توجد تعاملات بعد' : 'No transactions yet';
  String get debtHistory => isArabic ? 'سجل الديون' : 'Debt history';
  String get addDebt => isArabic ? 'إضافة دين' : 'Add debt';
  String get recordPayment => isArabic ? 'تسجيل دفعة' : 'Record payment';
  String get debtAmount => isArabic ? 'مبلغ الدين' : 'Debt amount';
  String get paymentAmount => isArabic ? 'مبلغ الدفعة' : 'Payment amount';
  String get recordedDebtPayment =>
      isArabic ? 'دفعة مسجلة للدين' : 'Debt payment';
  String get manualDebt => isArabic ? 'دين يدوي' : 'Manual debt';
  String get noOutstandingDebt =>
      isArabic ? 'لا يوجد رصيد مستحق للسداد' : 'No outstanding balance to pay';
  String get purchaseTitle => isArabic ? 'المشتريات' : 'Purchases';
  String get newPurchase => isArabic ? 'شراء جديد' : 'New purchase';
  String get recordPurchase => isArabic ? 'تسجيل الشراء' : 'Record purchase';
  String get noPurchases =>
      isArabic ? 'لا توجد مشتريات بعد' : 'No purchases yet';
  String get walkInSupplier =>
      isArabic ? 'بدون مورد مسجل' : 'No supplier selected';
  String get unpaidAmount => isArabic ? 'المبلغ غير المدفوع' : 'Unpaid amount';
  String get paymentExceedsTotal => isArabic
      ? 'لا يمكن أن يتجاوز المبلغ المدفوع إجمالي الشراء.'
      : 'Payment cannot exceed the purchase total.';
  String get supplierRequiredForDebt => isArabic
      ? 'اختر مورداً لتسجيل المبلغ غير المدفوع كدين.'
      : 'Select a supplier to record an unpaid balance.';
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
  String get analytics => isArabic ? 'التحليلات' : 'Analytics';
  String get reportTitle =>
      isArabic ? 'تقرير النشاط التجاري' : 'Business report';
  String get dateRange => isArabic ? 'الفترة' : 'Date range';
  String get metric => isArabic ? 'المؤشر' : 'Metric';
  String get amount => isArabic ? 'المبلغ' : 'Amount';
  String get grossSales => isArabic ? 'إجمالي المبيعات' : 'Gross sales';
  String get netSales => isArabic ? 'صافي المبيعات' : 'Net sales';
  String get refunds => isArabic ? 'المرتجعات' : 'Refunds';
  String get costOfGoods =>
      isArabic ? 'تكلفة البضاعة المباعة' : 'Cost of goods sold';
  String get grossProfit => isArabic ? 'إجمالي الربح' : 'Gross profit';
  String get netProfit => isArabic ? 'صافي الربح' : 'Net profit';
  String get expenses => isArabic ? 'المصروفات' : 'Expenses';
  String get expenseCategory => isArabic ? 'بند المصروف' : 'Expense category';
  String get profit => isArabic ? 'الربح' : 'Profit';
  String get productPerformance =>
      isArabic ? 'أداء المنتجات' : 'Product performance';
  String get daily => isArabic ? 'يومي' : 'Daily';
  String get weekly => isArabic ? 'أسبوعي' : 'Weekly';
  String get monthly => isArabic ? 'شهري' : 'Monthly';
  String get yearly => isArabic ? 'سنوي' : 'Yearly';
  String get salesOverTime => isArabic
      ? 'المبيعات والأرباح والمصروفات عبر الزمن'
      : 'Sales, profit and expenses over time';
  String get leastSellingProducts =>
      isArabic ? 'الأقل مبيعاً' : 'Least-selling products';
  String get highestProfitProducts =>
      isArabic ? 'الأعلى ربحاً' : 'Highest-profit products';
  String get customerAnalysis =>
      isArabic ? 'تحليل مشتريات العملاء' : 'Customer purchase analysis';
  String get inventoryValue => isArabic ? 'قيمة المخزون' : 'Inventory value';
  String get costValue => isArabic ? 'القيمة بالتكلفة' : 'Cost value';
  String get retailValue => isArabic ? 'القيمة بسعر البيع' : 'Retail value';
  String get customerDebt => isArabic ? 'ديون العملاء' : 'Customer debts';
  String get supplierDebt => isArabic ? 'ديون الموردين' : 'Supplier debts';
  String get exportCsv => isArabic ? 'تصدير CSV' : 'Export CSV';
  String get exportPdf => isArabic ? 'تصدير PDF' : 'Export PDF';
  String get exportXlsx => isArabic ? 'تصدير Excel' : 'Export Excel';
  String get reportReadyForSharing => isArabic
      ? 'تم تجهيز التقرير للمشاركة أو الحفظ'
      : 'The report is ready to share or save.';
  String exportFailed(String error) => isArabic
      ? 'تعذر تصدير التقرير: $error'
      : 'Failed to export report: $error';
  String get generatedReportNotice => isArabic
      ? 'تم إنشاء التقرير من البيانات المسجلة دون تنبؤات.'
      : 'Generated from recorded transactions; no forecasts included.';
  String get noReportData =>
      isArabic ? 'لا توجد بيانات لهذه الفترة' : 'No data for this period';
  String get searchAnalytics =>
      isArabic ? 'ابحث في التحليلات' : 'Search analytics';
  String get applyFilters => isArabic ? 'تطبيق عوامل التصفية' : 'Apply filters';
  String get salesOverTimeLabel => isArabic ? 'المبيعات' : 'Sales';
  String get profitOverTimeLabel => isArabic ? 'الأرباح' : 'Profit';
  String get expensesOverTimeLabel => isArabic ? 'المصروفات' : 'Expenses';
  String get globalSearch => isArabic ? 'بحث شامل' : 'Global search';
  String get searchEverything => isArabic
      ? 'ابحث في المنتجات والعملاء والمبيعات...'
      : 'Search products, customers, sales...';
  String get purchasesTitle => isArabic ? 'المشتريات' : 'Purchases';
  String get paymentStatus => isArabic ? 'حالة الدفع' : 'Payment status';
  String get allRecords => isArabic ? 'كل السجلات' : 'All records';
  String get paidInFull => isArabic ? 'مدفوع بالكامل' : 'Paid in full';
  String get partiallyPaid => isArabic ? 'مدفوع جزئياً' : 'Partially paid';
  String get unpaidOnly => isArabic ? 'غير مدفوع' : 'Unpaid';
  String get stockStatus => isArabic ? 'حالة المخزون' : 'Stock status';
  String get inStock => isArabic ? 'متوفر' : 'In stock';
  String get category => isArabic ? 'التصنيف' : 'Category';
  String get outOfStock => isArabic ? 'نفد المخزون' : 'Out of stock';
  String get noSearchResults =>
      isArabic ? 'لا توجد نتائج مطابقة' : 'No matching results';
  String get showMore => isArabic ? 'عرض المزيد' : 'Show more';
  String get salesSection => isArabic ? 'المبيعات' : 'Sales';
  String get productsSection => isArabic ? 'المنتجات' : 'Products';
  String get customersSection => isArabic ? 'العملاء' : 'Customers';
  String get suppliersSection => isArabic ? 'الموردون' : 'Suppliers';
  String get purchasesSection => isArabic ? 'المشتريات' : 'Purchases';
  String get dashboardTodayProfit => isArabic ? 'ربح اليوم' : "Today's profit";
  String get dashboardTodayExpenses =>
      isArabic ? 'مصروفات اليوم' : "Today's expenses";
  String get dashboardTodayNetProfit =>
      isArabic ? 'صافي ربح اليوم' : "Today's net profit";
  String get totalProducts => isArabic ? 'إجمالي المنتجات' : 'Total products';
  String get customerOutstanding =>
      isArabic ? 'ديون العملاء المستحقة' : 'Customer balances due';
  String get supplierOutstanding =>
      isArabic ? 'مستحقات الموردين' : 'Supplier balances due';
  String get noRecentSales =>
      isArabic ? 'لا توجد مبيعات حديثة' : 'No recent sales';
  String get chooseDateRange => isArabic ? 'اختر الفترة' : 'Choose date range';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get search => isArabic ? 'ابحث عن عملية أو عميل' : 'Search activity';
  String get completed => isArabic ? 'مكتملة' : 'Completed';
  String get pending => isArabic ? 'قيد الانتظار' : 'Pending';
  String get minutesAgo => isArabic ? 'منذ ١٥ دقيقة' : '15 min ago';
  String get hourAgo => isArabic ? 'منذ ساعة' : '1 hour ago';
  String get hoursAgo => isArabic ? 'منذ ٣ ساعات' : '3 hours ago';
  String get todaySales => isArabic ? 'مبيعات اليوم' : "Today's sales";
  String get loading => isArabic ? 'جارٍ التحميل' : 'Loading';
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
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get notifyLowStock =>
      isArabic ? 'التنبيه عند انخفاض المخزون' : 'Low-stock alerts';
  String get notifyOutOfStock =>
      isArabic ? 'التنبيه عند نفاد المخزون' : 'Out-of-stock alerts';
  String get notifyUnpaidDebts => isArabic
      ? 'التنبيه عن ديون العملاء والموردين'
      : 'Unpaid customer/supplier balances';
  String get notifyOverduePayments => isArabic
      ? 'التنبيه عن دفعات العملاء والموردين المتأخرة'
      : 'Overdue customer/supplier payments';
  String get notifyDailySales =>
      isArabic ? 'ملخص المبيعات اليومي' : 'Daily sales summary';
  String get dailySalesNotificationTiming => isArabic
      ? 'يظهر ملخص الأمس عند فتح التطبيق في يوم جديد.'
      : 'Yesterday’s summary appears when you open the app on a new day.';
  String get notificationPermissionDenied => isArabic
      ? 'لم يتم منح إذن الإشعارات. يمكنك تفعيله من إعدادات الجهاز.'
      : 'Notification permission was not granted. You can enable it in device settings.';
  String get notificationPermissionFailed => isArabic
      ? 'تعذر طلب إذن الإشعارات. حاول مرة أخرى.'
      : 'Could not request notification permission. Please try again.';
  String get backupTitle => isArabic ? 'النسخ الاحتياطي' : 'Backup';
  String get latestBackup => isArabic ? 'آخر نسخة احتياطية' : 'Latest backup';
  String get noBackupCreated =>
      isArabic ? 'لم يتم إنشاء نسخة احتياطية بعد.' : 'No backup created yet.';
  String get backupPrivacyNotice => isArabic
      ? 'تتضمن النسخة بيانات النشاط والعملاء. اختر مكاناً آمناً عند مشاركتها.'
      : 'Backups contain business and customer data. Choose a safe destination when sharing.';
  String get createAndExportBackup =>
      isArabic ? 'إنشاء نسخة ومشاركتها' : 'Create and export backup';
  String get backupCreated =>
      isArabic ? 'تم إنشاء النسخة الاحتياطية.' : 'Backup created successfully.';
  String get backupExportFailed => isArabic
      ? 'تم حفظ النسخة على الجهاز، لكن تعذرت مشاركتها.'
      : 'The backup was saved on this device, but could not be shared.';
  String get backupStatusUnavailable => isArabic
      ? 'تعذر التحقق من آخر نسخة احتياطية.'
      : 'Could not check the latest backup.';
  String get backupFailed => isArabic
      ? 'تعذر إنشاء النسخة أو مشاركتها.'
      : 'Could not create or export the backup.';
  String get restoreBackup =>
      isArabic ? 'استعادة نسخة احتياطية' : 'Restore backup';
  String get restoreBackupWarning => isArabic
      ? 'سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. لا يمكن التراجع عن ذلك. تأكد من إنشاء نسخة من بياناتك الحالية أولاً.'
      : 'All current data will be replaced by the selected backup. This cannot be undone. Consider creating a backup of current data first.';
  String get restore => isArabic ? 'استعادة' : 'Restore';
  String get backupInvalid => isArabic
      ? 'النسخة تالفة أو غير متوافقة؛ لم يتم تغيير بياناتك.'
      : 'The backup is corrupt or incompatible; your data was not changed.';
  String get restoreFailed => isArabic
      ? 'تعذرت الاستعادة وتمت حماية البيانات الحالية.'
      : 'Restore failed and your current data was protected.';
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
