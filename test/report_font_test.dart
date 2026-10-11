import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('embedded Arabic font renders an Arabic PDF report', () async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic.ttf');
    final font = pw.Font.ttf(fontData);
    final document =
        pw.Document(
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
            italic: font,
            boldItalic: font,
          ),
        )..addPage(
          pw.Page(
            textDirection: pw.TextDirection.rtl,
            build: (_) => pw.Text('تقرير المبيعات'),
          ),
        );

    expect(await document.save(), isNotEmpty);
  });
}
