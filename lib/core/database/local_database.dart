import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'models/app_settings.dart';
import 'models/category.dart';
import 'models/customer.dart';
import 'models/debt.dart';
import 'models/expense.dart';
import 'inventory_repository.dart';
import 'models/payment.dart';
import 'models/supplier.dart';
import 'models/user.dart';
import 'purchase_repository.dart';
import 'product_repository.dart';
import 'sale_repository.dart';
import 'sqlite_entity_repository.dart';

class LocalDatabase {
  LocalDatabase._(this._database)
    : categories = SqliteEntityRepository<Category>(
        _database,
        table: 'categories',
        fromMap: Category.fromMap,
        searchableColumns: const ['name', 'description'],
        filterableColumns: const {'id', 'is_archived'},
        dateColumn: 'created_at',
      ),
      products = ProductRepository(_database),
      customers = SqliteEntityRepository<Customer>(
        _database,
        table: 'customers',
        fromMap: Customer.fromMap,
        searchableColumns: const ['name', 'phone', 'email'],
        filterableColumns: const {'id', 'phone', 'email'},
        dateColumn: 'created_at',
      ),
      suppliers = SqliteEntityRepository<Supplier>(
        _database,
        table: 'suppliers',
        fromMap: Supplier.fromMap,
        searchableColumns: const ['name', 'phone', 'email'],
        filterableColumns: const {'id', 'phone', 'email'},
        dateColumn: 'created_at',
      ),
      debts = SqliteEntityRepository<Debt>(
        _database,
        table: 'debts',
        fromMap: Debt.fromMap,
        searchableColumns: const ['description', 'direction'],
        filterableColumns: const {
          'id',
          'customer_id',
          'supplier_id',
          'sale_id',
          'purchase_id',
          'direction',
        },
        dateColumn: 'due_date',
      ),
      expenses = SqliteEntityRepository<Expense>(
        _database,
        table: 'expenses',
        fromMap: Expense.fromMap,
        searchableColumns: const ['category', 'description', 'notes'],
        filterableColumns: const {'id', 'user_id', 'category', 'amount_minor'},
        dateColumn: 'date_at',
      ),
      payments = SqliteEntityRepository<Payment>(
        _database,
        table: 'payments',
        fromMap: Payment.fromMap,
        searchableColumns: const ['method', 'reference', 'notes'],
        filterableColumns: const {
          'id',
          'sale_id',
          'purchase_id',
          'debt_id',
          'expense_id',
          'user_id',
          'method',
          'amount_minor',
        },
        dateColumn: 'date_at',
      ),
      users = SqliteEntityRepository<User>(
        _database,
        table: 'users',
        fromMap: User.fromMap,
        searchableColumns: const ['name', 'email', 'role'],
        filterableColumns: const {'id', 'email', 'role', 'is_active'},
        dateColumn: 'created_at',
      ),
      settings = AppSettingsRepository(_database),
      sales = SaleRepository(_database),
      purchases = PurchaseRepository(_database),
      inventory = InventoryRepository(_database);

  static const databaseVersion = 4;
  static const databaseName = 'hesabati.db';

  final Database _database;

  final SqliteEntityRepository<Category> categories;
  final ProductRepository products;
  final SaleRepository sales;
  final PurchaseRepository purchases;
  final SqliteEntityRepository<Customer> customers;
  final SqliteEntityRepository<Supplier> suppliers;
  final SqliteEntityRepository<Debt> debts;
  final SqliteEntityRepository<Expense> expenses;
  final SqliteEntityRepository<Payment> payments;
  final SqliteEntityRepository<User> users;
  final AppSettingsRepository settings;
  final InventoryRepository inventory;

