import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/spreadsheet_export.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  FinancialBucket _bucket = FinancialBucket.day;
  String? _customerId;
  String? _supplierId;
  String? _categoryId;
  String _query = '';
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Category> _categories = [];
  FinancialReport? _report;
  List<FinancialPeriod> _trend = [];
  List<ProductFinancialResult> _topProducts = [];
  List<ProductFinancialResult> _leastProducts = [];
  List<ProductFinancialResult> _profitProducts = [];
  List<CustomerFinancialResult> _customerResults = [];
  AppSettings? _settings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day - 29);
    _to = DateTime(today.year, today.month, today.day + 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final financial = FinancialService(widget.database);
      final values = await Future.wait<Object?>([
        financial.getReport(
          from: _from,
          to: _to,
          customerId: _customerId,
          supplierId: _supplierId,
          categoryId: _categoryId,
        ),
        financial.getTrend(from: _from, to: _to, bucket: _bucket),
        financial.getProductPerformance(
          from: _from,
          to: _to,
          categoryId: _categoryId,
          customerId: _customerId,
          limit: 10,
        ),
        financial.getProductPerformance(
          from: _from,
          to: _to,
          categoryId: _categoryId,
          customerId: _customerId,
          limit: 10,
          leastSelling: true,
        ),
        financial.getCustomerPerformance(from: _from, to: _to),
        widget.database.customers.getAll(orderBy: 'name'),
        widget.database.suppliers.getAll(orderBy: 'name'),
        widget.database.categories.getAll(orderBy: 'name'),
        widget.database.settings.get(),
      ]);
      final products = values[2] as List<ProductFinancialResult>;
      final profitProducts = [...products]
        ..sort((a, b) => b.profitMinor.compareTo(a.profitMinor));
      if (!mounted) return;
      setState(() {
        _report = values[0] as FinancialReport;
        _trend = values[1] as List<FinancialPeriod>;
        _topProducts = products;
        _leastProducts = values[3] as List<ProductFinancialResult>;
        _profitProducts = profitProducts;
        _customerResults = values[4] as List<CustomerFinancialResult>;
        _customers = values[5] as List<Customer>;
        _suppliers = values[6] as List<Supplier>;
        _categories = values[7] as List<Category>;
        _settings = values[8] as AppSettings?;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Failed to load analytics and reports: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _from,
        end: _to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
    });
    await _load();
  }

  String _money(int minor) {
    final currency = _settings?.currencyCode ?? 'EGP';
    return '$currency ${(minor / 100).toStringAsFixed(2)}';
  }

  List<List<String>> _reportRows(
    AppLocalizations strings,
    FinancialReport report,
  ) {
    final summary = report.summary;
    return [
      [strings.reportTitle, _settings?.businessName ?? strings.appName],
      [
        strings.dateRange,
        '${_date(_from)} - ${_date(_to.subtract(const Duration(days: 1)))}',
      ],
      [],
      [strings.metric, strings.amount],
      [strings.grossSales, _money(summary.grossSalesMinor)],
      [strings.discount, _money(summary.discountsMinor)],
      [strings.refunds, _money(summary.refundsMinor)],
      [strings.netSales, _money(summary.netSalesMinor)],
      [strings.costOfGoods, _money(summary.costOfGoodsMinor)],
      [strings.grossProfit, _money(summary.grossProfitMinor)],
      [strings.expenses, _money(summary.expensesMinor)],
      [strings.netProfit, _money(summary.netProfitMinor)],
      [strings.customerDebt, _money(report.customerOutstandingMinor)],
      [strings.supplierDebt, _money(report.supplierOutstandingMinor)],
      [strings.inventoryValue, _money(report.inventoryCostValueMinor)],
      [],
      [strings.expenseCategory, strings.amount],
      ...report.expensesByCategory.entries.map(
        (entry) => [entry.key, _money(entry.value)],
      ),
      [],
      [strings.productName, strings.quantity, strings.netSales, strings.profit],
      ..._topProducts.map(
        (product) => [
          product.productName,
          product.quantity.toString(),
          _money(product.revenueMinor),
          _money(product.profitMinor),
        ],
      ),
    ];
  }

  SpreadsheetNumber _xlsxMoney(int minor) {
    final currencyCode = (_settings?.currencyCode ?? 'EGP').replaceAll(
      '"',
      '""',
    );
    return SpreadsheetNumber(
      minor / 100,
      numberFormat: '"$currencyCode" #,##0.00',
    );
  }

  List<List<Object?>> _xlsxReportRows(
    AppLocalizations strings,
    FinancialReport report,
  ) {
    final summary = report.summary;
    return [
      [strings.reportTitle, _settings?.businessName ?? strings.appName],
      [
        strings.dateRange,
        '${_date(_from)} - ${_date(_to.subtract(const Duration(days: 1)))}',
      ],
      [],
      [strings.metric, strings.amount],
      [strings.grossSales, _xlsxMoney(summary.grossSalesMinor)],
      [strings.discount, _xlsxMoney(summary.discountsMinor)],
      [strings.refunds, _xlsxMoney(summary.refundsMinor)],
      [strings.netSales, _xlsxMoney(summary.netSalesMinor)],
      [strings.costOfGoods, _xlsxMoney(summary.costOfGoodsMinor)],
      [strings.grossProfit, _xlsxMoney(summary.grossProfitMinor)],
      [strings.expenses, _xlsxMoney(summary.expensesMinor)],
      [strings.netProfit, _xlsxMoney(summary.netProfitMinor)],
      [strings.customerDebt, _xlsxMoney(report.customerOutstandingMinor)],
      [strings.supplierDebt, _xlsxMoney(report.supplierOutstandingMinor)],
      [strings.inventoryValue, _xlsxMoney(report.inventoryCostValueMinor)],
      [],
      [strings.expenseCategory, strings.amount],
      ...report.expensesByCategory.entries.map(
        (entry) => [entry.key, _xlsxMoney(entry.value)],
      ),
      [],
      [strings.productName, strings.quantity, strings.netSales, strings.profit],
      ..._topProducts.map(
        (product) => [
          product.productName,
          SpreadsheetNumber(
            product.quantity,
            numberFormat: '#,##0.#################',
          ),
          _xlsxMoney(product.revenueMinor),
          _xlsxMoney(product.profitMinor),
        ],
      ),
    ];
  }

  bool _hasReportData(FinancialReport report) {
    final summary = report.summary;
    return report.expensesByCategory.isNotEmpty ||
        report.products.isNotEmpty ||
        _topProducts.isNotEmpty ||
        report.customerOutstandingMinor != 0 ||
        report.supplierOutstandingMinor != 0 ||
        report.inventoryCostValueMinor != 0 ||
        report.inventoryRetailValueMinor != 0 ||
        [
          summary.grossSalesMinor,
          summary.discountsMinor,
          summary.refundsMinor,
          summary.costOfGoodsMinor,
          summary.expensesMinor,
          summary.grossProfitMinor,
          summary.netProfitMinor,
          summary.customerDebtPaymentsMinor,
          summary.supplierDebtPaymentsMinor,
        ].any((amount) => amount != 0);
  }

  void _showExportError(AppLocalizations strings, Object error) {
    debugPrint('Failed to create spreadsheet report: ${error.runtimeType}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.exportFailed(error.toString()))),
    );
  }

  Future<void> _exportCsv() async {
    final report = _report;
    if (report == null) return;
    final strings = AppLocalizations.of(context);
    final rows = _reportRows(strings, report);
    final csv = rows
        .map((row) => row.map(spreadsheetCsvCell).join(','))
        .join('\r\n');
    await _shareFile(
      name: 'hesabati-report-${_fileDate(_from)}.csv',
      bytes: [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)],
      mimeType: 'text/csv',
    );
  }

  Future<void> _exportXlsx() async {
    final report = _report;
    if (report == null) return;
    final strings = AppLocalizations.of(context);
    if (!_hasReportData(report)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.noReportData)));
      return;
    }
    try {
      await _shareFile(
        name: 'hesabati-report-${_fileDate(_from)}.xlsx',
        bytes: spreadsheetXlsxBytes(
          _xlsxReportRows(strings, report),
          rightToLeft: strings.isArabic,
        ),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        successMessage: strings.reportReadyForSharing,
      );
    } catch (error) {
      _showExportError(strings, error);
    }
  }

  Future<void> _exportPdf() async {
    final report = _report;
    if (report == null) return;
    final strings = AppLocalizations.of(context);
    final summary = report.summary;
    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic.ttf'),
    );
    final document = pw.Document();
    final content = <List<String>>[
      [strings.grossSales, _money(summary.grossSalesMinor)],
      [strings.discount, _money(summary.discountsMinor)],
      [strings.refunds, _money(summary.refundsMinor)],
      [strings.netSales, _money(summary.netSalesMinor)],
      [strings.costOfGoods, _money(summary.costOfGoodsMinor)],
      [strings.grossProfit, _money(summary.grossProfitMinor)],
      [strings.expenses, _money(summary.expensesMinor)],
      [strings.netProfit, _money(summary.netProfitMinor)],
      [strings.customerDebt, _money(report.customerOutstandingMinor)],
      [strings.supplierDebt, _money(report.supplierOutstandingMinor)],
      [strings.inventoryValue, _money(report.inventoryCostValueMinor)],
    ];
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
          italic: arabicFont,
          boldItalic: arabicFont,
        ),
        textDirection: strings.isArabic
            ? pw.TextDirection.rtl
            : pw.TextDirection.ltr,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(_settings?.businessName ?? strings.appName),
          ),
          pw.Text(strings.reportTitle, style: pw.Theme.of(context).header2),
          pw.SizedBox(height: 6),
          pw.Text(
            '${strings.dateRange}: ${_date(_from)} - '
            '${_date(_to.subtract(const Duration(days: 1)))}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [strings.metric, strings.amount],
            data: content,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
          pw.SizedBox(height: 18),
          pw.Header(level: 1, child: pw.Text(strings.productPerformance)),
          pw.TableHelper.fromTextArray(
            headers: [
              strings.productName,
              strings.quantity,
              strings.netSales,
              strings.profit,
            ],
            data: _topProducts
                .map(
                  (product) => [
                    product.productName,
                    product.quantity.toStringAsFixed(2),
                    _money(product.revenueMinor),
                    _money(product.profitMinor),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(strings.generatedReportNotice),
        ],
      ),
    );
    await _shareFile(
      name: 'hesabati-report-${_fileDate(_from)}.pdf',
      bytes: await document.save(),
      mimeType: 'application/pdf',
    );
  }

  Future<void> _shareFile({
    required String name,
    required List<int> bytes,
    required String mimeType,
    String? successMessage,
  }) async {
    final strings = AppLocalizations.of(context);
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: strings.reportTitle,
        ),
      );
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (error) {
      debugPrint('Failed to export or share report: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.exportFailed(error.toString()))),
      );
    }
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  String _fileDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.reports),
        actions: [
          IconButton(
            tooltip: strings.exportCsv,
            onPressed: report == null ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
          ),
          IconButton(
            tooltip: strings.exportXlsx,
            onPressed: report == null ? null : _exportXlsx,
            icon: const Icon(Icons.grid_on_outlined),
          ),
          IconButton(
            tooltip: strings.exportPdf,
            onPressed: report == null ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(strings.retry)),
                ],
              ),
            )
          : report == null
          ? Center(child: Text(strings.noReportData))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OutlinedButton.icon(
                    onPressed: _selectRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${_date(_from)} — '
                      '${_date(_to.subtract(const Duration(days: 1)))}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filter<String>(
                        value: _customerId,
                        label: strings.customer,
                        values: _customers.map((e) => (e.id, e.name)).toList(),
                        onChanged: (value) =>
                            setState(() => _customerId = value),
                        onClear: () => setState(() => _customerId = null),
                      ),
                      _filter<String>(
                        value: _supplierId,
                        label: strings.supplier,
                        values: _suppliers.map((e) => (e.id, e.name)).toList(),
                        onChanged: (value) =>
                            setState(() => _supplierId = value),
                        onClear: () => setState(() => _supplierId = null),
                      ),
                      _filter<String>(
                        value: _categoryId,
                        label: strings.category,
                        values: _categories.map((e) => (e.id, e.name)).toList(),
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        onClear: () => setState(() => _categoryId = null),
                      ),
                      DropdownButton<FinancialBucket>(
                        value: _bucket,
                        items: [
                          DropdownMenuItem(
                            value: FinancialBucket.day,
                            child: Text(strings.daily),
                          ),
                          DropdownMenuItem(
                            value: FinancialBucket.week,
                            child: Text(strings.weekly),
                          ),
                          DropdownMenuItem(
                            value: FinancialBucket.month,
                            child: Text(strings.monthly),
                          ),
                          DropdownMenuItem(
                            value: FinancialBucket.year,
                            child: Text(strings.yearly),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _bucket = value);
                          _load();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: Text(strings.applyFilters),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: strings.searchAnalytics,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(strings, report),
                  const SizedBox(height: 20),
                  _sectionTitle(strings.salesOverTime),
                  FinancialTrendChart(
                    periods: _trend,
                    currencyCode: _settings?.currencyCode ?? 'EGP',
                    salesLabel: strings.salesOverTimeLabel,
                    profitLabel: strings.profitOverTimeLabel,
                    expensesLabel: strings.expensesOverTimeLabel,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(strings.expenses),
                  if (report.expensesByCategory.isEmpty)
                    Text(strings.noReportData)
                  else
                    ...report.expensesByCategory.entries.map(
                      (entry) => ListTile(
                        title: Text(entry.key),
                        trailing: Text(_money(entry.value)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _sectionTitle(strings.bestSellingProducts),
                  _productList(_topProducts, strings),
                  const SizedBox(height: 16),
                  _sectionTitle(strings.leastSellingProducts),
                  _productList(_leastProducts, strings),
                  const SizedBox(height: 16),
                  _sectionTitle(strings.highestProfitProducts),
                  _productList(_profitProducts, strings),
                  const SizedBox(height: 16),
                  _sectionTitle(strings.customerAnalysis),
                  ..._customerResults
                      .where((customer) => _matches(customer.name))
                      .map(
                        (customer) => ListTile(
                          title: Text(customer.name),
                          subtitle: Text(
                            '${customer.orderCount} ${strings.orders}',
                          ),
                          trailing: Text(_money(customer.totalMinor)),
                        ),
                      ),
                  const SizedBox(height: 16),
                  _sectionTitle(strings.inventoryValue),
                  ListTile(
                    title: Text(strings.costValue),
                    trailing: Text(_money(report.inventoryCostValueMinor)),
                  ),
                  ListTile(
                    title: Text(strings.retailValue),
                    trailing: Text(_money(report.inventoryRetailValueMinor)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _filter<T>({
    required T? value,
    required String label,
    required List<(T, String)> values,
    required ValueChanged<T?> onChanged,
    required VoidCallback onClear,
  }) => DropdownButton<T?>(
    value: value,
    hint: Text(label),
    items: [
      DropdownMenuItem<T?>(value: null, child: Text(label)),
      ...values.map(
        (entry) => DropdownMenuItem<T?>(
          value: entry.$1,
          child: Text(entry.$2, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: (selected) {
      onChanged(selected);
      _load();
    },
  );

  Widget _buildSummaryCard(AppLocalizations strings, FinancialReport report) {
    final summary = report.summary;
    final rows = <(String, int)>[
      (strings.grossSales, summary.grossSalesMinor),
      (strings.discount, -summary.discountsMinor),
      (strings.refunds, -summary.refundsMinor),
      (strings.netSales, summary.netSalesMinor),
      (strings.costOfGoods, -summary.costOfGoodsMinor),
      (strings.grossProfit, summary.grossProfitMinor),
      (strings.expenses, -summary.expensesMinor),
      (strings.netProfit, summary.netProfitMinor),
      (strings.customerDebt, report.customerOutstandingMinor),
      (strings.supplierDebt, report.supplierOutstandingMinor),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final row in rows)
              ListTile(
                dense: true,
                title: Text(row.$1),
                trailing: Text(_money(row.$2)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productList(
    List<ProductFinancialResult> products,
    AppLocalizations strings,
  ) {
    final filtered = products
        .where((product) => _matches(product.productName))
        .toList();
    if (filtered.isEmpty) return Text(strings.noReportData);
    return Column(
      children: [
        for (final product in filtered)
          ListTile(
            title: Text(product.productName),
            subtitle: Text(
              '${strings.quantity}: ${product.quantity} · '
              '${strings.netSales}: ${_money(product.revenueMinor)}',
            ),
            trailing: Text(_money(product.profitMinor)),
          ),
      ],
    );
  }

  bool _matches(String value) =>
      _query.trim().isEmpty ||
      value.toLowerCase().contains(_query.trim().toLowerCase());

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class FinancialTrendChart extends StatelessWidget {
  const FinancialTrendChart({
    required this.periods,
    required this.currencyCode,
    required this.salesLabel,
    required this.profitLabel,
    required this.expensesLabel,
    super.key,
  });

  final List<FinancialPeriod> periods;
  final String currencyCode;
  final String salesLabel;
  final String profitLabel;
  final String expensesLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (periods.isEmpty) {
      return const SizedBox(height: 120);
    }
    final maxValue = periods.fold<int>(0, (maximum, period) {
      final summary = period.summary;
      return [
        maximum,
        summary.netSalesMinor,
        summary.grossProfitMinor,
        summary.expensesMinor,
      ].reduce((a, b) => a > b ? a : b);
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _FinancialChartPainter(
                  periods: periods,
                  maxValue: maxValue <= 0 ? 1 : maxValue,
                  salesColor: colors.primary,
                  profitColor: colors.tertiary,
                  expenseColor: colors.error,
                  gridColor: colors.outlineVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              children: [
                _legend(context, colors.primary, salesLabel),
                _legend(context, colors.tertiary, profitLabel),
                _legend(context, colors.error, expensesLabel),
              ],
            ),
            Text(currencyCode, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, color: color, size: 10),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _FinancialChartPainter extends CustomPainter {
  _FinancialChartPainter({
    required this.periods,
    required this.maxValue,
    required this.salesColor,
    required this.profitColor,
    required this.expenseColor,
    required this.gridColor,
  });

  final List<FinancialPeriod> periods;
  final int maxValue;
  final Color salesColor;
  final Color profitColor;
  final Color expenseColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(0, 6, size.width, size.height - 18);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.7;
    for (var row = 0; row < 4; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    _drawLine(canvas, chart, (e) => e.summary.netSalesMinor, salesColor);
    _drawLine(canvas, chart, (e) => e.summary.grossProfitMinor, profitColor);
    _drawLine(canvas, chart, (e) => e.summary.expensesMinor, expenseColor);
  }

  void _drawLine(
    Canvas canvas,
    Rect chart,
    int Function(FinancialPeriod) select,
    Color color,
  ) {
    if (periods.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < periods.length; index++) {
      final x = periods.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (periods.length - 1);
      final y =
          chart.bottom -
          chart.height * select(periods[index]).clamp(0, maxValue) / maxValue;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FinancialChartPainter oldDelegate) =>
      oldDelegate.periods != periods || oldDelegate.maxValue != maxValue;
}
