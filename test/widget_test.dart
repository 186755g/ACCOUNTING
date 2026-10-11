import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/app/app.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:hesabati/core/services/local_alert_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase database;
  late AppSettings settings;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await LocalDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    settings = (await database.settings.get())!;
  });

  tearDown(() => database.close());

  Future<DashboardData> loadEmptyDashboard(DateTime _) async =>
      const DashboardData(
        summary: DashboardSummary(
          financial: FinancialSummary(
            grossSalesMinor: 0,
            discountsMinor: 0,
            refundsMinor: 0,
            costOfGoodsMinor: 0,
            expensesMinor: 0,
            grossProfitMinor: 0,
            netProfitMinor: 0,
            customerDebtPaymentsMinor: 0,
            supplierDebtPaymentsMinor: 0,
          ),
          productCount: 0,
          lowStockCount: 0,
          customerOutstandingMinor: 0,
          supplierOutstandingMinor: 0,
          todaySalesCount: 0,
          recentSales: [],
        ),
        trend: [],
      );

  testWidgets('shows the Arabic dashboard and summary cards', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsOneWidget);
    expect(find.text('صباح الخير'), findsOneWidget);
    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(find.text('أحدث العمليات'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-logo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-business-management')));
    await tester.pumpAndSettle();
    expect(find.text('إدارة الموردين'), findsOneWidget);
    expect(find.text('المشتريات'), findsOneWidget);
    expect(find.text('المصروفات'), findsOneWidget);
  });

  testWidgets('switches language and theme', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    final savedSettings = await tester.runAsync(() => database.settings.get());
    expect(savedSettings!.localeCode, 'en');
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('shows each customer debt outstanding balance independently', (
    tester,
  ) async {
    final customer = Customer(name: 'رصيد الاختبار');
    await database.customers.create(customer);
    final firstDebt = await database.partyAccounts.addCustomerDebt(
      customerId: customer.id,
      amountMinor: 10000,
      description: 'الدين الأول',
    );
    final secondDebt = await database.partyAccounts.addCustomerDebt(
      customerId: customer.id,
      amountMinor: 25000,
      description: 'الدين الثاني',
    );
    await database.partyAccounts.recordPayment(
      debtId: firstDebt.id,
      amountMinor: 3000,
      method: PaymentMethod.cash,
    );
    await database.partyAccounts.recordPayment(
      debtId: secondDebt.id,
      amountMinor: 5000,
      method: PaymentMethod.cash,
    );

    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-customers')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رصيد الاختبار'));
    await tester.pumpAndSettle();

    expect(find.text('الرصيد المستحق: EGP 70.00'), findsOneWidget);
    expect(find.text('الرصيد المستحق: EGP 200.00'), findsOneWidget);
  });

  testWidgets('navigates from the main bar and opens More destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-products')));
    await tester.pumpAndSettle();
    expect(find.text('المنتجات'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-sales')));
    await tester.pumpAndSettle();
    expect(find.text('بيع جديد'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-customers')));
    await tester.pumpAndSettle();
    expect(find.text('إدارة العملاء'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-business-management')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expenses')));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مصروفات بعد'), findsOneWidget);
  });

  testWidgets('quick actions record a validated expense and payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-action-menu')));
    await tester.pumpAndSettle();
    expect(find.text('بيع جديد'), findsOneWidget);
    expect(find.text('إضافة منتج'), findsOneWidget);
    expect(find.text('إضافة مصروف'), findsOneWidget);
    expect(find.text('استلام دفعة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-sale')));
    await tester.pumpAndSettle();
    expect(find.text('سلة البيع'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-action-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-expense')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('expense-category')),
      'مرافق',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-description')),
      'فاتورة الكهرباء',
    );
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '0');
    await tester.tap(find.byKey(const ValueKey('save-expense')));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقماً صالحاً'), findsOneWidget);
    expect(await database.expenses.getAll(), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '125.50',
    );
    await tester.tap(find.byKey(const ValueKey('save-expense')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    final expenses = await tester.runAsync(() => database.expenses.getAll());
    expect(expenses, hasLength(1));
    expect(expenses!.single.amountMinor, 12550);
    final payments = await tester.runAsync(
      () =>
          database.payments.getAll(filters: {'expense_id': expenses.single.id}),
    );
    expect(payments, hasLength(1));
    expect(payments!.single.amountMinor, 12550);
    expect(payments.single.method, PaymentMethod.cash);
  });

  testWidgets('filters recent transactions by search query', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-a-transaction');
    await tester.pumpAndSettle();

    expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
  });

  testWidgets('saves and reloads an offline business profile', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(
        database: database,
        initialSettings: settings,
        dashboardDataLoader: loadEmptyDashboard,
        alertService: _TestAlerts(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حساب المتجر'));
    await tester.pumpAndSettle();
    expect(find.text('ملف النشاط التجاري'), findsOneWidget);
    expect(
      find.text('ملفك محفوظ على هذا الجهاز ويعمل دون اتصال بالإنترنت.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('business-name')),
      'متجري',
    );
    await tester.enterText(find.byKey(const ValueKey('owner-name')), 'سلمى');
    await tester.enterText(find.byKey(const ValueKey('phone')), '+20123456789');
    await tester.tap(find.byKey(const ValueKey('business-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مطعم').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD — دولار أمريكي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإنجليزية').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('allow-negative-stock')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('allow-negative-stock')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notify-low-stock')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notify-low-stock')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حفظ'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    final saved = await tester.runAsync(() => database.settings.get());
    await tester.pumpAndSettle();

    expect(saved!.businessName, 'متجري');
    expect(saved.ownerName, 'سلمى');
    expect(saved.phone, '+20123456789');
    expect(saved.businessType, 'restaurant');
    expect(saved.currencyCode, 'USD');
    expect(saved.localeCode, 'en');
    expect(saved.allowNegativeStock, isTrue);
    expect(saved.notifyLowStock, isTrue);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}

class _TestAlerts implements BusinessAlertService {
  @override
  Future<void> refresh({DateTime? now}) async {}

  @override
  Future<bool> requestPermission() async => true;
}