  static Future<LocalDatabase> open({
    String? databasePath,
    DatabaseFactory? factory,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final selectedPath =
        databasePath ?? path.join(await getDatabasesPath(), databaseName);
    final database = await selectedFactory.openDatabase(
      selectedPath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
          await database.execute('PRAGMA busy_timeout = 5000');
        },
        onCreate: (database, version) => _createSchema(database),
        onUpgrade: _upgradeSchema,
      ),
    );
    return LocalDatabase._(database);
  }

  Future<void> close() => _database.close();

  Future<T> transaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) => _database.transaction(action);

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        "ALTER TABLE app_settings ADD COLUMN owner_name TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        "ALTER TABLE app_settings ADD COLUMN phone TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        "ALTER TABLE app_settings ADD COLUMN business_type TEXT NOT NULL DEFAULT 'other'",
      );
    }
    if (oldVersion < 3) {
      await database.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      await database.execute(
        "ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'piece'",
      );
      await database.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
      await database.execute(
        'ALTER TABLE products ADD COLUMN minimum_stock REAL NOT NULL DEFAULT 0',
      );
      await database.execute(
        'UPDATE products SET minimum_stock = low_stock_threshold',
      );
      await database.execute('''
        CREATE UNIQUE INDEX idx_products_barcode
        ON products(barcode COLLATE NOCASE)
        WHERE barcode IS NOT NULL
      ''');
    }
    if (oldVersion < 4) {
      await database.execute('PRAGMA defer_foreign_keys = ON');
      await database.execute('''
        ALTER TABLE app_settings
        ADD COLUMN allow_negative_stock INTEGER NOT NULL DEFAULT 0
        CHECK (allow_negative_stock IN (0, 1))
      ''');
      await database.execute('''
        CREATE TABLE products_new (
          id TEXT PRIMARY KEY,
          category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
          sku TEXT COLLATE NOCASE UNIQUE,
          barcode TEXT COLLATE NOCASE UNIQUE,
          name TEXT NOT NULL,
          description TEXT,
          image_path TEXT,
          unit TEXT NOT NULL DEFAULT 'piece',
          cost_price_minor INTEGER NOT NULL CHECK (cost_price_minor >= 0),
          selling_price_minor INTEGER NOT NULL CHECK (selling_price_minor >= 0),
          stock_quantity REAL NOT NULL DEFAULT 0,
          low_stock_threshold REAL NOT NULL DEFAULT 0
            CHECK (low_stock_threshold >= 0),
          minimum_stock REAL NOT NULL DEFAULT 0 CHECK (minimum_stock >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await database.execute('''
        INSERT INTO products_new (
          id, category_id, sku, barcode, name, description, image_path, unit,
          cost_price_minor, selling_price_minor, stock_quantity,
          low_stock_threshold, minimum_stock, is_active, created_at, updated_at
        )
        SELECT id, category_id, sku, barcode, name, description, image_path, unit,
          cost_price_minor, selling_price_minor, stock_quantity,
          low_stock_threshold, minimum_stock, is_active, created_at, updated_at
        FROM products
      ''');
      await database.execute('DROP TABLE products');
      await database.execute('ALTER TABLE products_new RENAME TO products');
      await database.execute('''
        CREATE INDEX idx_products_category ON products(category_id)
      ''');
      await database.execute('''
        CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)
      ''');
      await database.execute('''
        CREATE UNIQUE INDEX idx_products_barcode
        ON products(barcode COLLATE NOCASE)
        WHERE barcode IS NOT NULL
      ''');
      await _createInventorySchema(database);
    }
  }

  static Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        description TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
        sku TEXT COLLATE NOCASE UNIQUE,
        barcode TEXT COLLATE NOCASE UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        image_path TEXT,
        unit TEXT NOT NULL DEFAULT 'piece',
        cost_price_minor INTEGER NOT NULL CHECK (cost_price_minor >= 0),
        selling_price_minor INTEGER NOT NULL CHECK (selling_price_minor >= 0),
        stock_quantity REAL NOT NULL DEFAULT 0,
        low_stock_threshold REAL NOT NULL DEFAULT 0 CHECK (low_stock_threshold >= 0),
        minimum_stock REAL NOT NULL DEFAULT 0 CHECK (minimum_stock >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT COLLATE NOCASE UNIQUE,
        role TEXT NOT NULL DEFAULT 'owner',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        date_at INTEGER NOT NULL,
        subtotal_minor INTEGER NOT NULL CHECK (subtotal_minor >= 0),
        discount_minor INTEGER NOT NULL CHECK (discount_minor >= 0),
        total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
        order_discount_minor INTEGER NOT NULL CHECK (order_discount_minor >= 0),
        status TEXT NOT NULL,
        notes TEXT,
        CHECK (discount_minor <= subtotal_minor),
        CHECK (total_minor = subtotal_minor - discount_minor)
      )
    ''');
    await database.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL CHECK (quantity > 0),
        selling_price_minor INTEGER NOT NULL CHECK (selling_price_minor >= 0),
        cost_price_minor INTEGER NOT NULL CHECK (cost_price_minor >= 0),
        discount_minor INTEGER NOT NULL CHECK (discount_minor >= 0),
        total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
        CHECK (discount_minor <= ROUND(quantity * selling_price_minor)),
        CHECK (total_minor = ROUND(quantity * selling_price_minor) - discount_minor)
      )
    ''');
    await database.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        supplier_id TEXT REFERENCES suppliers(id) ON DELETE SET NULL,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        date_at INTEGER NOT NULL,
        subtotal_minor INTEGER NOT NULL CHECK (subtotal_minor >= 0),
        discount_minor INTEGER NOT NULL CHECK (discount_minor >= 0),
        total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
        order_discount_minor INTEGER NOT NULL CHECK (order_discount_minor >= 0),
        status TEXT NOT NULL,
        notes TEXT,
        CHECK (discount_minor <= subtotal_minor),
        CHECK (total_minor = subtotal_minor - discount_minor)
      )
    ''');
    await database.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
        product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL CHECK (quantity > 0),
        cost_price_minor INTEGER NOT NULL CHECK (cost_price_minor >= 0),
        discount_minor INTEGER NOT NULL CHECK (discount_minor >= 0),
        total_minor INTEGER NOT NULL CHECK (total_minor >= 0),
        CHECK (discount_minor <= ROUND(quantity * cost_price_minor)),
        CHECK (total_minor = ROUND(quantity * cost_price_minor) - discount_minor)
      )
    ''');
    await _createInventorySchema(database);
    await database.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        customer_id TEXT REFERENCES customers(id) ON DELETE CASCADE,
        supplier_id TEXT REFERENCES suppliers(id) ON DELETE CASCADE,
        sale_id TEXT REFERENCES sales(id) ON DELETE SET NULL,
        purchase_id TEXT REFERENCES purchases(id) ON DELETE SET NULL,
        direction TEXT NOT NULL CHECK (direction IN ('receivable', 'payable')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        due_date INTEGER NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        CHECK (
          (customer_id IS NOT NULL AND supplier_id IS NULL AND direction = 'receivable')
          OR
          (customer_id IS NULL AND supplier_id IS NOT NULL AND direction = 'payable')
        ),
        CHECK (sale_id IS NULL OR purchase_id IS NULL)
      )
    ''');
    await database.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        date_at INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        sale_id TEXT REFERENCES sales(id) ON DELETE RESTRICT,
        purchase_id TEXT REFERENCES purchases(id) ON DELETE RESTRICT,
        debt_id TEXT REFERENCES debts(id) ON DELETE RESTRICT,
        expense_id TEXT REFERENCES expenses(id) ON DELETE RESTRICT,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        method TEXT NOT NULL CHECK (
          method IN ('cash', 'card', 'bankTransfer', 'mobileWallet', 'other')
        ),
        date_at INTEGER NOT NULL,
        reference TEXT,
        notes TEXT,
        CHECK (
          (sale_id IS NOT NULL) +
          (purchase_id IS NOT NULL) +
          (debt_id IS NOT NULL) +
          (expense_id IS NOT NULL) = 1
        )
      )
    ''');
    await database.execute('''
      CREATE TABLE app_settings (
        id TEXT PRIMARY KEY CHECK (id = '1'),
        business_name TEXT NOT NULL DEFAULT '',
        owner_name TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        currency_code TEXT NOT NULL DEFAULT 'EGP'
          CHECK (currency_code GLOB '[A-Z][A-Z][A-Z]'),
        locale_code TEXT NOT NULL DEFAULT 'ar'
          CHECK (locale_code IN ('ar', 'en')),
        business_type TEXT NOT NULL DEFAULT 'other',
        theme_mode TEXT NOT NULL DEFAULT 'system'
          CHECK (theme_mode IN ('system', 'light', 'dark')),
        allow_negative_stock INTEGER NOT NULL DEFAULT 0
          CHECK (allow_negative_stock IN (0, 1)),
        updated_at INTEGER NOT NULL
      )
    ''');
    await database.rawInsert(
      'INSERT INTO app_settings (id, updated_at) VALUES (?, ?)',
      ['1', DateTime.now().toUtc().millisecondsSinceEpoch],
    );

    for (final statement in const [
      'CREATE INDEX idx_products_category ON products(category_id)',
      'CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)',
      'CREATE UNIQUE INDEX idx_products_barcode ON products(barcode COLLATE NOCASE) WHERE barcode IS NOT NULL',
      'CREATE INDEX idx_sales_customer ON sales(customer_id)',
      'CREATE INDEX idx_sales_date ON sales(date_at)',
      'CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)',
      'CREATE INDEX idx_sale_items_product ON sale_items(product_id)',
      'CREATE INDEX idx_purchases_supplier ON purchases(supplier_id)',
      'CREATE INDEX idx_purchases_date ON purchases(date_at)',
      'CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id)',
      'CREATE INDEX idx_purchase_items_product ON purchase_items(product_id)',
      'CREATE INDEX idx_debts_customer ON debts(customer_id)',
      'CREATE INDEX idx_debts_supplier ON debts(supplier_id)',
      'CREATE INDEX idx_debts_due_date ON debts(due_date)',
      'CREATE INDEX idx_expenses_date ON expenses(date_at)',
      'CREATE INDEX idx_expenses_category ON expenses(category)',
      'CREATE INDEX idx_payments_date ON payments(date_at)',
      'CREATE INDEX idx_payments_debt ON payments(debt_id)',
    ]) {
      await database.execute(statement);
    }
  }

  static Future<void> _createInventorySchema(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE inventory_history (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        product_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        quantity REAL NOT NULL CHECK (quantity != 0),
        previous_quantity REAL NOT NULL,
        new_quantity REAL NOT NULL,
        date_at INTEGER NOT NULL,
        note TEXT,
        source_type TEXT,
        source_id TEXT,
        CHECK (ABS(previous_quantity + quantity - new_quantity) < 0.000001)
      )
    ''');
    await database.execute('''
      CREATE TABLE product_returns (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE RESTRICT,
        sale_item_id TEXT NOT NULL REFERENCES sale_items(id) ON DELETE RESTRICT,
        product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        quantity REAL NOT NULL CHECK (quantity > 0),
        date_at INTEGER NOT NULL,
        note TEXT
      )
    ''');
    await database.execute('''
      CREATE INDEX idx_inventory_history_product_date
      ON inventory_history(product_id, date_at DESC)
    ''');
    await database.execute('''
      CREATE INDEX idx_product_returns_sale_item
      ON product_returns(sale_item_id)
    ''');
  }
}

class AppSettingsRepository {
  AppSettingsRepository(this._database)
    : _repository = SqliteEntityRepository<AppSettings>(
        _database,
        table: 'app_settings',
        fromMap: AppSettings.fromMap,
        searchableColumns: const [
          'business_name',
          'owner_name',
          'phone',
          'currency_code',
        ],
        filterableColumns: const {
          'id',
          'currency_code',
          'locale_code',
          'business_type',
          'theme_mode',
        },
        dateColumn: 'updated_at',
      );

  final Database _database;
  final SqliteEntityRepository<AppSettings> _repository;

  Future<AppSettings?> get() => _repository.getById('1');

  Future<void> save(AppSettings settings) async {
    await _database.insert(
      'app_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> delete() async {
    final removed = await _repository.delete('1');
    await _database.insert(
      'app_settings',
      AppSettings().toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return removed;
  }

  Future<List<AppSettings>> search(
    String query, {
    Map<String, Object?> filters = const {},
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int offset = 0,
  }) => _repository.search(
    query,
    filters: filters,
    fromDate: fromDate,
    toDate: toDate,
    limit: limit,
    offset: offset,
    orderBy: 'id',
  );
}
