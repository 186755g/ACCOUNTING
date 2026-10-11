import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../database/models/debt.dart';
import '../database/models/model_utils.dart';

enum FinancialBucket { day, week, month, year }

const _adjustedSaleItemsCte = '''
line_totals AS (
  SELECT sale_id, SUM(total_minor) AS total_minor
  FROM sale_items GROUP BY sale_id
),
discount_shares AS (
  SELECT si.id, si.sale_id,
    CASE WHEN totals.total_minor > 0
      THEN CAST(s.order_discount_minor * si.total_minor / totals.total_minor AS INTEGER)
      ELSE 0 END AS share_minor,
    CASE WHEN si.id = (
      SELECT MIN(first_item.id) FROM sale_items first_item
      WHERE first_item.sale_id = si.sale_id
    ) THEN s.order_discount_minor - COALESCE((
      SELECT SUM(CASE WHEN sibling_totals.total_minor > 0
        THEN CAST(s.order_discount_minor * sibling.total_minor /
          sibling_totals.total_minor AS INTEGER)
        ELSE 0 END)
      FROM sale_items sibling
      JOIN line_totals sibling_totals ON sibling_totals.sale_id = sibling.sale_id
      WHERE sibling.sale_id = si.sale_id
    ), 0) ELSE 0 END AS residual_minor
  FROM sale_items si
  JOIN sales s ON s.id = si.sale_id
  JOIN line_totals totals ON totals.sale_id = s.id
),
adjusted_items AS (
  SELECT si.*, s.date_at, s.customer_id,
    si.total_minor - shares.share_minor - shares.residual_minor
      AS net_total_minor
  FROM sale_items si
  JOIN sales s ON s.id = si.sale_id
  JOIN discount_shares shares ON shares.id = si.id
)
''';

class FinancialService {
  FinancialService(this._database);

  final LocalDatabase _database;

