import 'dart:typed_data';

import 'package:excel/excel.dart';

String spreadsheetCsvCell(String value) {
  final formulaPrefix = RegExp(r'^[\u0000-\u0020\uFEFF]*[=+\-@]');
  final safeValue = formulaPrefix.hasMatch(value) ? "'$value" : value;
  return '"${safeValue.replaceAll('"', '""')}"';
}

class SpreadsheetNumber {
  const SpreadsheetNumber(this.value, {required this.numberFormat});

  final num value;
  final String numberFormat;
}

Uint8List spreadsheetXlsxBytes(
  List<List<Object?>> rows, {
  required bool rightToLeft,
}) {
  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Report');
  final sheet = workbook['Report']..isRTL = rightToLeft;
  final textCellStyle = CellStyle(
    horizontalAlign: rightToLeft ? HorizontalAlign.Right : HorizontalAlign.Left,
  );

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      final value = row[columnIndex];
      if (value is String) {
        cell
          ..value = TextCellValue(value)
          ..cellStyle = textCellStyle;
        continue;
      }
      if (value is SpreadsheetNumber) {
        final numericValue = value.value;
        cell
          ..value = numericValue is int
              ? IntCellValue(numericValue)
              : DoubleCellValue(numericValue.toDouble())
          ..cellStyle = CellStyle(
            horizontalAlign: rightToLeft
                ? HorizontalAlign.Right
                : HorizontalAlign.Left,
            numberFormat: CustomNumericNumFormat(
              formatCode: value.numberFormat,
            ),
          );
        continue;
      }
      if (value == null) continue;
      throw ArgumentError.value(
        value,
        'rows[$rowIndex][$columnIndex]',
        'XLSX cells must be text or SpreadsheetNumber values.',
      );
    }
  }

  final bytes = workbook.encode();
  if (bytes == null) {
    throw StateError('Failed to encode the XLSX report.');
  }
  return Uint8List.fromList(bytes);
}
