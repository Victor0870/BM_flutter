import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_provider.dart';
import '../../services/customer_import_service.dart';

/// Dialog import khách hàng từ file Excel (.xlsx).
/// Chỉ dùng trên desktop.
class ImportCustomerDialog extends StatefulWidget {
  const ImportCustomerDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ImportCustomerDialog(),
    );
  }

  @override
  State<ImportCustomerDialog> createState() => _ImportCustomerDialogState();
}

class _ImportCustomerDialogState extends State<ImportCustomerDialog> {
  List<CustomerPreviewRow> _previewRows = [];
  bool _isLoading = false;
  bool _isImporting = false;
  double _importProgress = 0.0;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không đọc được nội dung file. Vui lòng chọn file Excel (.xlsx).'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final rows = CustomerImportService.parseExcelForPreview(file.bytes!);
      if (mounted) {
        setState(() {
          _previewRows = rows;
          _isLoading = false;
        });
      }
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
    final validRows = _previewRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    final provider = context.read<CustomerProvider>();
    final groups = provider.customerGroups;
    final groupIdByGroupName = <String, String>{};
    for (final g in groups) {
      groupIdByGroupName[g.name.trim().toLowerCase()] = g.id;
      groupIdByGroupName[g.name.trim()] = g.id;
    }

    final customers = CustomerImportService.previewRowsToCustomers(
      validRows,
      groupIdByGroupName,
      idGenerator: (i) => 'import_${DateTime.now().millisecondsSinceEpoch}_$i',
    );

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
    });

    try {
      final result = await provider.addCustomersFromList(
        customers,
        onProgress: (p) {
          if (mounted) setState(() => _importProgress = p);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã nhập ${result.successCount} khách hàng${result.failCount > 0 ? ', thất bại ${result.failCount}' : ''}.',
            ),
            backgroundColor: result.failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
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
    final validCount = _previewRows.where((r) => r.isValid).length;
    final invalidCount = _previewRows.length - validCount;

    return AlertDialog(
      title: const Text('Import khách hàng từ Excel'),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isLoading || _isImporting ? null : _pickFile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(_previewRows.isEmpty ? 'Chọn file Excel (.xlsx)' : 'Chọn file khác'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                ),
                if (_previewRows.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${_previewRows.length} dòng • $validCount hợp lệ${invalidCount > 0 ? ', $invalidCount lỗi' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_isImporting) ...[
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_chart_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Chọn file Excel (.xlsx) có cột: Mã khách hàng, Tên khách hàng, Điện thoại...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
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
                        DataColumn(label: Text('Mã', style: _headerStyle)),
                        DataColumn(label: Text('Tên khách hàng', style: _headerStyle)),
                        DataColumn(label: Text('Điện thoại', style: _headerStyle)),
                        DataColumn(label: Text('Nhóm', style: _headerStyle)),
                        DataColumn(label: Text('Trạng thái', style: _headerStyle)),
                      ],
                      rows: _previewRows.take(500).map((row) {
                        return DataRow(
                          color: WidgetStateProperty.all(
                            row.isValid ? Colors.green.shade50 : Colors.red.shade50,
                          ),
                          cells: [
                            DataCell(Text('${row.rowIndex}')),
                            DataCell(Text(row.code ?? '—')),
                            DataCell(Text(row.name)),
                            DataCell(Text(row.phone)),
                            DataCell(Text(row.groupName ?? '—')),
                            DataCell(
                              Text(
                                row.isValid ? 'Hợp lệ' : (row.errorMessage ?? 'Lỗi'),
                                style: TextStyle(
                                  color: row.isValid ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
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
            if (_previewRows.length > 500)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chỉ hiển thị 500 dòng đầu. Toàn bộ ${_previewRows.length} dòng sẽ được import khi xác nhận.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
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
