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

  test(
    'sales and purchases atomically update stock on create, edit, and delete',
    () async {
      final product = Product(
        id: 'stock-lifecycle-product',
        name: 'Stock lifecycle',
        costPriceMinor: 100,
        sellingPriceMinor: 200,
        stockQuantity: 10,
      );
      await database.products.create(product);

      Sale makeSale(double quantity) => Sale(
        id: 'stock-lifecycle-sale',
        items: [
          SaleItem(
            saleId: 'stock-lifecycle-sale',
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            sellingPriceMinor: 200,
            costPriceMinor: 100,
          ),
        ],
      );

      await database.sales.create(makeSale(3));
      expect((await database.products.getById(product.id))!.stockQuantity, 7);
      await database.sales.update(makeSale(2));
      expect((await database.products.getById(product.id))!.stockQuantity, 8);
      expect(await database.sales.delete('stock-lifecycle-sale'), isTrue);
      expect((await database.products.getById(product.id))!.stockQuantity, 10);

      Purchase makePurchase(double quantity) => Purchase(
        id: 'stock-lifecycle-purchase',
        items: [
          PurchaseItem(
            purchaseId: 'stock-lifecycle-purchase',
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            costPriceMinor: 100,
          ),
        ],
      );

      await database.purchases.create(makePurchase(4));
      expect((await database.products.getById(product.id))!.stockQuantity, 14);
      await database.purchases.update(makePurchase(2));
      expect((await database.products.getById(product.id))!.stockQuantity, 12);
      expect(
        await database.purchases.delete('stock-lifecycle-purchase'),
        isTrue,
      );
      expect((await database.products.getById(product.id))!.stockQuantity, 10);

      final history = await database.inventory.getHistory(
        productId: product.id,
      );
      expect(history, isNotEmpty);
      expect(history.first.newQuantity, 10);
      expect(history.any((movement) => movement.reason == 'sale'), isTrue);
      expect(history.any((movement) => movement.reason == 'purchase'), isTrue);
    },
  );

  test(
    'manual stock adjustments are audited and negative stock is opt-in',
    () async {
      final product = Product(
        id: 'adjustable-product',
        name: 'Adjustable',
        costPriceMinor: 100,
        sellingPriceMinor: 200,
        stockQuantity: 4,
        minimumStock: 2,
      );
      await database.products.create(product);

      await expectLater(
        database.inventory.adjustStock(
          productId: product.id,
          quantity: -5,
          reason: 'Damaged goods',
        ),
        throwsStateError,
      );
      expect((await database.products.getById(product.id))!.stockQuantity, 4);

      await database.inventory.adjustStock(
        productId: product.id,
        quantity: -2,
        reason: 'Damaged goods',
        note: 'Two items were broken.',
        date: DateTime.utc(2026, 9, 20),
      );
      final movement = (await database.inventory.getHistory(
        productId: product.id,
      )).singleWhere((entry) => entry.reason == 'Damaged goods');
      expect(movement.reason, 'Damaged goods');
      expect(movement.quantity, -2);
      expect(movement.previousQuantity, 4);
      expect(movement.newQuantity, 2);
      expect(movement.date, DateTime.utc(2026, 9, 20));
      expect(movement.note, 'Two items were broken.');
      expect(
        (await database.inventory.getLowStockProducts()).single['id'],
        product.id,
      );

      const saleId = 'insufficient-sale';
      final sale = Sale(
        id: saleId,
        items: [
          SaleItem(
            saleId: saleId,
            productId: product.id,
            productName: product.name,
            quantity: 3,
            sellingPriceMinor: 200,
            costPriceMinor: 100,
          ),
        ],
      );
      await expectLater(database.sales.create(sale), throwsStateError);
      expect(await database.sales.getById(saleId), isNull);

      await database.settings.save(
        (await database.settings.get())!.copyWith(allowNegativeStock: true),
      );
      await database.sales.create(sale);
      expect((await database.products.getById(product.id))!.stockQuantity, -1);
      expect(
        (await database.inventory.getOutOfStockProducts()).single['id'],
        product.id,
      );
      expect(
        (await database.inventory.getHistory(productId: product.id))
            .first
            .newQuantity,
        -1,
      );
    },
  );

  test(
    'sale returns restore stock once and cannot exceed sold quantity',
    () async {
      final product = Product(
        id: 'returnable-product',
        name: 'Returnable',
        costPriceMinor: 100,
        sellingPriceMinor: 200,
        stockQuantity: 10,
      );
      await database.products.create(product);
      const saleId = 'returnable-sale';
      const saleItemId = 'returnable-sale-item';
      await database.sales.create(
        Sale(
          id: saleId,
          items: [
            SaleItem(
              id: saleItemId,
              saleId: saleId,
              productId: product.id,
              productName: product.name,
              quantity: 3,
              sellingPriceMinor: 200,
              costPriceMinor: 100,
            ),
          ],
        ),
      );
      expect((await database.products.getById(product.id))!.stockQuantity, 7);
      final returned = await database.inventory.returnSaleItem(
        saleItemId: saleItemId,
        quantity: 1,
        note: 'Customer return',
      );
      expect(returned.saleId, saleId);
      expect((await database.products.getById(product.id))!.stockQuantity, 8);
      await expectLater(
        database.inventory.returnSaleItem(
          saleItemId: saleItemId,
          quantity: 2.1,
        ),
        throwsStateError,
      );
      await database.inventory.returnSaleItem(
        saleItemId: saleItemId,
        quantity: 2,
      );
      expect((await database.products.getById(product.id))!.stockQuantity, 10);
      expect(await database.inventory.getReturns(saleId: saleId), hasLength(2));
      expect(
        (await database.inventory.getHistory(productId: product.id))
            .where((movement) => movement.reason == 'sale_return'),
        hasLength(2),
      );
      await expectLater(
        database.inventory.returnSaleItem(
          saleItemId: saleItemId,
          quantity: 0.1,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'checkout records cash, wallet, mixed tenders, and customer debt',
    () async {
      final customer = Customer(name: 'Checkout customer');
      await database.customers.create(customer);
      final product = Product(
        id: 'checkout-product',
        name: 'Checkout product',
        costPriceMinor: 150,
        sellingPriceMinor: 400,
        stockQuantity: 12,
      );
      await database.products.create(product);

      Sale makeSale({
        required String id,
        required double quantity,
        required int orderDiscountMinor,
        String? customerId,
      }) => Sale(
        id: id,
        customerId: customerId,
        orderDiscountMinor: orderDiscountMinor,
        items: [
          SaleItem(
            saleId: id,
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            sellingPriceMinor: product.sellingPriceMinor,
            costPriceMinor: product.costPriceMinor,
          ),
        ],
      );

      final cashSale = makeSale(
        id: 'checkout-cash',
        quantity: 2,
        orderDiscountMinor: 100,
      );
      await database.sales.checkout(
        cashSale,
        tenders: [SaleTender(method: PaymentMethod.cash, amountMinor: 700)],
      );
      expect(cashSale.totalMinor, 700);
      expect(
        (await database.payments.getAll(filters: {'sale_id': cashSale.id}))
            .single
            .method,
        PaymentMethod.cash,
      );

      final walletSale = makeSale(
        id: 'checkout-wallet',
        quantity: 1,
        orderDiscountMinor: 0,
      );
      await database.sales.checkout(
        walletSale,
        tenders: [
          SaleTender(
            method: PaymentMethod.mobileWallet,
            amountMinor: walletSale.totalMinor,
          ),
        ],
      );
      expect(
        (await database.payments.getAll(filters: {'sale_id': walletSale.id}))
            .single
            .method,
        PaymentMethod.mobileWallet,
      );

      final mixedSale = makeSale(
        id: 'checkout-mixed',
        quantity: 2,
        orderDiscountMinor: 0,
        customerId: customer.id,
      );
      await database.sales.checkout(
        mixedSale,
        tenders: const [
          SaleTender(method: PaymentMethod.cash, amountMinor: 300),
          SaleTender(method: PaymentMethod.card, amountMinor: 200),
        ],
      );
      final mixedPayments = await database.payments.getAll(
        filters: {'sale_id': mixedSale.id},
      );
      expect(mixedPayments.map((payment) => payment.amountMinor).toList(), [
        300,
        200,
      ]);
      final debt = (await database.debts.getAll(
        filters: {'sale_id': mixedSale.id},
      )).single;
      expect(debt.amountMinor, mixedSale.totalMinor - 500);
      expect(debt.customerId, customer.id);

      final detail = (await database.sales.getById(mixedSale.id))!;
      expect(detail.items.single.costPriceMinor, 150);
      expect(detail.items.single.sellingPriceMinor, 400);
      await database.products.update(
        Product(
          id: product.id,
          name: product.name,
          costPriceMinor: 250,
          sellingPriceMinor: 500,
          stockQuantity: product.stockQuantity - 5,
        ),
      );
      expect(
        (await database.sales.getById(mixedSale.id))!
            .items
            .single
            .costPriceMinor,
        150,
      );
    },
  );

  test(
    'checkout requires a customer for debt and rolls back failed sales',
    () async {
      final product = Product(
        id: 'checkout-validation-product',
        name: 'Checkout validation',
        costPriceMinor: 50,
        sellingPriceMinor: 100,
        stockQuantity: 1,
      );
      await database.products.create(product);
      const saleId = 'checkout-validation-sale';
      final sale = Sale(
        id: saleId,
        items: [
          SaleItem(
            saleId: saleId,
            productId: product.id,
            productName: product.name,
            quantity: 1,
            sellingPriceMinor: 100,
            costPriceMinor: 50,
          ),
        ],
      );
      await expectLater(
        database.sales.checkout(sale, tenders: const []),
        throwsArgumentError,
      );
      expect(await database.sales.getById(saleId), isNull);
      expect((await database.products.getById(product.id))!.stockQuantity, 1);

      await expectLater(
        database.sales.checkout(
          sale,
          tenders: const [
            SaleTender(method: PaymentMethod.cash, amountMinor: 101),
          ],
        ),
        throwsArgumentError,
      );
      expect(await database.sales.getById(saleId), isNull);
      expect(
        await database.payments.getAll(filters: {'sale_id': saleId}),
        isEmpty,
      );

      await database.sales.checkout(
        sale,
        tenders: const [
          SaleTender(method: PaymentMethod.card, amountMinor: 100),
        ],
      );
      expect((await database.products.getById(product.id))!.stockQuantity, 0);
      expect((await database.sales.getById(saleId))!.totalMinor, 100);
      expect(
        await database.inventory.getHistory(productId: product.id),
        isNotEmpty,
      );
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
    expect(settings.allowNegativeStock, isFalse);
    await database.settings.save(settings.copyWith(allowNegativeStock: true));
    expect((await database.settings.get())!.allowNegativeStock, isTrue);
    expect(await database.settings.delete(), isTrue);
    expect((await database.settings.get())!.currencyCode, 'EGP');
    expect((await database.settings.get())!.allowNegativeStock, isFalse);
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
              CREATE TABLE categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            await database.execute('''
              CREATE TABLE products (
                id TEXT PRIMARY KEY,
                category_id TEXT,
                sku TEXT,
                name TEXT NOT NULL,
                description TEXT,
                cost_price_minor INTEGER NOT NULL,
                selling_price_minor INTEGER NOT NULL,
                stock_quantity REAL NOT NULL DEFAULT 0,
                low_stock_threshold REAL NOT NULL DEFAULT 0,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
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
            await database.insert('products', {
              'id': 'legacy',
              'name': 'Legacy product',
              'cost_price_minor': 10,
              'selling_price_minor': 20,
              'stock_quantity': 2,
              'low_stock_threshold': 5,
              'created_at': 1,
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
      expect(settings.allowNegativeStock, isFalse);
      final legacyProduct = await upgradedDatabase.products.getById('legacy');
      expect(legacyProduct!.minimumStock, 5);
      expect(legacyProduct.name, 'Legacy product');
      await upgradedDatabase.settings.save(
        settings.copyWith(allowNegativeStock: true),
      );
      await upgradedDatabase.inventory.adjustStock(
        productId: legacyProduct.id,
        quantity: -3,
        reason: 'Migration negative-stock check',
      );
      expect(
        (await upgradedDatabase.products.getById(legacyProduct.id))!
            .stockQuantity,
        -1,
      );
      expect(
        await upgradedDatabase.transaction(
          (transaction) => transaction.rawQuery('PRAGMA foreign_key_check'),
        ),
        isEmpty,
      );
      await upgradedDatabase.close();
    },
  );

  test(
    'product repository filters, sorts, and searches barcode fields',
    () async {
      final category = Category(name: 'Drinks');
      await database.categories.create(category);
      final low = Product(
        id: 'product-low',
        name: 'Coffee',
        sku: 'COF-1',
        barcode: '123456789',
        categoryId: category.id,
        costPriceMinor: 150,
        sellingPriceMinor: 300,
        stockQuantity: 2,
        minimumStock: 3,
        unit: 'bag',
      );
      final high = Product(
        id: 'product-high',
        name: 'Tea',
        barcode: '987654321',
        categoryId: category.id,
        costPriceMinor: 100,
        sellingPriceMinor: 250,
        stockQuantity: 10,
        minimumStock: 2,
      );
      await database.products.create(low);
      await database.products.create(high);

      expect(
        (await database.products.browse(query: '123456')).single.id,
        low.id,
      );
      expect(
        (await database.products.browse(
          categoryId: category.id,
          lowStockOnly: true,
        )).map((product) => product.id),
        [low.id],
      );
      expect(
        (await database.products.browse(
          sortBy: ProductSortField.stock,
          descending: true,
        )).map((product) => product.id),
        [high.id, low.id],
      );
      expect(
        (await database.products.browse(sortBy: ProductSortField.purchasePrice))
            .map((product) => product.id),
        [high.id, low.id],
      );
      expect(
        (await database.products.browse(sortBy: ProductSortField.sellingPrice))
            .map((product) => product.id),
        [high.id, low.id],
      );
      expect((await database.products.getById(low.id))!.unit, 'bag');
    },
  );

  test('product SKU and barcode are unique when present', () async {
    await database.products.create(
      Product(
        name: 'First',
        sku: 'ITEM-1',
        barcode: '000123',
        costPriceMinor: 1,
        sellingPriceMinor: 2,
      ),
    );
    await expectLater(
      database.products.create(
        Product(
          name: 'Duplicate SKU',
          sku: 'item-1',
          costPriceMinor: 1,
          sellingPriceMinor: 2,
        ),
      ),
      throwsA(anything),
    );
    await expectLater(
      database.products.create(
        Product(
          name: 'Duplicate barcode',
          barcode: '000123',
          costPriceMinor: 1,
          sellingPriceMinor: 2,
        ),
      ),
      throwsA(anything),
    );
  });

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
