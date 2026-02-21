import 'dart:io' show File;

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../models/product_model.dart';
import '../models/unit_conversion.dart';
import 'product_service.dart';

/// Service để import sản phẩm từ CSV
class ImportService {
  final ProductService _productService;

  ImportService(this._productService);

  /// Tạo file Excel mẫu import sản phẩm, lưu vào thư mục Downloads và mở file.
  /// Trả về đường dẫn file đã lưu; null nếu thất bại hoặc trên web (chỉ tạo được bytes).
  Future<String?> downloadProductTemplate() async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Mẫu sản phẩm'];

    const headers = [
      'Mã Sản Phẩm',
      'Tên Sản Phẩm',
      'Đơn Vị',
      'Giá Vốn',
      'Giá Bán',
      'Tồn Kho',
      'Mô Tả',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    const exampleRow = [
      'SP001',
      'Nước suối 500ml',
      'Chai',
      5000,
      10000,
      100,
      'Mô tả ví dụ - có thể để trống',
    ];
    final rowCells = <CellValue>[
      TextCellValue(exampleRow[0] as String),
      TextCellValue(exampleRow[1] as String),
      TextCellValue(exampleRow[2] as String),
      IntCellValue(exampleRow[3] as int),
      IntCellValue(exampleRow[4] as int),
      IntCellValue(exampleRow[5] as int),
      TextCellValue(exampleRow[6] as String),
    ];
    sheet.appendRow(rowCells);

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) return null;

    if (kIsWeb) {
      if (kDebugMode) debugPrint('downloadProductTemplate: Web không lưu file, chỉ tạo bytes.');
      return null;
    }

    final directory = await getDownloadsDirectory();
    if (directory == null) {
      if (kDebugMode) debugPrint('downloadProductTemplate: Không lấy được thư mục Downloads.');
      return null;
    }

