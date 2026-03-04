import 'package:flutter/material.dart';

import 'edit_part_dialog.dart';

/// Bản Mobile: ListView với ListTile (3 cột quan trọng: Tên xe, Đời xe, Chủng loại). Tap → popup xem/sửa toàn bộ.
class KiotVietDataGocMobile extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool loading;
  final String? error;
  final String tenXe;
  final String doiXe;
  final String chungLoai;
  final ValueChanged<String> onTenXeChanged;
  final ValueChanged<String> onDoiXeChanged;
  final ValueChanged<String> onChungLoaiChanged;
  final void Function(String tenXe, String doiXe, String chungLoai) onSearch;
  final VoidCallback onReload;
  final Future<List<String>> Function(String query) getTenXeSuggestions;
  final Future<List<String>> Function(String query) getDoiXeSuggestions;
  final Future<List<String>> Function(String query) getChungLoaiSuggestions;

  const KiotVietDataGocMobile({
    super.key,
    required this.rows,
    required this.loading,
    required this.error,
    required this.tenXe,
    required this.doiXe,
    required this.chungLoai,
    required this.onTenXeChanged,
    required this.onDoiXeChanged,
    required this.onChungLoaiChanged,
    required this.onSearch,
    required this.onReload,
    required this.getTenXeSuggestions,
    required this.getDoiXeSuggestions,
    required this.getChungLoaiSuggestions,
  });

  @override
  State<KiotVietDataGocMobile> createState() => _KiotVietDataGocMobileState();
}

class _KiotVietDataGocMobileState extends State<KiotVietDataGocMobile> {
  TextEditingController? _tenXeCtrl;
  TextEditingController? _doiXeCtrl;
  TextEditingController? _chungLoaiCtrl;

  @override
  void didUpdateWidget(covariant KiotVietDataGocMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenXe != widget.tenXe && _tenXeCtrl?.text != widget.tenXe) _tenXeCtrl?.text = widget.tenXe;
    if (oldWidget.doiXe != widget.doiXe && _doiXeCtrl?.text != widget.doiXe) _doiXeCtrl?.text = widget.doiXe;
    if (oldWidget.chungLoai != widget.chungLoai && _chungLoaiCtrl?.text != widget.chungLoai) _chungLoaiCtrl?.text = widget.chungLoai;
  }

  static Widget _optionsDropdown(Iterable<String> options, void Function(String) onSelected) {
    final optionsList = options.toList();
    if (optionsList.isEmpty) {
      return const SizedBox(width: 1, height: 1);
    }
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1, minHeight: 1, maxHeight: 200, maxWidth: 400),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: optionsList.length,
            itemBuilder: (context, index) {
              final option = optionsList[index];
              return ListTile(
                title: Text(option),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _cellValue(Map<String, dynamic> cells, String key) {
    final v = cells[key] ?? cells[key.replaceAll(' ', '_')];
    return v?.toString() ?? '';
  }

  void _openEditDialog(Map<String, dynamic> row) {
    final id = row['id'] as String? ?? '';
    final cells = Map<String, dynamic>.from(row['cells'] as Map? ?? {});
    showDialog<bool>(
      context: context,
      builder: (ctx) => EditPartDialog(
        docId: id,
        cells: cells,
        onSaved: widget.onReload,
      ),
    ).then((saved) {
      if (saved == true) widget.onReload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng dữ liệu'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: widget.onReload, tooltip: 'Tải lại'),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bộ lọc', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) return Future.value(const Iterable<String>.empty());
                      return widget.getTenXeSuggestions(value.text);
                    },
                    onSelected: (_) => widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        ),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _tenXeCtrl = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: widget.onTenXeChanged,
                        decoration: const InputDecoration(labelText: 'Tên xe', hintText: 'Nhập tên xe', border: OutlineInputBorder(), isDense: true),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        );
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) => _optionsDropdown(options, onSelected),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) return Future.value(const Iterable<String>.empty());
                      return widget.getDoiXeSuggestions(value.text);
                    },
                    onSelected: (_) => widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        ),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _doiXeCtrl = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: widget.onDoiXeChanged,
                        decoration: const InputDecoration(labelText: 'Đời xe', hintText: 'Nhập đời xe', border: OutlineInputBorder(), isDense: true),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        );
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) => _optionsDropdown(options, onSelected),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) return Future.value(const Iterable<String>.empty());
                      return widget.getChungLoaiSuggestions(value.text);
                    },
                    onSelected: (_) => widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        ),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _chungLoaiCtrl = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: widget.onChungLoaiChanged,
                        decoration: const InputDecoration(labelText: 'Chủng loại', hintText: 'Nhập chủng loại', border: OutlineInputBorder(), isDense: true),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        );
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) => _optionsDropdown(options, onSelected),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: widget.loading
                    ? null
                    : () => widget.onSearch(
                          _tenXeCtrl?.text ?? '',
                          _doiXeCtrl?.text ?? '',
                          _chungLoaiCtrl?.text ?? '',
                        ),
                    icon: widget.loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                    label: const Text('Lọc'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.error != null && widget.error!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.loading
                ? const Center(child: CircularProgressIndicator())
                : widget.rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nhập bộ lọc (Tên xe, Đời xe, Chủng loại) và bấm Lọc.',
                              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dữ liệu tra cứu từ file Excel đã lưu (Cài đặt → Nội dung Excel KiotViet).',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: widget.rows.length,
                        itemBuilder: (context, index) {
                          final row = widget.rows[index];
                          final cells = row['cells'] as Map<String, dynamic>? ?? {};
                          final tenXe = _cellValue(cells, 'Tên Xe');
                          final doiXe = _cellValue(cells, 'Đời Xe');
                          final chungLoai = _cellValue(cells, 'Chủng loại');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(tenXe.isNotEmpty ? tenXe : '—', overflow: TextOverflow.ellipsis),
                              subtitle: Text('Đời: $doiXe • $chungLoai', overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openEditDialog(row),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
