import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../../services/local_db_service.dart';

/// Thứ tự cột ưu tiên khi hiển thị form (giống bảng dữ liệu).
const List<String> _kPreferredFieldOrder = [
  'Tên Xe',
  'Đời Xe',
  'Chủng loại',
  'Tên Phụ Tùng',
];

/// Dialog chỉnh sửa một dòng global_parts_catalog.
/// Style: form sạch, ô nhập chỉ gạch chân, lưới label trên ô, thanh nút phía dưới (giống ảnh tham chiếu).
class EditPartDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> cells;
  final VoidCallback? onSaved;

  const EditPartDialog({
    super.key,
    required this.docId,
    required this.cells,
    this.onSaved,
  });

  @override
  State<EditPartDialog> createState() => _EditPartDialogState();
}

class _EditPartDialogState extends State<EditPartDialog> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _initialValues;
  bool _saving = false;

  bool get _hasChanges {
    for (final e in _controllers.entries) {
      final current = e.value.text.trim();
      if ((_initialValues[e.key] ?? '') != current) return true;
    }
    return false;
  }

  void _checkChanges() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _initialValues = {};
    for (final e in widget.cells.entries) {
      final k = e.key;
      final v = e.value?.toString().trim() ?? '';
      _initialValues[k] = v;
      final ctrl = TextEditingController(text: v);
      ctrl.addListener(_checkChanges);
      _controllers[k] = ctrl;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.removeListener(_checkChanges);
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _orderedKeys {
    final set = _controllers.keys.toSet();
    final preferred = _kPreferredFieldOrder.where(set.contains).toList();
    final rest = set.difference(_kPreferredFieldOrder.toSet()).toList()..sort();
    return [...preferred, ...rest];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cells = <String, dynamic>{};
      for (final e in _controllers.entries) {
        cells[e.key] = e.value.text.trim();
      }
      await LocalDbService().updateGlobalPartsCatalogRow(widget.docId, cells);
      await FirebaseService().updateGlobalPart(widget.docId, {'cells': cells});
      if (!mounted) return;
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thành công')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = _orderedKeys;
    final width = MediaQuery.sizeOf(context).width * 0.55.clamp(360.0, 560.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Chỉnh sửa dòng dữ liệu',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: keys.map((k) {
                    final itemWidth = ((width - 40 - 2 * 20) / 3).clamp(140.0, 220.0);
                    return SizedBox(
                      width: itemWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            k,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _controllers[k],
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                              border: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                              ),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
                  ),
                  if (_hasChanges) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
