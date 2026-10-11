String spreadsheetCsvCell(String value) {
  final formulaPrefix = RegExp(r'^[\u0000-\u0020\uFEFF]*[=+\-@]');
  final safeValue = formulaPrefix.hasMatch(value) ? "'$value" : value;
  return '"${safeValue.replaceAll('"', '""')}"';
}
