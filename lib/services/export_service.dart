import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Kết quả xuất file: bytes, tên file gợi ý, và đường dẫn đã lưu (nếu có).
class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.suggestedFileName,
    this.savedFilePath,
  });

  final Uint8List bytes;
  final String suggestedFileName;
  /// Khác null khi đã ghi ra disk (mobile/desktop). Trên web thường null.
  final String? savedFilePath;
}

/// Service tập trung xuất báo cáo ra Excel và PDF.
/// Hỗ trợ tiếng Việt trong PDF (dùng font mặc định; có thể truyền TTF nếu cần).
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Chuyển giá trị ô sang [CellValue] của package excel.
  static CellValue _toCellValue(Object? value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is num) {
      if (value == value.toInt()) return IntCellValue(value.toInt());
      return DoubleCellValue(value.toDouble());
    }
    if (value is DateTime) {
      return TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(value));
    }
    return TextCellValue(value.toString());
  }

  /// Xuất bảng từ danh sách dòng có sẵn (phù hợp khi cần build dòng bất đồng bộ).
  Future<ExportResult> exportToExcelFromRows({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
    List<Object?>? summaryRow,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[sheetName];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(_toCellValue).toList());
    }
    if (summaryRow != null && summaryRow.isNotEmpty) {
      sheet.appendRow(<CellValue>[]);
      sheet.appendRow(summaryRow.map(_toCellValue).toList());
    }

    final bytes = excel.save();
    final raw = bytes != null ? Uint8List.fromList(bytes) : Uint8List(0);
    final suggested = fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx';

    if (kIsWeb) {
      return ExportResult(bytes: raw, suggestedFileName: suggested);
    }
    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    if (directory != null && raw.isNotEmpty) {
      final filePath = path.join(directory.path, suggested);
      final file = File(filePath);
      await file.writeAsBytes(raw);
      return ExportResult(
        bytes: raw,
        suggestedFileName: suggested,
        savedFilePath: filePath,
      );
    }
    return ExportResult(bytes: raw, suggestedFileName: suggested);
  }

  /// Xuất bảng dữ liệu ra file Excel.
  /// [rowToCells] chuyển mỗi phần tử [T] thành danh sách giá trị ô (String|int|double|DateTime).
  /// [summaryRow] nếu có sẽ thêm một dòng trống rồi một dòng tổng.
  Future<ExportResult> exportToExcel<T>({
    required String fileName,
    required String sheetName,
    required List<String> headers,
    required List<T> data,
    required List<Object?> Function(T) rowToCells,
    List<Object?>? summaryRow,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[sheetName];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final item in data) {
      final cells = rowToCells(item).map(_toCellValue).toList();
      sheet.appendRow(cells);
    }

    if (summaryRow != null && summaryRow.isNotEmpty) {
      sheet.appendRow(<CellValue>[]);
      sheet.appendRow(summaryRow.map(_toCellValue).toList());
    }

    final bytes = excel.save();
    final raw = bytes != null ? Uint8List.fromList(bytes) : Uint8List(0);
    final suggested = fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx';

    if (kIsWeb) {
      return ExportResult(bytes: raw, suggestedFileName: suggested);
    }

    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    if (directory != null && raw.isNotEmpty) {
      final filePath = path.join(directory.path, suggested);
      final file = File(filePath);
      await file.writeAsBytes(raw);
      return ExportResult(
        bytes: raw,
        suggestedFileName: suggested,
        savedFilePath: filePath,
      );
    }
    return ExportResult(bytes: raw, suggestedFileName: suggested);
  }

  /// Xuất bảng báo cáo ra PDF, định dạng chuyên nghiệp, hỗ trợ tiếng Việt.
  /// [rows]: từng dòng là danh sách chuỗi ô (đã format sẵn).
  /// [summaryText]: dòng chữ tóm tắt in dưới bảng (tùy chọn).
  Future<ExportResult> exportToPdf({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryText,
    required String suggestedFileName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Trang ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (ctx) => [
          if (subtitle != null && subtitle.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                subtitle,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: _tableColumnWidths(headers.length),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: headers
                    .map((h) => _pdfCell(h, isHeader: true))
                    .toList(),
              ),
              ...rows.map(
                (row) => pw.TableRow(
                  children: row.map((c) => _pdfCell(c)).toList(),
                ),
              ),
            ],
          ),
          if (summaryText != null && summaryText.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              summaryText,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final raw = Uint8List.fromList(bytes);
    final suggested = suggestedFileName.endsWith('.pdf')
        ? suggestedFileName
        : '$suggestedFileName.pdf';

    if (kIsWeb) {
      return ExportResult(bytes: raw, suggestedFileName: suggested);
    }

    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    if (directory != null) {
      final filePath = path.join(directory.path, suggested);
      final file = File(filePath);
      await file.writeAsBytes(raw);
      return ExportResult(
        bytes: raw,
        suggestedFileName: suggested,
        savedFilePath: filePath,
      );
    }
    return ExportResult(bytes: raw, suggestedFileName: suggested);
  }

  Map<int, pw.TableColumnWidth> _tableColumnWidths(int columnCount) {
    final single = pw.FlexColumnWidth(1);
    return Map.fromIterables(
      List.generate(columnCount, (i) => i),
      List.generate(columnCount, (_) => single),
    );
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
