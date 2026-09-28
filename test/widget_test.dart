import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/app/app.dart';
import 'package:hesabati/core/database/database.dart';
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

  testWidgets('shows the Arabic dashboard and summary cards', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(database: database, initialSettings: settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsOneWidget);
    expect(find.text('صباح الخير'), findsOneWidget);
    expect(find.text('إجمالي المبيعات'), findsOneWidget);
    expect(find.text('أحدث العمليات'), findsOneWidget);
  });

  testWidgets('switches language and theme', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(database: database, initialSettings: settings),
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

  testWidgets('filters recent transactions by search query', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(database: database, initialSettings: settings),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-a-transaction');
    await tester.pumpAndSettle();

    expect(find.text('لا توجد نتائج'), findsOneWidget);
  });

  testWidgets('saves and reloads an offline business profile', (tester) async {
    await tester.pumpWidget(
      HesabatiApp(database: database, initialSettings: settings),
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
      find.byType(FilledButton),
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
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
