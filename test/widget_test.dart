import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hesabati/app/app.dart';

void main() {
  testWidgets('shows the Arabic dashboard and summary cards', (tester) async {
    await tester.pumpWidget(const HesabatiApp());
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsOneWidget);
    expect(find.text('صباح الخير'), findsOneWidget);
    expect(find.text('إجمالي المبيعات'), findsOneWidget);
    expect(find.text('أحدث العمليات'), findsOneWidget);
  });

  testWidgets('switches language and theme', (tester) async {
    await tester.pumpWidget(const HesabatiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('filters recent transactions by search query', (tester) async {
    await tester.pumpWidget(const HesabatiApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-a-transaction');
    await tester.pumpAndSettle();

    expect(find.text('لا توجد نتائج'), findsOneWidget);
  });
}
