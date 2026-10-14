import 'package:flutter_test/flutter_test.dart';
import 'package:hesabati/core/services/spreadsheet_export.dart';

void main() {
  test('escapes CSV fields and neutralizes formula-leading values', () {
    expect(spreadsheetCsvCell('Product, "special"'), '"Product, ""special"""');
    expect(
      spreadsheetCsvCell('=HYPERLINK("https://example.invalid")'),
      '"\'=HYPERLINK(""https://example.invalid"")"',
    );
    expect(spreadsheetCsvCell('\t@SUM(1,2)'), '"\'\t@SUM(1,2)"');
    expect(spreadsheetCsvCell('ordinary value'), '"ordinary value"');
  });
}
