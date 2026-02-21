import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../services/import_service.dart';
import '../../services/product_service.dart';
import '../../controllers/auth_provider.dart';

/// Dialog chọn file CSV, xem trước và xác nhận nhập sản phẩm.
class ImportProductDialog extends StatefulWidget {
  const ImportProductDialog({super.key});

  @override
  State<ImportProductDialog> createState() => _ImportProductDialogState();
}

class _ImportProductDialogState extends State<ImportProductDialog> {
  String? _csvContent;
  List<PreviewRow> _previewRows = [];
  bool _isLoading = false;
  bool _isImporting = false;
  double _importProgress = 0.0;

  ImportService get _importService {
    final auth = context.read<AuthProvider>();
    final productService = ProductService(
      isPro: auth.isPro,
      userId: auth.user!.uid,
    );
    return ImportService(productService);
  }

  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final path = await _importService.downloadProductTemplate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null
                  ? 'Đã tải file mẫu: $path'
                  : 'File mẫu đã tạo (trên web: kiểm tra thư mục tải về).',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.single;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không đọc được nội dung file. Vui lòng chọn file CSV nhỏ hơn.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      final content = utf8.decode(file.bytes!);

      final rows = _importService.parseCsvForPreview(content);
      setState(() {
        _csvContent = content;
        _previewRows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đọc file: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmImport() async {
    if (_csvContent == null || _csvContent!.isEmpty) return;
    final validRows = _previewRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
    });
    try {
      final products = previewRowsToProducts(validRows);
      final provider = context.read<ProductProvider>();
      final result = await provider.importProductsFromList(
        products,
        onProgress: (p) {
          if (mounted) setState(() => _importProgress = p);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Đã nhập ${result.count} sản phẩm.'
                  : (result.error ?? 'Lỗi khi nhập.'),
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        if (result.success && context.mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nhập: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidRows = _previewRows.any((r) => r.isValid);

    return AlertDialog(
      title: const Text('Import sản phẩm từ file'),
      content: SizedBox(
        width: 800,
        height: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _downloadTemplate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Tải file mẫu'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Chọn file từ máy tính'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isImporting) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _importProgress),
              const SizedBox(height: 4),
              Text(
                'Đang nhập... ${(_importProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
            ],
            if (_previewRows.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Text(
                    'Chọn file CSV (định dạng trùng file mẫu) để xem trước.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else if (_previewRows.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columnSpacing: 12,
                      columns: const [
                        DataColumn(label: Text('STT', style: _headerStyle)),
                        DataColumn(label: Text('Mã SP', style: _headerStyle)),
                        DataColumn(label: Text('Tên sản phẩm', style: _headerStyle)),
                        DataColumn(label: Text('Đơn vị', style: _headerStyle)),
                        DataColumn(label: Text('Giá vốn', style: _headerStyle)),
                        DataColumn(label: Text('Giá bán', style: _headerStyle)),
                        DataColumn(label: Text('Tồn kho', style: _headerStyle)),
                        DataColumn(label: Text('Mô tả', style: _headerStyle)),
                        DataColumn(label: Text('Trạng thái', style: _headerStyle)),
                      ],
                      rows: _previewRows.map((row) {
                        return DataRow(
                          color: WidgetStateProperty.all(
                            row.isValid ? Colors.green.shade50 : Colors.red.shade50,
                          ),
                          cells: [
                            DataCell(Text('${row.rowIndex}')),
                            DataCell(Text(row.code ?? '-')),
                            DataCell(Text(row.name)),
                            DataCell(Text(row.unit)),
                            DataCell(Text(row.importPriceStr)),
                            DataCell(Text(row.priceStr)),
                            DataCell(Text(row.stockStr)),
                            DataCell(Text(row.description ?? '-')),
                            DataCell(
                              Text(
                                row.isValid ? 'Hợp lệ' : (row.errorMessage ?? 'Lỗi'),
                                style: TextStyle(
                                  color: row.isValid ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: (hasValidRows && !_isImporting) ? _confirmImport : null,
          child: _isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận nhập'),
        ),
      ],
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: Color(0xFF64748B),
);