  Future<DashboardData> getDashboardData({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final summary = await getDashboardSummary(now: clock);
    final trend = await getTrend(
      from: DateTime(clock.year, clock.month, clock.day - 6),
      to: DateTime(clock.year, clock.month, clock.day + 1),
      bucket: FinancialBucket.day,
    );
    return DashboardData(summary: summary, trend: trend);
  }

  Future<FinancialReport> getReport({
    required DateTime from,
    required DateTime to,
    String? customerId,
    String? supplierId,
    String? categoryId,
  }) async {
    _validateRange(from, to);
    return _database.transaction((transaction) async {
      final summary = await _calculate(
        transaction,
        from.toUtc(),
        to.toUtc(),
        customerId: customerId,
        supplierId: supplierId,
      );
      final expenseRows = await transaction.rawQuery(
        '''
        SELECT category, COALESCE(SUM(amount_minor), 0) AS amount
        FROM expenses
        WHERE date_at >= ? AND date_at < ?
        GROUP BY category ORDER BY amount DESC, category COLLATE NOCASE
        ''',
        [dateToDatabase(from), dateToDatabase(to)],
      );
      final supplierDebt = await _outstanding(
        transaction,
        ownerColumn: 'supplier_id',
        ownerId: supplierId,
        direction: DebtDirection.payable,
      );
      final customerDebt = await _outstanding(
        transaction,
        ownerColumn: 'customer_id',
        ownerId: customerId,
        direction: DebtDirection.receivable,
      );
      final productRows = await transaction.rawQuery(
        '''
        WITH $_adjustedSaleItemsCte
        SELECT si.product_id, si.product_name,
          COALESCE(SUM(si.quantity), 0) AS quantity,
          COALESCE(SUM(si.net_total_minor), 0) AS revenue,
          COALESCE(SUM(ROUND(si.quantity * si.cost_price_minor)), 0) AS cost,
          COALESCE(SUM((
            SELECT SUM(pr.refund_minor)
            FROM product_returns pr WHERE pr.sale_item_id = si.id
              AND pr.date_at >= ? AND pr.date_at < ?
          )), 0) AS refunds,
          COALESCE(SUM((
            SELECT SUM(pr.returned_cost_minor)
            FROM product_returns pr WHERE pr.sale_item_id = si.id
              AND pr.date_at >= ? AND pr.date_at < ?
          )), 0) AS returned_cost
        FROM adjusted_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.date_at >= ? AND si.date_at < ?
          AND (? IS NULL OR si.customer_id = ?)
          AND (? IS NULL OR p.category_id = ?)
        GROUP BY si.product_id, si.product_name
        ORDER BY revenue DESC, si.product_name COLLATE NOCASE
        ''',
        [
          dateToDatabase(from),
          dateToDatabase(to),
          dateToDatabase(from),
          dateToDatabase(to),
          dateToDatabase(from),
          dateToDatabase(to),
          customerId,
          customerId,
          categoryId,
          categoryId,
        ],
      );
      final products = productRows
          .map((row) {
            final revenue = _roundMoney(row['revenue']);
            final refunds = _roundMoney(row['refunds']);
            final cost = _roundMoney(row['cost']);
            final returnedCost = _roundMoney(row['returned_cost']);
            return ProductFinancialResult(
              productId: requiredString(row, 'product_id'),
              productName: requiredString(row, 'product_name'),
              quantity: requiredDouble(row, 'quantity'),
              revenueMinor: revenue - refunds,
              costMinor: cost - returnedCost,
              profitMinor: revenue - refunds - cost + returnedCost,
            );
          })
          .toList(growable: false);
      final inventory = await transaction.rawQuery('''
        SELECT COALESCE(SUM(ROUND(p.stock_quantity * p.cost_price_minor)), 0)
          AS value,
          COALESCE(SUM(ROUND(p.stock_quantity * p.selling_price_minor)), 0)
          AS retail_value
        FROM products p WHERE p.is_active = 1
        ${categoryId == null ? '' : 'AND p.category_id = ?'}
        ''', categoryId == null ? const [] : [categoryId]);
      return FinancialReport(
        summary: summary,
        expensesByCategory: {
          for (final row in expenseRows)
            requiredString(row, 'category'): requiredInt(row, 'amount'),
        },
        products: products,
        customerOutstandingMinor: customerDebt,
        supplierOutstandingMinor: supplierDebt,
        inventoryCostValueMinor: _roundMoney(inventory.single['value']),
        inventoryRetailValueMinor: _roundMoney(
          inventory.single['retail_value'],
        ),
      );
    });
  }

  Future<DashboardSummary> getDashboardSummary({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final from = DateTime(clock.year, clock.month, clock.day).toUtc();
    final to = DateTime(clock.year, clock.month, clock.day + 1).toUtc();
    return _database.transaction((transaction) async {
      final financial = await _calculate(transaction, from, to);
      final productRows = await transaction.rawQuery('''
        SELECT COUNT(*) AS total,
          COALESCE(SUM(CASE WHEN stock_quantity <= minimum_stock THEN 1 ELSE 0 END), 0)
            AS low_stock
        FROM products WHERE is_active = 1
      ''');
      final debts = await transaction.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN d.direction = 'receivable' THEN
            MAX(0, d.amount_minor - COALESCE((
              SELECT SUM(p.amount_minor) FROM payments p WHERE p.debt_id = d.id
            ), 0)) ELSE 0 END), 0) AS customer_balance,
          COALESCE(SUM(CASE WHEN d.direction = 'payable' THEN
            MAX(0, d.amount_minor - COALESCE((
              SELECT SUM(p.amount_minor) FROM payments p WHERE p.debt_id = d.id
            ), 0)) ELSE 0 END), 0) AS supplier_balance
        FROM debts d
      ''');
      final recent = await transaction.rawQuery('''
        SELECT s.id, s.date_at, s.total_minor,
          COALESCE(c.name, '') AS customer_name
        FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
        WHERE s.status = 'completed'
        ORDER BY s.date_at DESC, s.rowid DESC LIMIT 8
        ''');
      final salesCount = await transaction.rawQuery(
        'SELECT COUNT(*) AS total FROM sales '
        "WHERE status = 'completed' AND date_at >= ? AND date_at < ?",
        [dateToDatabase(from), dateToDatabase(to)],
      );
      return DashboardSummary(
        financial: financial,
        productCount: requiredInt(productRows.single, 'total'),
        lowStockCount: requiredInt(productRows.single, 'low_stock'),
        customerOutstandingMinor: requiredInt(debts.single, 'customer_balance'),
        supplierOutstandingMinor: requiredInt(debts.single, 'supplier_balance'),
        todaySalesCount: requiredInt(salesCount.single, 'total'),
        recentSales: recent
            .map(
              (row) => RecentFinancialSale(
                id: requiredString(row, 'id'),
                date: dateFromDatabase(row['date_at']),
                totalMinor: requiredInt(row, 'total_minor'),
                customerName: nullableString(row, 'customer_name'),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  Future<AlertMetrics> getNotificationMetrics({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final startToday = DateTime(clock.year, clock.month, clock.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));
    final values = await _database.transaction((transaction) async {
      final stock = await transaction.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN stock_quantity > 0
            AND stock_quantity <= minimum_stock THEN 1 ELSE 0 END), 0)
            AS low_stock,
          COALESCE(SUM(CASE WHEN stock_quantity <= 0 THEN 1 ELSE 0 END), 0)
            AS out_of_stock
        FROM products WHERE is_active = 1
      ''');
      final debts = await transaction.rawQuery(
        '''
        SELECT
          COUNT(DISTINCT CASE WHEN direction = 'receivable' AND balance > 0
            THEN customer_id END)
            AS unpaid_customers,
          COUNT(DISTINCT CASE WHEN direction = 'receivable' AND balance > 0
            AND due_date < ?
            THEN customer_id END) AS overdue_customers,
          COUNT(DISTINCT CASE WHEN direction = 'payable' AND balance > 0
            THEN supplier_id END)
            AS unpaid_suppliers,
          COUNT(DISTINCT CASE WHEN direction = 'payable' AND balance > 0
            AND due_date < ?
            THEN supplier_id END) AS overdue_suppliers
        FROM (
          SELECT d.customer_id, d.supplier_id, d.due_date,
            d.direction,
            MAX(0, d.amount_minor - COALESCE(SUM(p.amount_minor), 0))
              AS balance
          FROM debts d LEFT JOIN payments p ON p.debt_id = d.id
          GROUP BY d.id
        )
        ''',
        [dateToDatabase(startToday), dateToDatabase(startToday)],
      );
      final sales = await transaction.rawQuery(
        '''
        SELECT COALESCE(SUM(total_minor), 0) AS sales
        FROM sales
        WHERE status = 'completed' AND date_at >= ? AND date_at < ?
        ''',
        [dateToDatabase(startYesterday), dateToDatabase(startToday)],
      );
      return (stock: stock.single, debts: debts.single, sales: sales.single);
    });
    return AlertMetrics(
      lowStockCount: requiredInt(values.stock, 'low_stock'),
      outOfStockCount: requiredInt(values.stock, 'out_of_stock'),
      unpaidCustomerCount: requiredInt(values.debts, 'unpaid_customers'),
      overdueCustomerCount: requiredInt(values.debts, 'overdue_customers'),
      unpaidSupplierCount: requiredInt(values.debts, 'unpaid_suppliers'),
      overdueSupplierCount: requiredInt(values.debts, 'overdue_suppliers'),
      previousDaySalesMinor: _roundMoney(values.sales['sales']),
    );
  }

  Future<List<FinancialPeriod>> getTrend({
    required DateTime from,
    required DateTime to,
    required FinancialBucket bucket,
  }) async {
    _validateRange(from, to);
    final starts = _bucketStarts(from, to, bucket);
    final fromUtc = from.toUtc();
    final toUtc = to.toUtc();
    final rows = await _database.transaction((transaction) async {
      final sales = await transaction.rawQuery(
        '''
        SELECT date_at, subtotal_minor, discount_minor, total_minor
        FROM sales WHERE status = 'completed' AND date_at >= ? AND date_at < ?
        ''',
        [dateToDatabase(fromUtc), dateToDatabase(toUtc)],
      );
      final costs = await transaction.rawQuery(
        '''
        SELECT s.date_at, COALESCE(SUM(ROUND(si.quantity * si.cost_price_minor)), 0)
          AS cost
        FROM sales s JOIN sale_items si ON si.sale_id = s.id
        WHERE s.status = 'completed' AND s.date_at >= ? AND s.date_at < ?
        GROUP BY s.id
        ''',
        [dateToDatabase(fromUtc), dateToDatabase(toUtc)],
      );
      final expenses = await transaction.rawQuery(
        'SELECT date_at, amount_minor FROM expenses '
        'WHERE date_at >= ? AND date_at < ?',
        [dateToDatabase(fromUtc), dateToDatabase(toUtc)],
      );
      final returns = await transaction.rawQuery(
        '''
        SELECT pr.date_at,
          pr.refund_minor AS refund,
          pr.returned_cost_minor AS returned_cost
        FROM product_returns pr
        WHERE pr.date_at >= ? AND pr.date_at < ?
        ''',
        [dateToDatabase(fromUtc), dateToDatabase(toUtc)],
      );
      return (sales, costs, expenses, returns);
    });
    final values = <DateTime, _PeriodAccumulator>{
      for (final start in starts) start: _PeriodAccumulator(),
    };
    for (final row in rows.$1) {
      final accumulator =
          values[_bucketStart(dateFromDatabase(row['date_at']), bucket)];
      if (accumulator == null) continue;
      accumulator.grossSales += requiredInt(row, 'subtotal_minor');
      accumulator.discounts += requiredInt(row, 'discount_minor');
    }
    for (final row in rows.$2) {
      final accumulator =
          values[_bucketStart(dateFromDatabase(row['date_at']), bucket)];
      if (accumulator != null) {
        accumulator.cost += _roundMoney(row['cost']);
      }
    }
    for (final row in rows.$3) {
      final accumulator =
          values[_bucketStart(dateFromDatabase(row['date_at']), bucket)];
      if (accumulator != null) {
        accumulator.expenses += requiredInt(row, 'amount_minor');
      }
    }
    for (final row in rows.$4) {
      final accumulator =
          values[_bucketStart(dateFromDatabase(row['date_at']), bucket)];
      if (accumulator != null) {
        accumulator.refunds += _roundMoney(row['refund']);
        accumulator.returnedCost += _roundMoney(row['returned_cost']);
      }
    }
    return [
      for (final entry in values.entries)
        FinancialPeriod(
          start: entry.key,
          summary: _summaryFromAccumulator(entry.value),
        ),
    ];
  }

  Future<List<ProductFinancialResult>> getProductPerformance({
    required DateTime from,
    required DateTime to,
    String? categoryId,
    int? limit,
    bool leastSelling = false,
  }) async {
    _validateRange(from, to);
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit');
    }
    final rows = await _database.transaction(
      (transaction) => transaction.rawQuery(
        '''
      WITH $_adjustedSaleItemsCte
      SELECT si.product_id, si.product_name,
        SUM(si.quantity) AS quantity,
        SUM(si.net_total_minor) - COALESCE(SUM((
          SELECT SUM(pr.refund_minor)
          FROM product_returns pr WHERE pr.sale_item_id = si.id
            AND pr.date_at >= ? AND pr.date_at < ?
        )), 0) AS revenue,
        SUM(ROUND(si.quantity * si.cost_price_minor)) - COALESCE(SUM((
          SELECT SUM(pr.returned_cost_minor)
          FROM product_returns pr WHERE pr.sale_item_id = si.id
            AND pr.date_at >= ? AND pr.date_at < ?
        )), 0) AS cost
      FROM adjusted_items si JOIN products p ON p.id = si.product_id
      WHERE si.date_at >= ? AND si.date_at < ?
        AND (? IS NULL OR p.category_id = ?)
      GROUP BY si.product_id, si.product_name
      ORDER BY quantity ${leastSelling ? 'ASC' : 'DESC'}, revenue DESC
      ${limit == null ? '' : 'LIMIT $limit'}
        ''',
        [
          dateToDatabase(from),
          dateToDatabase(to),
          dateToDatabase(from),
          dateToDatabase(to),
          dateToDatabase(from),
          dateToDatabase(to),
          categoryId,
          categoryId,
        ],
      ),
    );
    return rows
        .map((row) {
          final revenue = _roundMoney(row['revenue']);
          final cost = _roundMoney(row['cost']);
          return ProductFinancialResult(
            productId: requiredString(row, 'product_id'),
            productName: requiredString(row, 'product_name'),
            quantity: requiredDouble(row, 'quantity'),
            revenueMinor: revenue,
            costMinor: cost,
            profitMinor: revenue - cost,
          );
        })
        .toList(growable: false);
  }

  Future<List<CustomerFinancialResult>> getCustomerPerformance({
    required DateTime from,
    required DateTime to,
    int limit = 20,
  }) async {
    _validateRange(from, to);
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final rows = await _database.transaction(
      (transaction) => transaction.rawQuery(
        '''
      SELECT c.id, c.name, COUNT(s.id) AS order_count,
        COALESCE(SUM(s.total_minor), 0) AS total
      FROM customers c LEFT JOIN sales s ON s.customer_id = c.id
        AND s.status = 'completed' AND s.date_at >= ? AND s.date_at < ?
      GROUP BY c.id ORDER BY total DESC, c.name COLLATE NOCASE LIMIT ?
        ''',
        [dateToDatabase(from), dateToDatabase(to), limit],
      ),
    );
    return rows
        .map(
          (row) => CustomerFinancialResult(
            customerId: requiredString(row, 'id'),
            name: requiredString(row, 'name'),
            orderCount: requiredInt(row, 'order_count'),
            totalMinor: requiredInt(row, 'total'),
          ),
        )
        .toList(growable: false);
  }

  Future<int> _outstanding(
    Transaction transaction, {
    required String ownerColumn,
    required String? ownerId,
    required DebtDirection direction,
  }) async {
    final rows = await transaction.rawQuery(
      '''
      SELECT COALESCE(SUM(MAX(0, d.amount_minor - COALESCE((
        SELECT SUM(p.amount_minor) FROM payments p WHERE p.debt_id = d.id
      ), 0))), 0) AS total
      FROM debts d WHERE d.direction = ?
        AND (? IS NULL OR d.$ownerColumn = ?)
      ''',
      [direction.name, ownerId, ownerId],
    );
    return requiredInt(rows.single, 'total');
  }

  Future<FinancialSummary> _calculate(
    Transaction transaction,
    DateTime from,
    DateTime to, {
    String? customerId,
    String? supplierId,
  }) async {
    final args = [
      dateToDatabase(from),
      dateToDatabase(to),
      customerId,
      customerId,
    ];
    final sales = await transaction.rawQuery('''
      SELECT COALESCE(SUM(subtotal_minor), 0) AS gross,
        COALESCE(SUM(discount_minor), 0) AS discounts
      FROM sales
      WHERE status = 'completed' AND date_at >= ? AND date_at < ?
        AND (? IS NULL OR customer_id = ?)
      ''', args);
    final cost = await transaction.rawQuery('''
      SELECT COALESCE(SUM(ROUND(si.quantity * si.cost_price_minor)), 0) AS total
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.date_at >= ? AND s.date_at < ?
        AND (? IS NULL OR s.customer_id = ?)
      ''', args);
    final returns = await transaction.rawQuery(
      '''
    WITH returned_items AS (
      SELECT sale_item_id, SUM(refund_minor) AS refund_minor,
        SUM(returned_cost_minor) AS returned_cost_minor
      FROM product_returns WHERE date_at >= ? AND date_at < ?
      GROUP BY sale_item_id
    )
    SELECT COALESCE(SUM(r.refund_minor), 0) AS refund,
      COALESCE(SUM(r.returned_cost_minor), 0) AS returned_cost
    FROM returned_items r
    JOIN sale_items si ON si.id = r.sale_item_id
    JOIN sales s ON s.id = si.sale_id
    WHERE (? IS NULL OR s.customer_id = ?)
    ''',
      [dateToDatabase(from), dateToDatabase(to), customerId, customerId],
    );
    final expenses = await transaction.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses '
      'WHERE date_at >= ? AND date_at < ?',
      [dateToDatabase(from), dateToDatabase(to)],
    );
    final debtPayments = await transaction.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN d.direction = 'receivable' THEN p.amount_minor ELSE 0 END), 0)
          AS customer_payments,
        COALESCE(SUM(CASE WHEN d.direction = 'payable' THEN p.amount_minor ELSE 0 END), 0)
          AS supplier_payments
      FROM payments p JOIN debts d ON d.id = p.debt_id
      WHERE p.date_at >= ? AND p.date_at < ?
        AND (
          (d.direction = 'receivable' AND (? IS NULL OR d.customer_id = ?))
          OR (d.direction = 'payable' AND (? IS NULL OR d.supplier_id = ?))
        )
      ''',
      [
        dateToDatabase(from),
        dateToDatabase(to),
        customerId,
        customerId,
        supplierId,
        supplierId,
      ],
    );
    final sale = sales.single;
    final returnRow = returns.single;
    final accumulator = _PeriodAccumulator()
      ..grossSales = requiredInt(sale, 'gross')
      ..discounts = requiredInt(sale, 'discounts')
      ..cost = _roundMoney(cost.single['total'])
      ..refunds = _roundMoney(returnRow['refund'])
      ..returnedCost = _roundMoney(returnRow['returned_cost'])
      ..expenses = requiredInt(expenses.single, 'total');
    return _summaryFromAccumulator(
      accumulator,
      customerDebtPaymentsMinor: requiredInt(
        debtPayments.single,
        'customer_payments',
      ),
      supplierDebtPaymentsMinor: requiredInt(
        debtPayments.single,
        'supplier_payments',
      ),
    );
  }

  static FinancialSummary _summaryFromAccumulator(
    _PeriodAccumulator value, {
    int customerDebtPaymentsMinor = 0,
    int supplierDebtPaymentsMinor = 0,
  }) {
    final netSales = value.grossSales - value.discounts - value.refunds;
    final cogs = value.cost - value.returnedCost;
    final grossProfit = netSales - cogs;
    return FinancialSummary(
      grossSalesMinor: value.grossSales,
      discountsMinor: value.discounts,
      refundsMinor: value.refunds,
      costOfGoodsMinor: cogs,
      expensesMinor: value.expenses,
      grossProfitMinor: grossProfit,
      netProfitMinor: grossProfit - value.expenses,
      customerDebtPaymentsMinor: customerDebtPaymentsMinor,
      supplierDebtPaymentsMinor: supplierDebtPaymentsMinor,
    );
  }

  static int _roundMoney(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.round();
    throw FormatException('Expected a numeric money value, got $value.');
  }

  static void _validateRange(DateTime from, DateTime to) {
    if (!from.isBefore(to)) {
      throw ArgumentError('from must be earlier than exclusive to.');
    }
  }

  static List<DateTime> _bucketStarts(
    DateTime from,
    DateTime to,
    FinancialBucket bucket,
  ) {
    var current = _bucketStart(from, bucket);
    final result = <DateTime>[];
    while (current.isBefore(to)) {
      result.add(current);
      current = switch (bucket) {
        FinancialBucket.day => DateTime(
          current.year,
          current.month,
          current.day + 1,
        ),
        FinancialBucket.week => DateTime(
          current.year,
          current.month,
          current.day + 7,
        ),
        FinancialBucket.month => DateTime(current.year, current.month + 1),
        FinancialBucket.year => DateTime(current.year + 1),
      };
    }
    return result;
  }

  static DateTime _bucketStart(DateTime value, FinancialBucket bucket) {
    final local = value.toLocal();
    return switch (bucket) {
      FinancialBucket.day => DateTime(local.year, local.month, local.day),
      FinancialBucket.week => DateTime(
        local.year,
        local.month,
        local.day - (local.weekday - DateTime.monday),
      ),
      FinancialBucket.month => DateTime(local.year, local.month),
      FinancialBucket.year => DateTime(local.year),
    };
  }
}

class _PeriodAccumulator {
  int grossSales = 0;
  int discounts = 0;
  int refunds = 0;
  int cost = 0;
  int returnedCost = 0;
  int expenses = 0;
}

class FinancialSummary {
  const FinancialSummary({
    required this.grossSalesMinor,
    required this.discountsMinor,
    required this.refundsMinor,
    required this.costOfGoodsMinor,
    required this.expensesMinor,
    required this.grossProfitMinor,
    required this.netProfitMinor,
    required this.customerDebtPaymentsMinor,
    required this.supplierDebtPaymentsMinor,
  });

  final int grossSalesMinor;
  final int discountsMinor;
  final int refundsMinor;
  final int costOfGoodsMinor;
  final int expensesMinor;
  final int grossProfitMinor;
  final int netProfitMinor;
  final int customerDebtPaymentsMinor;
  final int supplierDebtPaymentsMinor;

  int get netSalesMinor => grossSalesMinor - discountsMinor - refundsMinor;
}

class FinancialReport {
  const FinancialReport({
    required this.summary,
    required this.expensesByCategory,
    required this.products,
    required this.customerOutstandingMinor,
    required this.supplierOutstandingMinor,
    required this.inventoryCostValueMinor,
    required this.inventoryRetailValueMinor,
  });

  final FinancialSummary summary;
  final Map<String, int> expensesByCategory;
  final List<ProductFinancialResult> products;
  final int customerOutstandingMinor;
  final int supplierOutstandingMinor;
  final int inventoryCostValueMinor;
  final int inventoryRetailValueMinor;
}

class DashboardSummary {
  const DashboardSummary({
    required this.financial,
    required this.productCount,
    required this.lowStockCount,
    required this.customerOutstandingMinor,
    required this.supplierOutstandingMinor,
    required this.todaySalesCount,
    required this.recentSales,
  });

  final FinancialSummary financial;
  final int productCount;
  final int lowStockCount;
  final int customerOutstandingMinor;
  final int supplierOutstandingMinor;
  final int todaySalesCount;
  final List<RecentFinancialSale> recentSales;
}

class AlertMetrics {
  const AlertMetrics({
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.unpaidCustomerCount,
    required this.overdueCustomerCount,
    required this.unpaidSupplierCount,
    required this.overdueSupplierCount,
    required this.previousDaySalesMinor,
  });

  final int lowStockCount;
  final int outOfStockCount;
  final int unpaidCustomerCount;
  final int overdueCustomerCount;
  final int unpaidSupplierCount;
  final int overdueSupplierCount;
  final int previousDaySalesMinor;
}

typedef DashboardDataLoader = Future<DashboardData> Function(DateTime now);

class DashboardData {
  const DashboardData({required this.summary, required this.trend});

  final DashboardSummary summary;
  final List<FinancialPeriod> trend;
}

class RecentFinancialSale {
  const RecentFinancialSale({
    required this.id,
    required this.date,
    required this.totalMinor,
    required this.customerName,
  });

  final String id;
  final DateTime date;
  final int totalMinor;
  final String? customerName;
}

class FinancialPeriod {
  const FinancialPeriod({required this.start, required this.summary});

  final DateTime start;
  final FinancialSummary summary;
}

class ProductFinancialResult {
  const ProductFinancialResult({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenueMinor,
    required this.costMinor,
    required this.profitMinor,
  });

  final String productId;
  final String productName;
  final double quantity;
  final int revenueMinor;
  final int costMinor;
  final int profitMinor;
}

class CustomerFinancialResult {
  const CustomerFinancialResult({
    required this.customerId,
    required this.name,
    required this.orderCount,
    required this.totalMinor,
  });

  final String customerId;
  final String name;
  final int orderCount;
  final int totalMinor;
}