    const fileName = 'Mau_san_pham_import.xlsx';
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('downloadProductTemplate: Không mở được file: $e');
    }

    return filePath;
  }

  /// Đọc CSV và trả về danh sách dòng để xem trước (không lưu DB).
  /// Hỗ trợ 7 cột (Mã, Tên, Đơn vị, Giá vốn, Giá bán, Tồn kho, Mô tả) hoặc 6 cột (Tên, Đơn vị, Giá nhập, Giá bán, Tồn kho, Mã vạch).
  List<PreviewRow> parseCsvForPreview(String csvContent) {
    final result = <PreviewRow>[];
    final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return result;

    int startIndex = 0;
    bool useSevenColumns = false;
    final firstLine = lines[0].toLowerCase();
    if (firstLine.contains('tên') || firstLine.contains('name') || firstLine.contains('mã')) {
      startIndex = 1;
      if (firstLine.contains('mã') && _parseCsvLine(lines[0], lines[0].contains(';') ? ';' : ',').length >= 7) {
        useSevenColumns = true;
      }
    }

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final separator = line.contains(';') ? ';' : ',';
      final fields = _parseCsvLine(line, separator);

      if (useSevenColumns) {
        if (fields.length < 7) {
          result.add(PreviewRow(
            rowIndex: i + 1,
            name: fields.isNotEmpty ? fields[0] : '',
            unit: fields.length > 1 ? fields[1] : '',
            importPriceStr: fields.length > 2 ? fields[2] : '',
            priceStr: fields.length > 3 ? fields[3] : '',
            stockStr: fields.length > 4 ? fields[4] : '',
            isValid: false,
            errorMessage: 'Thiếu cột (cần 7 cột)',
          ));
          continue;
        }
        final code = fields[0].trim();
        final name = fields[1].trim();
        final unit = fields[2].trim();
        final importPriceStr = fields[3].trim();
        final priceStr = fields[4].trim();
        final stockStr = fields[5].trim();
        final description = fields[6].trim();

        String? errorMsg;
        if (name.isEmpty) errorMsg = 'Tên sản phẩm không được để trống';
        final price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;
        if (errorMsg == null && price <= 0) errorMsg = 'Giá bán phải lớn hơn 0';

        result.add(PreviewRow(
          rowIndex: i + 1,
          code: code.isEmpty ? null : code,
          name: name,
          unit: unit,
          importPriceStr: importPriceStr,
          priceStr: priceStr,
          stockStr: stockStr,
          description: description.isEmpty ? null : description,
          isValid: errorMsg == null,
          errorMessage: errorMsg,
        ));
      } else {
        if (fields.length < 5) {
          result.add(PreviewRow(
            rowIndex: i + 1,
            name: fields.isNotEmpty ? fields[0] : '',
            unit: fields.length > 1 ? fields[1] : '',
            importPriceStr: fields.length > 2 ? fields[2] : '',
            priceStr: fields.length > 3 ? fields[3] : '',
            stockStr: fields.length > 4 ? fields[4] : '',
            isValid: false,
            errorMessage: 'Thiếu thông tin (cần ít nhất 5 cột)',
          ));
          continue;
        }
        final name = fields[0].trim();
        final unit = fields[1].trim();
        final importPriceStr = fields[2].trim();
        final priceStr = fields[3].trim();
        final stockStr = fields[4].trim();
        final barcode = fields.length > 5 ? fields[5].trim() : '';

        String? errorMsg;
        if (name.isEmpty) errorMsg = 'Tên sản phẩm không được để trống';
        final price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;
        if (errorMsg == null && price <= 0) errorMsg = 'Giá bán phải lớn hơn 0';

        result.add(PreviewRow(
          rowIndex: i + 1,
          name: name,
          unit: unit,
          importPriceStr: importPriceStr,
          priceStr: priceStr,
          stockStr: stockStr,
          barcode: barcode.isEmpty ? null : barcode,
          isValid: errorMsg == null,
          errorMessage: errorMsg,
        ));
      }
    }
    return result;
  }

  /// Import sản phẩm từ nội dung CSV
  /// Format CSV: Tên, Đơn vị, Giá nhập, Giá bán, Tồn kho, Mã vạch (tùy chọn)
  /// Hoặc 7 cột: Mã Sản Phẩm, Tên Sản Phẩm, Đơn Vị, Giá Vốn, Giá Bán, Tồn Kho, Mô Tả
  /// Header có thể có hoặc không
  /// 
  /// Ví dụ:
  /// Tên,Đơn vị,Giá nhập,Giá bán,Tồn kho,Mã vạch
  /// Nước suối,Chai,5000,10000,100,1234567890123
  /// Bánh mì,Cái,3000,5000,50,
  /// Import từ CSV: validate từng dòng, gom sản phẩm hợp lệ rồi ghi hàng loạt (WriteBatch)
  /// để giảm lượt ghi Firestore so với gọi addProduct từng cái.
  Future<ImportResult> importFromCsv(String csvContent) async {
    final result = ImportResult();
    
    try {
      final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      if (lines.isEmpty) {
        result.errorMessage = 'File CSV trống';
        return result;
      }

      int startIndex = 0;
      bool useSevenColumns = false;
      final firstLine = lines[0].toLowerCase();
      if (firstLine.contains('tên') || firstLine.contains('name') || firstLine.contains('mã')) {
        startIndex = 1;
        if (firstLine.contains('mã') && _parseCsvLine(lines[0], lines[0].contains(';') ? ';' : ',').length >= 7) {
          useSevenColumns = true;
        }
      }

      final validProducts = <ProductModel>[];
      final baseId = DateTime.now().millisecondsSinceEpoch;

      for (int i = startIndex; i < lines.length; i++) {
        try {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final separator = line.contains(';') ? ';' : ',';
          final fields = _parseCsvLine(line, separator);

          String name;
          String unit;
          String importPriceStr;
          String priceStr;
          String stockStr;
          String barcode = '';

          if (useSevenColumns && fields.length >= 7) {
            name = fields[1].trim();
            unit = fields[2].trim();
            importPriceStr = fields[3].trim();
            priceStr = fields[4].trim();
            stockStr = fields[5].trim();
          } else {
            if (fields.length < 5) {
              result.failedCount++;
              result.failedRows.add('Dòng ${i + 1}: Thiếu thông tin (cần ít nhất 5 cột)');
              continue;
            }
            name = fields[0].trim();
            unit = fields[1].trim();
            importPriceStr = fields[2].trim();
            priceStr = fields[3].trim();
            stockStr = fields[4].trim();
            barcode = fields.length > 5 ? fields[5].trim() : '';
          }

          if (name.isEmpty) {
            result.failedCount++;
            result.failedRows.add('Dòng ${i + 1}: Tên sản phẩm không được để trống');
            continue;
          }

          final importPrice = double.tryParse(importPriceStr.replaceAll(',', '')) ?? 0.0;
          final price = double.tryParse(priceStr.replaceAll(',', '')) ?? 0.0;
          final stock = double.tryParse(stockStr.replaceAll(',', '')) ?? 0.0;

          if (price <= 0) {
            result.failedCount++;
            result.failedRows.add('Dòng ${i + 1}: Giá bán phải lớn hơn 0');
            continue;
          }

          final unitConversion = UnitConversion(
            id: 'default',
            unitName: unit.isEmpty ? 'cái' : unit,
            conversionValue: 1.0,
            price: price,
            barcode: barcode.isEmpty ? null : barcode,
          );

          validProducts.add(ProductModel(
            id: 'import_${baseId}_$i',
            name: name,
            units: [unitConversion],
            branchPrices: {'default': price},
            importPrice: importPrice,
            branchStock: {'default': stock},
            barcode: barcode.isEmpty ? null : barcode,
            isSellable: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          ));
        } catch (e) {
          result.failedCount++;
          result.failedRows.add('Dòng ${i + 1}: ${e.toString()}');
          if (kDebugMode) debugPrint('❌ Error importing row ${i + 1}: $e');
        }
      }

      if (validProducts.isNotEmpty) {
        await _productService.importProductsBulk(validProducts);
        result.successCount = validProducts.length;
        if (kDebugMode) debugPrint('✅ Import batch: ${validProducts.length} products');
      }

      result.isSuccess = result.failedCount == 0 || result.successCount > 0;
      if (kDebugMode) {
        debugPrint('📊 Import result: ${result.successCount} success, ${result.failedCount} failed');
      }

      return result;
    } catch (e) {
      result.errorMessage = 'Lỗi khi đọc CSV: ${e.toString()}';
      result.isSuccess = false;
      if (kDebugMode) debugPrint('❌ Error importing CSV: $e');
      return result;
    }
  }

  /// Parse một dòng CSV, xử lý cả trường hợp có dấu ngoặc kép
  List<String> _parseCsvLine(String line, String separator) {
    final List<String> fields = [];
    String currentField = '';
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == separator && !inQuotes) {
        fields.add(currentField.trim());
        currentField = '';
      } else {
        currentField += char;
      }
    }
    
    // Thêm field cuối cùng
    fields.add(currentField.trim());

    return fields;
  }
}

