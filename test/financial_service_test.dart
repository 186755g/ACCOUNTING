import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:hesabati/core/services/spreadsheet_export.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase database;
  final periodStart = DateTime.utc(2025, 6);
  final nextPeriod = DateTime.utc(2025, 7);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await LocalDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => database.close());

  test('loads dashboard and its recent daily trend', () async {
    await database.settings.get();
    final service = FinancialService(database);
    final dashboard = await service.getDashboardData(
      now: DateTime(2025, 6, 15),
    );
    expect(dashboard.summary.productCount, 0);
    expect(dashboard.trend, hasLength(7));
  });

  test('calculates low stock, unpaid and overdue alert metrics', () async {
    final lowStock = Product(
      id: 'alert-low',
      name: 'Low stock',
      costPriceMinor: 10,
      sellingPriceMinor: 20,
      stockQuantity: 2,
      minimumStock: 3,
    );
    final outOfStock = Product(
      id: 'alert-out',
      name: 'Out of stock',
      costPriceMinor: 10,
      sellingPriceMinor: 20,
      stockQuantity: 0,
      minimumStock: 3,
    );
    final customer = Customer(name: 'Alert customer');
    final supplier = Supplier(name: 'Alert supplier');
    await database.products.create(lowStock);
    await database.products.create(outOfStock);
    await database.customers.create(customer);
    await database.suppliers.create(supplier);
    await database.debts.create(
      Debt(
        customerId: customer.id,
        direction: DebtDirection.receivable,
        amountMinor: 100,
        dueDate: DateTime.utc(2025, 6, 1),
      ),
    );
    await database.debts.create(
      Debt(
        supplierId: supplier.id,
        direction: DebtDirection.payable,
        amountMinor: 100,
        dueDate: DateTime.utc(2025, 6, 1),
      ),
    );
    final metrics = await FinancialService(database)
        .getNotificationMetrics(now: DateTime(2025, 6, 15));
    expect(metrics.lowStockCount, 1);
    expect(metrics.outOfStockCount, 1);
    expect(metrics.unpaidCustomerCount, 1);
    expect(metrics.overdueCustomerCount, 1);
    expect(metrics.unpaidSupplierCount, 1);
    expect(metrics.overdueSupplierCount, 1);
    expect(metrics.previousDaySalesMinor, 0);
  });

  test(
    'calculates discounts, returns, cost, and expenses in minor units',
    () async {
      final productA = Product(
        id: 'financial-a',
        name: 'Product A',
        costPriceMinor: 40,
        sellingPriceMinor: 101,
        stockQuantity: 10,
      );
      final productB = Product(
        id: 'financial-b',
        name: 'Product B',
        costPriceMinor: 40,
        sellingPriceMinor: 100,
        stockQuantity: 10,
      );
      final customer = Customer(name: 'Financial customer');
      await database.products.create(productA);
      await database.products.create(productB);
      await database.customers.create(customer);

      const saleId = 'financial-sale';
      final saleDate = DateTime.utc(2025, 6, 10);
      const itemAId = 'item-a';
      await database.sales.checkout(
        Sale(
          id: saleId,
          customerId: customer.id,
          date: saleDate,
          orderDiscountMinor: 1,
          items: [
            SaleItem(
              id: itemAId,
              saleId: saleId,
              productId: productA.id,
              productName: productA.name,
              quantity: 1,
              sellingPriceMinor: 101,
              costPriceMinor: 40,
              discountMinor: 1,
            ),
            SaleItem(
              id: 'item-b',
              saleId: saleId,
              productId: productB.id,
              productName: productB.name,
              quantity: 1,
              sellingPriceMinor: 100,
              costPriceMinor: 40,
            ),
          ],
        ),
        tenders: const [
          SaleTender(method: PaymentMethod.cash, amountMinor: 100),
        ],
      );
      await database.inventory.returnSaleItem(
        saleItemId: itemAId,
        quantity: 0.5,
        refundMinor: 50,
        date: DateTime.utc(2025, 6, 20),
      );
      await database.expenses.create(
        Expense(
          category: 'Operating',
          description: 'Test expense',
          amountMinor: 25,
          date: DateTime.utc(2025, 6, 15),
        ),
      );

      final debt = (await database.debts.getAll(filters: {'sale_id': saleId}))
          .single;
      await database.partyAccounts.recordPayment(
        debtId: debt.id,
        amountMinor: 50,
        method: PaymentMethod.card,
        date: DateTime.utc(2025, 6, 25),
      );

      final report = await FinancialService(database)
          .getReport(from: periodStart, to: nextPeriod);
      expect(report.summary.grossSalesMinor, 201);
      expect(report.summary.discountsMinor, 2);
      expect(report.summary.refundsMinor, 50);
      expect(report.summary.netSalesMinor, 149);
      expect(report.summary.costOfGoodsMinor, 60);
      expect(report.summary.grossProfitMinor, 89);
      expect(report.summary.expensesMinor, 25);
      expect(report.summary.netProfitMinor, 64);
      expect(report.summary.customerDebtPaymentsMinor, 50);

      final products = await FinancialService(database)
          .getProductPerformance(from: periodStart, to: nextPeriod);
      expect(
        products.map((item) => item.revenueMinor).reduce((a, b) => a + b),
        149,
      );
      expect(
        products.map((item) => item.costMinor).reduce((a, b) => a + b),
        60,
      );
      expect(
        products.map((item) => item.profitMinor).reduce((a, b) => a + b),
        89,
      );
    },
  );

  test('uses an inclusive start and exclusive end date boundary', () async {
    final product = Product(
      id: 'boundary-product',
      name: 'Boundary product',
      costPriceMinor: 10,
      sellingPriceMinor: 20,
      stockQuantity: 5,
    );
    await database.products.create(product);
    for (final (id, date) in [
      ('before', DateTime.utc(2025, 5, 31, 23, 59, 59)),
      ('at-start', periodStart),
      ('at-end', nextPeriod),
    ]) {
      await database.sales.create(
        Sale(
          id: id,
          date: date,
          items: [
            SaleItem(
              saleId: id,
              productId: product.id,
              productName: product.name,
              quantity: 1,
              sellingPriceMinor: 20,
              costPriceMinor: 10,
            ),
          ],
        ),
      );
    }

    final report = await FinancialService(database)
        .getReport(from: periodStart, to: nextPeriod);
    expect(report.summary.grossSalesMinor, 20);
    expect(report.summary.costOfGoodsMinor, 10);
  });

  test(
    'distributes order discounts without losing or duplicating cents',
    () async {
      final products = [
        Product(
          id: 'penny-a',
          name: 'Penny A',
          costPriceMinor: 0,
          sellingPriceMinor: 1,
          stockQuantity: 1,
        ),
        Product(
          id: 'penny-b',
          name: 'Penny B',
          costPriceMinor: 0,
          sellingPriceMinor: 1,
          stockQuantity: 1,
        ),
      ];
      for (final product in products) {
        await database.products.create(product);
      }
      await database.sales.create(
        Sale(
          id: 'penny-sale',
          date: periodStart.add(const Duration(days: 1)),
          orderDiscountMinor: 1,
          items: [
            for (var index = 0; index < products.length; index++)
              SaleItem(
                id: 'line-$index',
                saleId: 'penny-sale',
                productId: products[index].id,
                productName: products[index].name,
                quantity: 1,
                sellingPriceMinor: 1,
                costPriceMinor: 0,
              ),
          ],
        ),
      );

      final performance = await FinancialService(database)
          .getProductPerformance(from: periodStart, to: nextPeriod);
      expect(
        performance.map((item) => item.revenueMinor).reduce((a, b) => a + b),
        1,
      );
    },
  );

  test(
    'splits returned cost across fractional returns without rounding drift',
    () async {
      final product = Product(
        id: 'fractional-cost',
        name: 'Fractional cost',
        costPriceMinor: 1,
        sellingPriceMinor: 2,
        stockQuantity: 1,
      );
      await database.products.create(product);
      await database.sales.create(
        Sale(
          id: 'fractional-return-sale',
          date: DateTime(2025, 6, 10),
          items: [
            SaleItem(
              id: 'fractional-return-item',
              saleId: 'fractional-return-sale',
              productId: product.id,
              productName: product.name,
              quantity: 1,
              sellingPriceMinor: 2,
              costPriceMinor: 1,
            ),
          ],
        ),
      );
      await database.inventory.returnSaleItem(
        saleItemId: 'fractional-return-item',
        quantity: 0.5,
        refundMinor: 0,
        date: DateTime(2025, 6, 20),
      );
      await database.inventory.returnSaleItem(
        saleItemId: 'fractional-return-item',
        quantity: 0.5,
        refundMinor: 0,
        date: DateTime(2025, 6, 25),
      );

      final trend = await FinancialService(database).getTrend(
        from: DateTime(2025, 6, 1),
        to: DateTime(2025, 7, 1),
        bucket: FinancialBucket.day,
      );
      expect(
        trend
            .map((period) => period.summary.costOfGoodsMinor)
            .reduce((a, b) => a + b),
        0,
      );
    },
  );

  test(
    'tracks supplier debt payments separately from profit and customer debt',
    () async {
      final supplier = Supplier(name: 'Financial supplier');
      final product = Product(
        id: 'supplier-debt-product',
        name: 'Supplier debt product',
        costPriceMinor: 100,
        sellingPriceMinor: 200,
        stockQuantity: 0,
      );
      await database.suppliers.create(supplier);
      await database.products.create(product);
      const purchaseId = 'supplier-debt-purchase';
      await database.purchases.checkout(
        Purchase(
          id: purchaseId,
          supplierId: supplier.id,
          date: DateTime(2025, 6, 10),
          items: [
            PurchaseItem(
              purchaseId: purchaseId,
              productId: product.id,
              productName: product.name,
              quantity: 1,
              costPriceMinor: 100,
            ),
          ],
        ),
        tenders: const [],
      );
      final debt = (await database.debts.getAll(
        filters: {'purchase_id': purchaseId},
      )).single;
      await database.partyAccounts.recordPayment(
        debtId: debt.id,
        amountMinor: 30,
        method: PaymentMethod.cash,
        date: DateTime(2025, 6, 20),
      );

      final report = await FinancialService(
        database,
      ).getReport(from: periodStart, to: nextPeriod, supplierId: supplier.id);
      expect(report.summary.supplierDebtPaymentsMinor, 30);
      expect(report.summary.customerDebtPaymentsMinor, 0);
      expect(report.summary.netProfitMinor, 0);
      expect(report.supplierOutstandingMinor, 70);
    },
  );

  test('paginates product and customer analytics with offset-based queries',
      () async {
    final service = FinancialService(database);
    final products = [
      Product(
        id: 'page-p-1',
        name: 'Page Product 1',
        costPriceMinor: 10,
        sellingPriceMinor: 20,
        stockQuantity: 5,
      ),
      Product(
        id: 'page-p-2',
        name: 'Page Product 2',
        costPriceMinor: 15,
        sellingPriceMinor: 30,
        stockQuantity: 5,
      ),
      Product(
        id: 'page-p-3',
        name: 'Page Product 3',
        costPriceMinor: 20,
        sellingPriceMinor: 40,
        stockQuantity: 5,
      ),
      Product(
        id: 'page-p-4',
        name: 'Page Product 4',
        costPriceMinor: 25,
        sellingPriceMinor: 50,
        stockQuantity: 5,
      ),
      Product(
        id: 'page-p-5',
        name: 'Page Product 5',
        costPriceMinor: 30,
        sellingPriceMinor: 60,
        stockQuantity: 5,
      ),
    ];
    for (final product in products) {
      await database.products.create(product);
    }

    for (var index = 0; index < 5; index++) {
      final customer = Customer(name: 'Page customer $index');
      await database.customers.create(customer);
      await database.sales.checkout(
        Sale(
          id: 'page-sale-$index',
          customerId: customer.id,
          date: periodStart.add(Duration(days: index)),
          items: [
            SaleItem(
              id: 'page-item-$index',
              saleId: 'page-sale-$index',
              productId: products[index].id,
              productName: products[index].name,
              quantity: 1,
              sellingPriceMinor: products[index].sellingPriceMinor,
              costPriceMinor: products[index].costPriceMinor,
            ),
          ],
        ),
        tenders: [
          SaleTender(
            method: PaymentMethod.cash,
            amountMinor: products[index].sellingPriceMinor,
          ),
        ],
      );
    }

    final firstProductPage = await service.getProductPerformance(
      from: periodStart,
      to: nextPeriod,
      limit: 2,
    );
    final secondProductPage = await service.getProductPerformance(
      from: periodStart,
      to: nextPeriod,
      limit: 2,
      offset: 2,
    );
    expect(firstProductPage, hasLength(2));
    expect(secondProductPage, hasLength(2));
    final firstIds = firstProductPage.map((item) => item.productId).toSet();
    final secondIds = secondProductPage.map((item) => item.productId).toSet();
    expect(firstIds.intersection(secondIds), isEmpty);

    final firstCustomerPage = await service.getCustomerPerformance(
      from: periodStart,
      to: nextPeriod,
      limit: 2,
    );
    final secondCustomerPage = await service.getCustomerPerformance(
      from: periodStart,
      to: nextPeriod,
      limit: 2,
      offset: 2,
    );
    expect(firstCustomerPage, hasLength(2));
    expect(secondCustomerPage, hasLength(2));
    final firstCustomerIds = firstCustomerPage
        .map((item) => item.customerId)
        .toSet();
    final secondCustomerIds = secondCustomerPage
        .map((item) => item.customerId)
        .toSet();
    expect(firstCustomerIds.intersection(secondCustomerIds), isEmpty);
  });

  test('export rows include the full filtered report dataset', () async {
    final service = FinancialService(database);
    final product = Product(
      id: 'export-product',
      name: 'Export Product',
      costPriceMinor: 15,
      sellingPriceMinor: 30,
      stockQuantity: 4,
    );
    final customer = Customer(name: 'Export Customer');
    await database.products.create(product);
    await database.customers.create(customer);
    await database.sales.checkout(
      Sale(
        id: 'export-sale',
        customerId: customer.id,
        date: DateTime.utc(2025, 6, 10),
        items: [
          SaleItem(
            id: 'export-item',
            saleId: 'export-sale',
            productId: product.id,
            productName: product.name,
            quantity: 2,
            sellingPriceMinor: 30,
            costPriceMinor: 15,
          ),
        ],
      ),
      tenders: const [SaleTender(method: PaymentMethod.cash, amountMinor: 60)],
    );

    final report = await service.getReport(
      from: periodStart,
      to: nextPeriod,
      customerId: customer.id,
    );
    final rows = [
      ['Metric', 'Amount'],
      ...report.products.map(
        (item) => [item.productName, item.quantity.toString()],
      ),
    ];

    final bytes = spreadsheetXlsxBytes(rows, rightToLeft: false);
    expect(report.products, hasLength(1));
    expect(bytes, isNotEmpty);
  });

  test('tracks account balances and daily reconciliation variance', () async {
    final cash = FinancialAccount(
      name: 'Cash drawer',
      type: FinancialAccountType.cash,
      openingBalanceMinor: 1000,
    );
    await database.financialAccounts.create(cash);

    await database.financialAccounts.recordMovement(
      accountId: cash.id,
      direction: AccountMovementDirection.credit,
      amountMinor: 750,
      description: 'Sale collection',
      date: DateTime.utc(2025, 6, 11),
    );
    await database.financialAccounts.recordMovement(
      accountId: cash.id,
      direction: AccountMovementDirection.debit,
      amountMinor: 250,
      description: 'Office expense',
      date: DateTime.utc(2025, 6, 12),
    );

    expect(await database.financialAccounts.getBalance(cash.id), 1500);

    final reconciliation = await database.financialAccounts.reconcileDaily(
      accountId: cash.id,
      date: DateTime.utc(2025, 6, 12),
      actualBalanceMinor: 1490,
      note: 'Cash count mismatch',
    );
    expect(reconciliation.bookBalanceMinor, 1500);
    expect(reconciliation.actualBalanceMinor, 1490);
    expect(reconciliation.varianceMinor, -10);
    expect(reconciliation.status, 'variance');
  });
}
