import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import '../../services/local_db_service.dart';

String _cellValue(Map<String, dynamic> cells, String key) {
  final v = cells[key] ?? cells[key.replaceAll(' ', '_')];
  return v?.toString() ?? '';
}

/// Bản Desktop: PaginatedDataTable, cột 1 = STT, các cột còn lại = keys trong cells. onRowTap → EditPartDialog.
class KiotVietDataGocDesktop extends StatefulWidget {
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

  const KiotVietDataGocDesktop({
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
  State<KiotVietDataGocDesktop> createState() => _KiotVietDataGocDesktopState();
}

class _KiotVietDataGocDesktopState extends State<KiotVietDataGocDesktop> {
  TextEditingController? _tenXeCtrl;
  TextEditingController? _doiXeCtrl;
  TextEditingController? _chungLoaiCtrl;
  /// Dòng đang chọn: hiển thị form chỉnh sửa inline phía trên bảng (giống ảnh tham chiếu).
  Map<String, dynamic>? _selectedRow;

  @override
  void didUpdateWidget(covariant KiotVietDataGocDesktop oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = _orderedCellKeys(widget.rows);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bảng dữ liệu',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bộ lọc', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
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
                                decoration: const InputDecoration(
                                  labelText: 'Tên xe',
                                  hintText: 'Nhập tên xe',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Autocomplete<String>(
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
                                decoration: const InputDecoration(
                                  labelText: 'Đời xe',
                                  hintText: 'Nhập đời xe',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Autocomplete<String>(
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
                                decoration: const InputDecoration(
                                  labelText: 'Chủng loại',
                                  hintText: 'Nhập chủng loại',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: widget.loading
                              ? null
                              : () => widget.onSearch(
                                    _tenXeCtrl?.text ?? '',
                                    _doiXeCtrl?.text ?? '',
                                    _chungLoaiCtrl?.text ?? '',
                                  ),
                          icon: const Icon(Icons.search),
                          label: const Text('Lọc'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(onPressed: widget.onReload, icon: const Icon(Icons.refresh), tooltip: 'Tải lại'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.error != null && widget.error!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (!widget.loading && widget.rows.isNotEmpty && _selectedRow != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _InlineEditPanel(
                        key: ValueKey(_selectedRow!['id']),
                        row: _selectedRow!,
                        onSaved: widget.onReload,
                        onClose: () => setState(() => _selectedRow = null),
                      ),
                    ),
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
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Dữ liệu tra cứu từ file Excel đã lưu (Cài đặt → Nội dung Excel KiotViet).',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : _DataTablePart(
                                rows: widget.rows,
                                cellKeys: keys,
                                selectedRow: _selectedRow,
                                onRowTap: (row) => setState(() => _selectedRow = row),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thứ tự cột ưu tiên: Tên xe, Đời xe, Chủng loại, Tên Phụ Tùng, rồi các cột khác (sort).
  static const List<String> _preferredColumnOrder = [
    'Tên Xe',
    'Đời Xe',
    'Chủng loại',
    'Tên Phụ Tùng',
  ];

  static List<String> _orderedCellKeys(List<Map<String, dynamic>> rows) {
    final set = <String>{};
    for (final row in rows) {
      final cells = row['cells'] as Map?;
      if (cells != null) {
        for (final k in cells.keys) {
          if (k != null) set.add(k.toString());
        }
      }
    }
    final preferred = _preferredColumnOrder.where(set.contains).toList();
    final rest = set.difference(_preferredColumnOrder.toSet()).toList()..sort();
    return [...preferred, ...rest];
  }
}

/// Panel chỉnh sửa inline nằm trong khung bảng (giống ảnh: chi tiết dòng nằm trên bảng).
class _InlineEditPanel extends StatefulWidget {
  final Map<String, dynamic> row;
  final VoidCallback onSaved;
  final VoidCallback onClose;

  const _InlineEditPanel({
    super.key,
    required this.row,
    required this.onSaved,
    required this.onClose,
  });

  @override
  State<_InlineEditPanel> createState() => _InlineEditPanelState();
}

class _InlineEditPanelState extends State<_InlineEditPanel> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _initialValues;
  bool _saving = false;

  static const List<String> _preferredOrder = ['Tên Xe', 'Đời Xe', 'Chủng loại', 'Tên Phụ Tùng'];

  List<String> get _orderedKeys {
    final set = _controllers.keys.toSet();
    final preferred = _preferredOrder.where(set.contains).toList();
    final rest = set.difference(_preferredOrder.toSet()).toList()..sort();
    return [...preferred, ...rest];
  }

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
    final cells = widget.row['cells'] as Map<String, dynamic>? ?? {};
    for (final e in cells.entries) {
      final v = e.value?.toString().trim() ?? '';
      _initialValues[e.key] = v;
      final ctrl = TextEditingController(text: v);
      ctrl.addListener(_checkChanges);
      _controllers[e.key] = ctrl;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final docId = widget.row['id'] as String? ?? '';
      final cells = <String, dynamic>{};
      for (final e in _controllers.entries) {
        cells[e.key] = e.value.text.trim();
      }
      await LocalDbService().updateGlobalPartsCatalogRow(docId, cells);
      await FirebaseService().updateGlobalPart(docId, {'cells': cells});
      if (!mounted) return;
      _initialValues = Map.fromEntries(
        _controllers.entries.map((e) => MapEntry(e.key, e.value.text.trim())),
      );
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thành công')),
      );
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
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = ((width - 40 - 2 * 20) / 3).clamp(140.0, 220.0);
    final title = _cellValue(widget.row['cells'] as Map<String, dynamic>? ?? {}, 'Tên Xe');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Chỉnh sửa dòng dữ liệu' : title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Chọn dòng trong bảng để xem hoặc chỉnh sửa',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: keys.map((k) {
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
                          border: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Đóng'),
                ),
                if (_hasChanges) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DataTablePart extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> cellKeys;
  final Map<String, dynamic>? selectedRow;
  final ValueChanged<Map<String, dynamic>> onRowTap;

  const _DataTablePart({
    required this.rows,
    required this.cellKeys,
    required this.onRowTap,
    this.selectedRow,
  });

  @override
  State<_DataTablePart> createState() => _DataTablePartState();
}

class _DataTablePartState extends State<_DataTablePart> {
  int _rowsPerPage = 25;
  int _pageIndex = 0;
  /// Ẩn/hiện từng cột: key = tên cột, value = true thì hiện. Mặc định tất cả true.
  Map<String, bool> _columnVisibility = {};

  int get _totalRows => widget.rows.length;
  int get _totalPages => _rowsPerPage <= 0 ? 1 : (_totalRows / _rowsPerPage).ceil().clamp(1, 0x7fffffff);
  int get _startIndex => (_pageIndex * _rowsPerPage).clamp(0, _totalRows);
  int get _endIndex => (_startIndex + _rowsPerPage).clamp(0, _totalRows);
  List<Map<String, dynamic>> get _pageRows => widget.rows.isEmpty ? [] : widget.rows.sublist(_startIndex, _endIndex);

  List<String> get _visibleColumns =>
      widget.cellKeys.where((c) => _columnVisibility[c] != false).toList();

  @override
  void initState() {
    super.initState();
    _columnVisibility = {for (final c in widget.cellKeys) c: true};
  }

  @override
  void didUpdateWidget(covariant _DataTablePart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cellKeys != widget.cellKeys) {
      for (final c in widget.cellKeys) {
        _columnVisibility.putIfAbsent(c, () => true);
      }
    }
    if (oldWidget.rows != widget.rows) {
      final maxPage = _totalPages;
      if (_pageIndex >= maxPage) setState(() => _pageIndex = (maxPage - 1).clamp(0, 0x7fffffff));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final bodyStyle = theme.textTheme.bodyMedium ?? theme.textTheme.bodyLarge ?? const TextStyle();
    const headerHeight = 48.0;
    const indexWidth = 48.0;

    final visibleCols = _visibleColumns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final n = visibleCols.isEmpty ? 1 : visibleCols.length;
        final dataWidth = (maxWidth - indexWidth).clamp(0.0, double.infinity);
        final colWidth = dataWidth / n;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh công cụ: số kết quả + nút ẩn/hiện cột
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('$_totalRows kết quả', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Ẩn / hiện cột',
                    icon: const Icon(Icons.view_column_outlined),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Ẩn / hiện cột'),
                          content: StatefulBuilder(
                            builder: (context, setDialogState) {
                              return SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: widget.cellKeys.map((col) {
                                    return CheckboxListTile(
                                      title: Text(col),
                                      value: _columnVisibility[col] != false,
                                      onChanged: (v) {
                                        setState(() => _columnVisibility[col] = v ?? true);
                                        setDialogState(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Xong'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Header cố định khi cuộn dọc
            SizedBox(
              height: headerHeight,
              child: Material(
                elevation: 2,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: indexWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text('#', style: headerStyle, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    ...visibleCols.map(
                      (k) => SizedBox(
                        width: colWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text(k, style: headerStyle, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Danh sách dòng (cuộn dọc, tiêu đề vẫn cố định phía trên)
            Expanded(
              child: ListView.builder(
                itemCount: _pageRows.length,
                itemBuilder: (context, i) {
                  final row = _pageRows[i];
                  final cells = row['cells'] as Map<String, dynamic>? ?? {};
                  final isSelected = widget.selectedRow != null &&
                      (widget.selectedRow!['id'] == row['id']);
                  return Material(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                        : (i.isEven ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.3)),
                    child: InkWell(
                      onTap: () => widget.onRowTap(row),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: indexWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Text('${_startIndex + i + 1}', style: bodyStyle, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          ...visibleCols.map(
                            (k) => SizedBox(
                              width: colWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Text(_cellValue(cells, k), style: bodyStyle, overflow: TextOverflow.ellipsis, maxLines: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Phân trang
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Text('Hiển thị:', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _rowsPerPage.clamp(10, 100),
                    isDense: true,
                    items: const [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                        _rowsPerPage = v;
                        if (_pageIndex >= _totalPages) _pageIndex = (_totalPages - 1).clamp(0, 0x7fffffff);
                      });
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Text('${_startIndex + 1}–$_endIndex / $_totalRows', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _pageIndex > 0 ? () => setState(() => _pageIndex--) : null,
                    tooltip: 'Trang trước',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _pageIndex < _totalPages - 1 ? () => setState(() => _pageIndex++) : null,
                    tooltip: 'Trang sau',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

