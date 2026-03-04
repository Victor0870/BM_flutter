// Script tạm: đọc file Excel và in tên sheet + các cột (dòng đầu).
// Chạy: dart run scripts/read_excel_columns.dart
// (từ thư mục gốc project: dart run scripts/read_excel_columns.dart)

import 'dart:developer' as developer;
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

String cellStr(dynamic cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.text ?? v.value.toString();
  if (v is IntCellValue) return '${v.value}';
  if (v is DoubleCellValue) return '${v.value}';
  return v.toString();
}

void main() async {
  // Chạy từ thư mục gốc project
  final path = p.join(Directory.current.path, 'lib', 'Data base danganh.xlsx');
  final file = File(path);
  if (!file.existsSync()) {
    developer.log('File không tồn tại: $path');
    exit(1);
  }
  final bytes = await file.readAsBytes();
  final excel = Excel.decodeBytes(bytes);
  if (excel.sheets.isEmpty) {
    developer.log('File không có sheet nào.');
    exit(1);
  }
  developer.log('=== Sheets và cột (dòng header) trong file ===\n');
  for (final name in excel.sheets.keys) {
    final sheet = excel.sheets[name]!;
    final rows = sheet.rows;
    developer.log('Sheet: "$name" (${rows.length} dòng)');
    if (rows.isNotEmpty) {
      final header = rows[0];
      final cols = <String>[];
      for (var c = 0; c < header.length; c++) {
        cols.add(cellStr(header[c]));
      }
      developer.log('  Cột (header): $cols');
      developer.log('');
    }
  }
}
