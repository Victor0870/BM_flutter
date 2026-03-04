import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_provider.dart';
import '../../services/local_db_service.dart';
import '../../utils/platform_utils.dart';
import 'kiot_viet_data_goc_desktop.dart';
import 'kiot_viet_data_goc_mobile.dart';

/// Màn hình Bảng dữ liệu (global_parts_catalog): chọn Mobile hoặc Desktop theo platform.
/// Giống trang Tra dữ liệu: không hiện gì khi chưa lọc; chỉ tải khi bấm Lọc; các ô lọc có gợi ý.
class KiotVietDataGocScreen extends StatefulWidget {
  const KiotVietDataGocScreen({super.key});

  @override
  State<KiotVietDataGocScreen> createState() => _KiotVietDataGocScreenState();
}

class _KiotVietDataGocScreenState extends State<KiotVietDataGocScreen> {
  final LocalDbService _local = LocalDbService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  String _tenXe = '';
  String _doiXe = '';
  String _chungLoai = '';

  static String _cellValue(Map<String, dynamic>? cells, String key) {
    if (cells == null) return '';
    final v = cells[key] ?? cells[key.replaceAll(' ', '_')];
    return v?.toString().trim() ?? '';
  }

  /// Parse cells từ JSON string (local DB) hoặc Map.
  static Map<String, dynamic> _parseCells(dynamic cells) {
    if (cells == null) return {};
    if (cells is Map<String, dynamic>) return cells;
    if (cells is String && cells.toString().trim().isNotEmpty) {
      try {
        final m = jsonDecode(cells) as Map<String, dynamic>?;
        return m ?? {};
      } catch (_) {}
    }
    return {};
  }

  /// Lọc theo năm đời xe khi user nhập đúng 4 chữ số (giống Tra cứu).
  static ({int start, int end})? _parseDoiXeRange(String? doiXe) {
    if (doiXe == null || doiXe.trim().isEmpty) return null;
    final numbers = RegExp(r'\d{4}').allMatches(doiXe.trim()).map((m) => int.tryParse(m.group(0) ?? '')).whereType<int>().toList();
    if (numbers.isEmpty) return null;
    return (start: numbers.first, end: numbers.length >= 2 ? numbers[1] : DateTime.now().year);
  }

  static bool _doiXeContainsYear(String? doiXe, int year) {
    final r = _parseDoiXeRange(doiXe);
    return r != null && year >= r.start && year <= r.end;
  }

  /// Chạy tìm kiếm với đúng giá trị từ ô lọc (tránh lệch khi chọn gợi ý Autocomplete).
  void _runSearch(String tenXe, String doiXe, String chungLoai) {
    final t = tenXe.trim();
    final d = doiXe.trim();
    final c = chungLoai.trim();
    setState(() {
      _tenXe = t;
      _doiXe = d;
      _chungLoai = c;
    });
    _loadDataWith(t, d, c);
  }

  Future<void> _loadDataWith(String t, String d, String c) async {
    final auth = context.read<AuthProvider>();
    if (auth.shop?.isKiotVietEnabled != true) return;
    if (t.isEmpty && d.isEmpty && c.isEmpty) {
      setState(() {
        _rows = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Nguồn dữ liệu: chỉ local (giống trang Tra cứu). Đồng bộ/ghi Firestore do trang khác.
      final hasGlobal = await _local.hasGlobalPartsCatalogData();
      if (!hasGlobal) {
        if (!mounted) return;
        setState(() {
          _rows = [];
          _loading = false;
          _error = 'Chưa có dữ liệu danh mục. Vào Cài đặt → Đồng bộ KiotViet để tải dữ liệu xuống máy.';
        });
        return;
      }
      final namSanXuatForDb = d.isEmpty ? null : (RegExp(r'^\d{4}$').hasMatch(d) ? null : d);
      var list = await _local.getGlobalPartsCatalogRowsFiltered(
        tenXe: t.isEmpty ? null : t,
        namSanXuat: namSanXuatForDb,
        chungLoaiPhuTung: c.isEmpty ? null : c,
      );
      if (RegExp(r'^\d{4}$').hasMatch(d)) {
        final year = int.tryParse(d);
        if (year != null) list = list.where((row) => _doiXeContainsYear(row['doi_xe'] as String?, year)).toList();
      }
      // Chuẩn hóa về format { id, cells } cho bảng + EditPartDialog (id = row_id local).
      final rows = list.map<Map<String, dynamic>>((row) {
        final rowId = row['row_id'] as String? ?? '';
        final cells = _parseCells(row['cells']);
        return {'id': rowId, 'cells': cells};
      }).toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _rows = [];
        _loading = false;
      });
    }
  }