/// Một dòng xem trước khi import (chưa lưu DB).
class PreviewRow {
  const PreviewRow({
    required this.rowIndex,
    this.code,
    required this.name,
    required this.unit,
    required this.importPriceStr,
    required this.priceStr,
    required this.stockStr,
    this.barcode,
    this.description,
    required this.isValid,
    this.errorMessage,
  });

  final int rowIndex;
  final String? code;
  final String name;
  final String unit;
  final String importPriceStr;
  final String priceStr;
  final String stockStr;
  final String? barcode;
  final String? description;
  final bool isValid;
  final String? errorMessage;
}

/// Chuyển các dòng preview hợp lệ thành `List<ProductModel>` để gửi vào ProductProvider.importProductsFromList.
List<ProductModel> previewRowsToProducts(List<PreviewRow> validRows) {
  final products = <ProductModel>[];
  for (var i = 0; i < validRows.length; i++) {
    final row = validRows[i];
    if (!row.isValid) continue;
    final importPrice = double.tryParse(row.importPriceStr.replaceAll(',', '')) ?? 0.0;
    final price = double.tryParse(row.priceStr.replaceAll(',', '')) ?? 0.0;
    final stock = double.tryParse(row.stockStr.replaceAll(',', '')) ?? 0.0;
    final unitConversion = UnitConversion(
      id: 'default',
      unitName: row.unit.isEmpty ? 'cái' : row.unit,
      conversionValue: 1.0,
      price: price,
      barcode: row.barcode,
    );
    products.add(ProductModel(
      id: 'temp_$i', // Provider sẽ gán id thật khi import
      code: row.code?.isEmpty == true ? null : row.code,
      name: row.name,
      units: [unitConversion],
      branchPrices: {'default': price},
      importPrice: importPrice,
      branchStock: {'default': stock},
      barcode: row.barcode,
      description: row.description,
      isSellable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    ));
  }
  return products;
}

/// Kết quả import
class ImportResult {
  int successCount = 0;
  int failedCount = 0;
  List<String> failedRows = [];
  String? errorMessage;
  bool isSuccess = false;

  String get summary {
    if (errorMessage != null) {
      return errorMessage!;
    }
    return 'Thành công: $successCount, Thất bại: $failedCount';
  }
}
