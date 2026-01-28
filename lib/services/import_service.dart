import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/product_model.dart';
import '../models/unit_conversion.dart';
import 'product_service.dart';

/// Service để import sản phẩm từ CSV
class ImportService {
  final ProductService _productService;

  ImportService(this._productService);

  /// Import sản phẩm từ nội dung CSV
  /// Format CSV: Tên, Đơn vị, Giá nhập, Giá bán, Tồn kho, Mã vạch (tùy chọn)
  /// Header có thể có hoặc không
  /// 
  /// Ví dụ:
  /// Tên,Đơn vị,Giá nhập,Giá bán,Tồn kho,Mã vạch
  /// Nước suối,Chai,5000,10000,100,1234567890123
  /// Bánh mì,Cái,3000,5000,50,
  Future<ImportResult> importFromCsv(String csvContent) async {
    final result = ImportResult();
    
    try {
      final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      if (lines.isEmpty) {
        result.errorMessage = 'File CSV trống';
        return result;
      }

      // Kiểm tra xem dòng đầu tiên có phải là header không
      int startIndex = 0;
      final firstLine = lines[0].toLowerCase();
      if (firstLine.contains('tên') || firstLine.contains('name')) {
        startIndex = 1; // Bỏ qua header
      }

      // Parse từng dòng
      for (int i = startIndex; i < lines.length; i++) {
        try {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          // Parse CSV (xử lý cả dấu phẩy và dấu chấm phẩy)
          final separator = line.contains(';') ? ';' : ',';
          final fields = _parseCsvLine(line, separator);
          
          if (fields.length < 5) {
            result.failedCount++;
            result.failedRows.add('Dòng ${i + 1}: Thiếu thông tin (cần ít nhất 5 cột)');
            continue;
          }

          final name = fields[0].trim();
          final unit = fields[1].trim();
          final importPriceStr = fields[2].trim();
          final priceStr = fields[3].trim();
          final stockStr = fields[4].trim();
          final barcode = fields.length > 5 ? fields[5].trim() : '';

          // Validate
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

          // Tạo ProductModel
          final unitConversion = UnitConversion(
            id: 'default',
            unitName: unit.isEmpty ? 'cái' : unit,
            conversionValue: 1.0,
            price: price,
            barcode: barcode.isEmpty ? null : barcode,
          );

          final product = ProductModel(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
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
          );

          // Lưu sản phẩm
          await _productService.addProduct(product);
          result.successCount++;

          if (kDebugMode) {
            debugPrint('✅ Imported product: $name');
          }
        } catch (e) {
          result.failedCount++;
          result.failedRows.add('Dòng ${i + 1}: ${e.toString()}');
          
          if (kDebugMode) {
            debugPrint('❌ Error importing row ${i + 1}: $e');
          }
        }
      }

      result.isSuccess = result.failedCount == 0 || result.successCount > 0;
      
      if (kDebugMode) {
        debugPrint('📊 Import result: ${result.successCount} success, ${result.failedCount} failed');
      }

      return result;
    } catch (e) {
      result.errorMessage = 'Lỗi khi đọc CSV: ${e.toString()}';
      result.isSuccess = false;
      
      if (kDebugMode) {
        debugPrint('❌ Error importing CSV: $e');
      }
      
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