  Future<List<String>> _getTenXeSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    if (_rows.isNotEmpty) {
      final q = query.trim().toLowerCase();
      final distinct = <String>{};
      for (final row in _rows) {
        final cells = row['cells'] as Map<String, dynamic>?;
        final v = _cellValue(cells, 'Tên Xe');
        if (v.isNotEmpty && (q.isEmpty || v.toLowerCase().contains(q))) distinct.add(v);
      }
      final list = distinct.toList()..sort();
      return list.take(20).toList();
    }
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (!hasGlobal) return [];
    return _local.getGlobalPartsCatalogTenXeSuggestions(
      query,
      namSanXuat: _doiXe.trim().isEmpty ? null : _doiXe.trim(),
      chungLoaiPhuTung: _chungLoai.trim().isEmpty ? null : _chungLoai.trim(),
    );
  }

  /// Gợi ý Đời xe: đã có kết quả → khoảng năm min–max từ _rows (giống Tra cứu); chưa có → lấy từ DB.
  Future<List<String>> _getDoiXeSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    if (_rows.isNotEmpty) {
      final doiXeSet = <String>{};
      for (final row in _rows) {
        final cells = row['cells'] as Map<String, dynamic>?;
        final v = _cellValue(cells, 'Đời Xe');
        if (v.isNotEmpty) doiXeSet.add(v);
      }
      int? minYear;
      int? maxYear;
      for (final d in doiXeSet) {
        final r = _parseDoiXeRange(d);
        if (r != null) {
          minYear = minYear == null ? r.start : (minYear < r.start ? minYear : r.start);
          maxYear = maxYear == null ? r.end : (maxYear > r.end ? maxYear : r.end);
        }
      }
      if (minYear == null || maxYear == null) return [];
      final years = List.generate(maxYear - minYear + 1, (i) => (minYear! + i).toString());
      final q = query.trim();
      if (q.isEmpty) return years;
      return years.where((y) => y.contains(q)).take(20).toList();
    }
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (!hasGlobal) return [];
    return _local.getGlobalPartsCatalogDoiXeSuggestions(
      query,
      tenXe: _tenXe.trim().isEmpty ? null : _tenXe.trim(),
      chungLoaiPhuTung: _chungLoai.trim().isEmpty ? null : _chungLoai.trim(),
    );
  }

  Future<List<String>> _getChungLoaiSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    if (_rows.isNotEmpty) {
      final q = query.trim().toLowerCase();
      final distinct = <String>{};
      for (final row in _rows) {
        final cells = row['cells'] as Map<String, dynamic>?;
        final v = _cellValue(cells, 'Chủng loại');
        if (v.isNotEmpty && (q.isEmpty || v.toLowerCase().contains(q))) distinct.add(v);
      }
      final list = distinct.toList()..sort();
      return list.take(20).toList();
    }
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (!hasGlobal) return [];
    return _local.getGlobalPartsCatalogChungLoaiSuggestions(
      query,
      tenXe: _tenXe.trim().isEmpty ? null : _tenXe.trim(),
      namSanXuat: _doiXe.trim().isEmpty ? null : _doiXe.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isMobilePlatform) {
      return KiotVietDataGocMobile(
        rows: _rows,
        loading: _loading,
        error: _error,
        tenXe: _tenXe,
        doiXe: _doiXe,
        chungLoai: _chungLoai,
        onTenXeChanged: (v) => setState(() => _tenXe = v),
        onDoiXeChanged: (v) => setState(() => _doiXe = v),
        onChungLoaiChanged: (v) => setState(() => _chungLoai = v),
        onSearch: (t, d, c) => _runSearch(t, d, c),
        onReload: () => _loadDataWith(_tenXe, _doiXe, _chungLoai),
        getTenXeSuggestions: _getTenXeSuggestions,
        getDoiXeSuggestions: _getDoiXeSuggestions,
        getChungLoaiSuggestions: _getChungLoaiSuggestions,
      );
    }
    return KiotVietDataGocDesktop(
      rows: _rows,
      loading: _loading,
      error: _error,
      tenXe: _tenXe,
      doiXe: _doiXe,
      chungLoai: _chungLoai,
      onTenXeChanged: (v) => setState(() => _tenXe = v),
      onDoiXeChanged: (v) => setState(() => _doiXe = v),
      onChungLoaiChanged: (v) => setState(() => _chungLoai = v),
      onSearch: (t, d, c) => _runSearch(t, d, c),
      onReload: () => _loadDataWith(_tenXe, _doiXe, _chungLoai),
      getTenXeSuggestions: _getTenXeSuggestions,
      getDoiXeSuggestions: _getDoiXeSuggestions,
      getChungLoaiSuggestions: _getChungLoaiSuggestions,
    );
  }
}
