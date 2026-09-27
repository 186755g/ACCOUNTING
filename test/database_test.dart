import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/database/database.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await LocalDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => database.close());

  test('creates all tables with foreign-key enforcement', () async {
    final tableRows = await database.transaction(
      (transaction) => transaction.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ),
    );
    final tableNames = tableRows.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll([
        'categories',
        'products',
        'sales',
        'sale_items',
        'purchases',
        'purchase_items',
        'customers',
        'suppliers',
        'debts',
        'expenses',
        'payments',
        'users',
        'app_settings',
      ]),
    );
    expect(
      await database.transaction(
        (transaction) => transaction.rawQuery('PRAGMA foreign_keys'),
      ),
      [
        {'foreign_keys': 1},
      ],
    );
    expect(await database.settings.get(), isNotNull);
  });

  test(
    'persists sale items and historical cost independently of product edits',
    () async {
      final category = Category(name: 'مشروبات');
      await database.categories.create(category);
      final product = Product(
        categoryId: category.id,
        sku: 'COFFEE-01',
        name: 'قهوة',
        costPriceMinor: 125,
        sellingPriceMinor: 250,
        stockQuantity: 12,
      );
      await database.products.create(product);

      final saleId = 'sale-1';
      final sale = Sale(
        id: saleId,
        items: [
          SaleItem(
            id: 'sale-item-1',
            saleId: saleId,
            productId: product.id,
            productName: product.name,
            quantity: 2,
            sellingPriceMinor: 250,
            costPriceMinor: product.costPriceMinor,
            discountMinor: 50,
          ),
        ],
        orderDiscountMinor: 25,
      );
      await database.sales.create(sale);

      await database.products.update(
        Product(
          id: product.id,
          categoryId: category.id,
          sku: product.sku,
          name: product.name,
          costPriceMinor: 200,
          sellingPriceMinor: 300,
          stockQuantity: 10,
        ),
      );

      final savedSale = await database.sales.getById(saleId);
      expect(savedSale, isNotNull);
      expect(savedSale!.items, hasLength(1));
      expect(savedSale.items.single.costPriceMinor, 125);
      expect(savedSale.items.single.sellingPriceMinor, 250);
      expect(savedSale.items.single.discountMinor, 50);
      expect(savedSale.items.single.totalMinor, 450);
      expect(savedSale.items.single.costTotalMinor, 250);
      expect(savedSale.items.single.grossProfitMinor, 200);
      expect(savedSale.subtotalMinor, 500);
      expect(savedSale.totalDiscountMinor, 75);
      expect(savedSale.totalMinor, 425);
      expect(savedSale.costTotalMinor, 250);
      expect(savedSale.grossProfitMinor, 175);
    },
  );

  test(
    'sale creation is atomic when a referenced product is missing',
    () async {
      const saleId = 'broken-sale';
      final sale = Sale(
        id: saleId,
        items: [
          SaleItem(
            saleId: saleId,
            productId: 'missing-product',
            productName: 'Missing',
            quantity: 1,
            sellingPriceMinor: 100,
            costPriceMinor: 60,
          ),
        ],
      );

      await expectLater(database.sales.create(sale), throwsA(anything));
      expect(await database.sales.getById(saleId), isNull);
    },
  );

  test('supports CRUD, search, filters, date ranges, and pagination', () async {
    final category = Category(name: 'Beverages');
    await database.categories.create(category);
    final coffee = Product(
      id: 'coffee',
      categoryId: category.id,
      sku: 'C-1',
      name: 'Coffee Beans',
      costPriceMinor: 100,
      sellingPriceMinor: 200,
    );
    final tea = Product(
      id: 'tea',
      categoryId: category.id,
      sku: 'T-1',
      name: 'Green Tea',
      costPriceMinor: 80,
      sellingPriceMinor: 150,
      isActive: false,
    );
    await database.products.create(coffee);
    await database.products.create(tea);

    expect((await database.products.search('coffee')).single.id, 'coffee');
    expect(await database.products.search('Coffee%'), isEmpty);
    expect(
      (await database.products.getAll(
        fromDate: DateTime.utc(2000),
        toDate: DateTime.utc(2100),
      )).length,
      2,
    );
    expect(
      (await database.products.getAll(filters: {'is_active': false})).single.id,
      'tea',
    );
    expect(
      (await database.products.getAll(
        filters: {'category_id': category.id},
        orderBy: 'name',
        limit: 1,
      )).single.id,
      'coffee',
    );
    expect(
      (await database.products.getAll(
        offset: 1,
        limit: 1,
        orderBy: 'name',
      )).single.id,
      'tea',
    );

    await database.products.update(
      Product(
        id: coffee.id,
        categoryId: category.id,
        sku: coffee.sku,
        name: 'Roasted Coffee',
        costPriceMinor: 110,
        sellingPriceMinor: 220,
      ),
    );
    expect(
      (await database.products.getById(coffee.id))!.name,
      'Roasted Coffee',
    );
    expect(await database.products.delete(tea.id), isTrue);
    expect(await database.products.delete(tea.id), isFalse);
    expect(await database.categories.delete(category.id), isTrue);
    expect((await database.products.getById(coffee.id))!.categoryId, isNull);
  });

  test(
    'purchase items round-trip and preserve purchase-time unit cost',
    () async {
      final supplier = Supplier(name: 'Coffee Supplier');
      await database.suppliers.create(supplier);
      final product = Product(
        name: 'Coffee',
        costPriceMinor: 120,
        sellingPriceMinor: 240,
      );
      await database.products.create(product);
      const purchaseId = 'purchase-1';
      final purchase = Purchase(
        id: purchaseId,
        supplierId: supplier.id,
        items: [
          PurchaseItem(
            purchaseId: purchaseId,
            productId: product.id,
            productName: 'Coffee',
            quantity: 3,
            costPriceMinor: 120,
          ),
        ],
      );

      await database.purchases.create(purchase);
      final saved = await database.purchases.getById(purchaseId);

      expect(saved!.items, hasLength(1));
      expect(saved.items.single.costPriceMinor, 120);
      expect(saved.totalMinor, 360);
      expect(
        (await database.purchases.getAll(filters: {'supplier_id': supplier.id}))
            .single
            .id,
        purchaseId,
      );

      final updatedPurchase = Purchase(
        id: purchaseId,
        supplierId: supplier.id,
        items: [
          PurchaseItem(
            purchaseId: purchaseId,
            productId: product.id,
            productName: 'Coffee',
            quantity: 2,
            costPriceMinor: 120,
          ),
        ],
      );
      await database.purchases.update(updatedPurchase);
      expect((await database.purchases.getById(purchaseId))!.totalMinor, 240);
      expect(await database.purchases.delete(purchaseId), isTrue);
      expect(await database.purchases.getById(purchaseId), isNull);
    },
  );

  test('enforces debt direction and one-owner payment relationships', () async {
    final customer = Customer(name: 'Customer');
    await database.customers.create(customer);
    final debt = Debt(
      customerId: customer.id,
      direction: DebtDirection.receivable,
      amountMinor: 1000,
      dueDate: DateTime.utc(2026, 10),
    );
    await database.debts.create(debt);
    final payment = Payment(
      debtId: debt.id,
      amountMinor: 250,
      method: PaymentMethod.cash,
    );
    await database.payments.create(payment);

    expect((await database.debts.search('receivable')).single.id, debt.id);
    expect((await database.payments.getById(payment.id))!.amountMinor, 250);
    expect(
      () => Debt(
        customerId: customer.id,
        direction: DebtDirection.payable,
        amountMinor: 100,
        dueDate: DateTime.utc(2026, 10),
      ),
      throwsArgumentError,
    );
    expect(
      () => Payment(amountMinor: 10, method: PaymentMethod.card),
      throwsArgumentError,
    );
  });

  test('settings are updated and reset instead of remaining deleted', () async {
    await database.settings.save(
      AppSettings(
        businessName: 'My Store',
        ownerName: 'Sam Owner',
        phone: '+20123456789',
        currencyCode: 'USD',
        localeCode: 'en',
        businessType: 'retail',
        themeMode: 'dark',
      ),
    );

    final settings = (await database.settings.get())!;
    expect(settings.businessName, 'My Store');
    expect(settings.ownerName, 'Sam Owner');
    expect(settings.phone, '+20123456789');
    expect(settings.businessType, 'retail');
    expect(await database.settings.delete(), isTrue);
    expect((await database.settings.get())!.currencyCode, 'EGP');
  });

  test(
    'upgrades existing settings with empty local profile defaults',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'hesabati-settings-upgrade-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final legacyPath = path.join(tempDirectory.path, 'legacy.db');
      final legacyDatabase = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await database.execute('''
            CREATE TABLE app_settings (
              id TEXT PRIMARY KEY CHECK (id = '1'),
              business_name TEXT NOT NULL DEFAULT '',
              currency_code TEXT NOT NULL DEFAULT 'EGP',
              locale_code TEXT NOT NULL DEFAULT 'ar',
              theme_mode TEXT NOT NULL DEFAULT 'system',
              updated_at INTEGER NOT NULL
            )
          ''');
            await database.insert('app_settings', {
              'id': '1',
              'business_name': 'Existing shop',
              'currency_code': 'USD',
              'locale_code': 'en',
              'theme_mode': 'dark',
              'updated_at': 1,
            });
          },
        ),
      );
      await legacyDatabase.close();

      final upgradedDatabase = await LocalDatabase.open(
        databasePath: legacyPath,
        factory: databaseFactoryFfi,
      );
      final settings = (await upgradedDatabase.settings.get())!;
      expect(settings.businessName, 'Existing shop');
      expect(settings.currencyCode, 'USD');
      expect(settings.ownerName, isEmpty);
      expect(settings.phone, isEmpty);
      expect(settings.businessType, 'other');
      await upgradedDatabase.close();
    },
  );

  test(
    'persists expenses, users, and expense payments with CRUD filters',
    () async {
      final user = User(name: 'Account owner', email: 'owner@example.com');
      await database.users.create(user);
      final expense = Expense(
        userId: user.id,
        category: 'Utilities',
        description: 'Electricity',
        amountMinor: 850,
        date: DateTime.utc(2026, 9, 1),
      );
      await database.expenses.create(expense);
      final payment = Payment(
        expenseId: expense.id,
        userId: user.id,
        amountMinor: expense.amountMinor,
        method: PaymentMethod.bankTransfer,
      );
      await database.payments.create(payment);

      expect((await database.users.search('owner@example')).single.id, user.id);
      expect(
        (await database.expenses.getAll(
          filters: {'category': 'Utilities'},
          fromDate: DateTime.utc(2026, 9, 1),
          toDate: DateTime.utc(2026, 10, 1),
        )).single.id,
        expense.id,
      );
      expect(
        (await database.payments.getAll(filters: {'expense_id': expense.id}))
            .single
            .method,
        PaymentMethod.bankTransfer,
      );
      await database.payments.delete(payment.id);
      expect(await database.expenses.delete(expense.id), isTrue);
      expect(await database.users.delete(user.id), isTrue);
    },
  );
}
