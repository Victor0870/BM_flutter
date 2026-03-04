import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_provider.dart';
import '../../services/kiot_api_client.dart';
import '../../services/kiot_auth_service.dart';
import '../../services/kiot_viet_sync_service.dart';
import '../../services/local_db_service.dart';

/// Màn hình Tra dữ liệu KiotViet: 3 ô lọc (Tên xe, Đời xe, Chủng loại) + bảng kết quả từ local.
class KiotVietLookupScreen extends StatefulWidget {
  const KiotVietLookupScreen({super.key});

  @override
  State<KiotVietLookupScreen> createState() => _KiotVietLookupScreenState();
}

class _KiotVietLookupScreenState extends State<KiotVietLookupScreen> {
  final LocalDbService _local = LocalDbService();
  final _doiXeController = TextEditingController();
  /// Controller do Autocomplete cung cấp (Đời xe); nếu null thì dùng _doiXeController.
  TextEditingController? _doiXeAcCtrl;
  /// Controller do Autocomplete cung cấp (Tên xe) — dùng trong _search().
  TextEditingController? _tenXeAcCtrl;
  /// Controller do Autocomplete cung cấp (Chủng loại) — dùng trong _search().
  TextEditingController? _chungLoaiAcCtrl;

  String get _doiXeValue => (_doiXeAcCtrl?.text ?? _doiXeController.text).trim();

  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _productNameLookup = {};
  bool _loading = false;
  String? _error;

  /// Đăng nhập KiotViet + danh sách chi nhánh (dùng Client ID/Secret đã lưu trong Cài đặt).
  List<KiotVietBranch> _kiotBranches = [];
  KiotVietBranch? _selectedKiotBranch;
  bool _kiotAuthLoading = false;
  String? _kiotAuthError;
  String? _kiotAccessToken;
  String? _kiotRetailer;

  /// Cache giá & tồn kho theo mã sản phẩm (từ KiotViet API, theo chi nhánh đã chọn).
  Map<String, ({double price, double onHand})> _kiotProductCache = {};
  bool _kiotProductCacheLoading = false;

  /// Cột bảng kết quả. Giá, Tồn kho lấy từ KiotViet theo chi nhánh đã chọn.
  static const List<String> _displayColumns = [
    'Tên Xe',
    'Mã sản phẩm',
    'Product code',
    'Đời Xe',
    'Chủng loại',
    'Tên Phụ Tùng',
    'Tên sản phẩm',
    'Giá',
    'Tồn kho',
    'Ghi chú',
    'Phạm vi',
    'Thực Tế Bán',
  ];

  final ScrollController _horizontalScrollController = ScrollController();

  /// Ẩn/hiện từng cột: key = tên cột, value = true thì hiện. Mặc định tất cả true.
  late Map<String, bool> _columnVisibility;

  @override
  void initState() {
    super.initState();
    _columnVisibility = {for (final c in _displayColumns) c: true};
    WidgetsBinding.instance.addPostFrameCallback((_) => _loginKiotViet());
  }

  /// Đăng nhập KiotViet: lấy token trước, rồi thử lấy danh sách chi nhánh.
  /// Nếu API chi nhánh lỗi (420): vẫn lưu token, hiển thị "Tất cả chi nhánh KiotViet" để có thể tra cứu.
  Future<void> _loginKiotViet() async {
    final auth = context.read<AuthProvider>();
    final shop = auth.shop;
    if (shop == null ||
        shop.kiotClientId == null ||
        shop.kiotClientId!.trim().isEmpty ||
        shop.kiotClientSecret == null ||
        shop.kiotClientSecret!.trim().isEmpty) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _kiotAuthLoading = true;
      _kiotAuthError = null;
    });
    final authService = KiotVietAuthService();
    String? token;

    try {
      token = await authService.getAccessToken(
        clientId: shop.kiotClientId!.trim(),
        clientSecret: shop.kiotClientSecret!.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kiotAuthError = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '');
        _kiotBranches = [];
        _selectedKiotBranch = null;
        _kiotAuthLoading = false;
      });
      return;
    }

    // Ưu tiên tên kết nối đã cấu hình (ví dụ: danganhauto), không thì chuẩn hóa từ tên cửa hàng
    String retailer = (shop.kiotRetailer ?? '').trim();
    if (retailer.isEmpty) retailer = KiotVietAuthService.normalizeRetailer(shop.name);
    if (retailer.isEmpty) retailer = shop.name.trim();
    if (retailer.isEmpty) {
      if (!mounted) return;
      setState(() {
        _kiotAuthError = 'Tên cửa hàng trống, không thể gọi API KiotViet';
        _kiotBranches = [];
        _kiotAuthLoading = false;
      });
      return;
    }

    List<KiotVietBranch> branches = [];
    try {
      branches = await authService.getBranches(retailer: retailer, accessToken: token);
    } catch (e) {
      try {
        final rawRetailer = shop.name.trim().replaceAll(RegExp(r'\s+'), '');
        if (rawRetailer.isNotEmpty && rawRetailer != retailer) {
          branches = await authService.getBranches(retailer: rawRetailer, accessToken: token);
          if (branches.isNotEmpty) retailer = rawRetailer;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _kiotBranches = branches;
      _selectedKiotBranch = null;
      _kiotAuthLoading = false;
      _kiotAuthError = null;
      _kiotAccessToken = token;
      _kiotRetailer = retailer;
    });
    // Không gọi _loadKiotProductCache() ở đây — chỉ tải khi user nhập đủ 3 bộ lọc và bấm Tra cứu.
  }

  List<String> get _visibleColumns =>
      _displayColumns.where((c) => _columnVisibility[c] != false).toList();

  /// Nhãn cột khi hiển thị (vd. Giá → Giá (K VND)).
  static String _columnHeaderLabel(String col) =>
      col == 'Giá' ? 'Giá (K VND)' : col;

  /// Xóa toàn bộ filter và bảng kết quả để nhập tìm kiếm lại.
  void _clearFiltersAndResults() {
    _doiXeController.clear();
    _tenXeAcCtrl?.clear();
    _doiXeAcCtrl?.clear();
    _chungLoaiAcCtrl?.clear();
    setState(() {
      _rows = [];
      _error = null;
      _kiotProductCache = {};
    });
  }

  /// Gộp một trang sản phẩm từ API vào [cache] (chỉ các mã trong [neededCodes]). [branchId] null = tổng tồn tất cả chi nhánh.
  void _mergeProductPageIntoCache(
    List<Map<String, dynamic>> list,
    Set<String> neededCodes,
    Map<String, ({double price, double onHand})> cache,
    int? branchId,
  ) {
    for (final p in list) {
      final code = (p['code'] as String? ?? p['Code']?.toString() ?? '').trim();
      if (code.isEmpty || !neededCodes.contains(code)) continue;
      final basePrice = (p['basePrice'] as num?)?.toDouble() ?? (p['BasePrice'] as num?)?.toDouble() ?? 0.0;
      double onHand = 0.0;
      final invList = p['inventories'] ?? p['Inventories'];
      if (invList is List) {
        for (final inv in invList) {
          final m = inv is Map ? Map<String, dynamic>.from(inv) : null;
          if (m == null) continue;
          if (branchId != null) {
            final bid = m['branchId'] is int ? m['branchId'] as int : (m['branchId'] as num?)?.toInt();
            if (bid == branchId) {
              onHand = (m['onHand'] as num? ?? m['OnHand'] as num?)?.toDouble() ?? 0.0;
              break;
            }
          } else {
            onHand += (m['onHand'] as num? ?? m['OnHand'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
      cache[code] = (price: basePrice, onHand: onHand);
    }
  }

  /// Load cache giá & tồn kho từ KiotViet chỉ cho các mã trong bảng kết quả [_rows].
  /// Gọi nhiều trang song song để giảm thời gian (dừng sớm khi đủ mã cần thiết).
  Future<void> _loadKiotProductCache() async {
    if (_kiotAccessToken == null || _kiotRetailer == null || _kiotRetailer!.isEmpty) {
      setState(() {
        _kiotProductCache = {};
        _kiotProductCacheLoading = false;
      });
      return;
    }
    final neededCodes = <String>{};
    for (final row in _rows) {
      final code = (row['product_code_full'] as String? ?? row['ma_san_pham'] as String? ?? '').trim();
      if (code.isNotEmpty) neededCodes.add(code);
    }
    if (neededCodes.isEmpty) {
      setState(() {
        _kiotProductCache = {};
        _kiotProductCacheLoading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _kiotProductCacheLoading = true);
    final cache = <String, ({double price, double onHand})>{};
    try {
      final client = KiotVietApiClientImpl(
        retailer: _kiotRetailer!,
        accessToken: _kiotAccessToken!,
      );
      const pageSize = 100;
      const parallelPages = 5;
      int currentItem = 0;
      final branchId = _selectedKiotBranch?.id;
      while (true) {
        final futures = List.generate(
          parallelPages,
          (i) => client.fetchProducts(
            pageSize: pageSize,
            currentItem: currentItem + i * pageSize,
            includeInventory: true,
            branchIds: branchId != null ? [branchId] : null,
          ),
        );
        final results = await Future.wait(futures);
        var hasMore = false;
        for (final list in results) {
          if (list.isNotEmpty) {
            _mergeProductPageIntoCache(list, neededCodes, cache, branchId);
            if (list.length >= pageSize) hasMore = true;
          }
        }
        if (neededCodes.every((c) => cache.containsKey(c))) break;
        if (!hasMore) break;
        currentItem += parallelPages * pageSize;
      }
      if (!mounted) return;
      setState(() {
        _kiotProductCache = cache;
        _kiotProductCacheLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kiotProductCache = {};
        _kiotProductCacheLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _doiXeController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final tenXe = _tenXeAcCtrl?.text.trim() ?? '';
    final doiXeInput = _doiXeValue;
    final chungLoai = _chungLoaiAcCtrl?.text.trim() ?? '';
    // Tìm kiếm cho phép 1 hoặc 2 bộ lọc. Chỉ tải giá/tồn kho từ KiotViet khi đủ 3 bộ lọc.

    final auth = context.read<AuthProvider>();
    final shopId = auth.shop?.id;
    if (shopId == null) {
      setState(() {
        _error = 'Không tìm thấy cửa hàng';
        _rows = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    // Nếu đời xe là đúng 1 năm (4 chữ số) → lọc theo khoảng năm trong Dart; không dùng LIKE ở DB.
    final isSingleYear = RegExp(r'^\d{4}$').hasMatch(doiXeInput);
    final namSanXuatForDb = doiXeInput.isEmpty
        ? null
        : (isSingleYear ? null : doiXeInput); // single year: không gửi xuống DB

    try {
      // Ưu tiên dữ liệu global_parts_catalog (đã tải về local khi đăng nhập nếu isKiotVietEnabled)
      final hasGlobalCatalog = await _local.hasGlobalPartsCatalogData();
      if (auth.shop?.isKiotVietEnabled == true && hasGlobalCatalog) {
        var list = await _local.getGlobalPartsCatalogRowsFiltered(
          tenXe: tenXe.isEmpty ? null : tenXe,
          namSanXuat: namSanXuatForDb,
          chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
        );
        if (isSingleYear) {
          final year = int.parse(doiXeInput);
          list = _filterByDoiXeYear(list, year);
        }
        list = _expandRowsByProductCodes(list);
        final productNameLookup = await _local.getProductNameLookupMap(shopId);
        list = _enrichRowsWithProductCodeLookup(list, productNameLookup);
        if (!mounted) return;
        setState(() {
          _rows = list;
          _productNameLookup = productNameLookup;
          _loading = false;
        });
        if (tenXe.isNotEmpty && doiXeInput.isNotEmpty && chungLoai.isNotEmpty) {
          _loadKiotProductCache();
        }
        return;
      }

      // Fallback: dữ liệu KiotViet theo shop (danganh từ Firestore → local)
      final hasData = await _local.hasKiotVietData(shopId);
      if (!hasData) {
        await KiotVietSyncService().syncIfNeeded(shopId);
      }
      var list = await _local.getKiotVietRowsFiltered(
        shopId,
        tenXe: tenXe.isEmpty ? null : tenXe,
        namSanXuat: namSanXuatForDb,
        chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
      );
      if (isSingleYear) {
        final year = int.parse(doiXeInput);
        list = _filterByDoiXeYear(list, year);
      }
      list = _expandRowsByProductCodes(list);
      final productNameLookup = await _local.getProductNameLookupMap(shopId);
      list = _enrichRowsWithProductCodeLookup(list, productNameLookup);
      if (!mounted) return;
      setState(() {
        _rows = list;
        _productNameLookup = productNameLookup;
        _loading = false;
      });
      if (tenXe.isNotEmpty && doiXeInput.isNotEmpty && chungLoai.isNotEmpty) {
        _loadKiotProductCache();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _rows = [];
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _parseCells(String? cellsJson) {
    if (cellsJson == null || cellsJson.isEmpty) return {};
    try {
      final m = jsonDecode(cellsJson) as Map<String, dynamic>?;
      return m ?? {};
    } catch (_) {
      return {};
    }
  }

  String _cellValue(Map<String, dynamic> row, String columnName) {
    final raw = row['cells'];
    final cells = _parseCells(raw is String ? raw : null);
    final key = columnName.replaceAll('.', '_');
    final v = cells[columnName] ?? cells[key];
    return v?.toString() ?? '';
  }

  /// Giá trị cột "Tên sản phẩm": tra Mã chéo trong bảng Productcode -> Tên sản phẩm (từ kiotviet2.xlsx).
  String _productNameForRow(Map<String, dynamic> row) {
    final maCheo = _cellValue(row, 'Mã chéo').trim();
    if (maCheo.isEmpty) return '';
    // Thử đúng key, rồi key không khoảng trắng (để khớp khi lưu từ Excel)
    return _productNameLookup[maCheo] ??
        _productNameLookup[maCheo.replaceAll(' ', '')] ??
        '';
  }

  /// Text hiển thị cho một ô (dùng cho cả bảng và copy).
  String _cellDisplayText(Map<String, dynamic> row, String col) {
    if (col == 'Mã sản phẩm') return (row['ma_san_pham'] as String? ?? '');
    if (col == 'Product code') return (row['product_code_full'] as String? ?? '');
    if (col == 'Tên sản phẩm') {
      final fromLookup = row['product_name_from_lookup'] as String? ?? '';
      if (fromLookup.isNotEmpty) return fromLookup;
      if (_productNameForRow(row).isNotEmpty) return _productNameForRow(row);
      return _cellValue(row, col);
    }
    if (col == 'Giá' || col == 'Tồn kho') {
      final code = (row['product_code_full'] as String? ?? row['ma_san_pham'] as String? ?? '').trim();
      if (code.isEmpty) return '';
      final entry = _kiotProductCache[code];
      if (entry == null) return '';
      if (col == 'Giá') return NumberFormat('#,##0').format(entry.price.toInt());
      return entry.onHand.toStringAsFixed(0);
    }
    return _cellValue(row, col);
  }

  /// Copy toàn bộ dữ liệu bảng ra clipboard (tab-separated, dòng xuống hàng).
  void _copyTableToClipboard() {
    if (_rows.isEmpty) return;
    const sep = '\t';
    final header = ['#', ..._visibleColumns.map((c) => _columnHeaderLabel(c))].join(sep);
    final lines = <String>[header];
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final cells = ['${i + 1}', ..._visibleColumns.map((c) => _cellDisplayText(row, c))];
      lines.add(cells.join(sep));
    }
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép dữ liệu bảng vào clipboard')),
      );
    }
  }

  /// Parse chuỗi Đời xe (vd. "2013-2017", "2014 - ", "2014") thành (startYear, endYear).
  /// "2014" hoặc "2014 - " → endYear = năm hiện tại. Trả về null nếu không parse được.
  static ({int start, int end})? _parseDoiXeRange(String? doiXe) {
    if (doiXe == null || doiXe.trim().isEmpty) return null;
    final s = doiXe.trim();
    final numbers = RegExp(r'\d{4}').allMatches(s).map((m) => int.tryParse(m.group(0) ?? '')).whereType<int>().toList();
    if (numbers.isEmpty) return null;
    final start = numbers.first;
    final end = numbers.length >= 2 ? numbers[1] : DateTime.now().year;
    return (start: start, end: end);
  }

  /// Kiểm tra năm [year] có nằm trong khoảng Đời xe [doiXe] không.
  static bool _doiXeContainsYear(String? doiXe, int year) {
    final range = _parseDoiXeRange(doiXe);
    if (range == null) return false;
    return year >= range.start && year <= range.end;
  }

  /// Lọc danh sách theo năm đời xe (năm nằm trong khoảng hoặc "YYYY"/"YYYY - " = từ YYYY đến hiện tại).
  List<Map<String, dynamic>> _filterByDoiXeYear(List<Map<String, dynamic>> list, int year) {
    return list.where((row) {
      final doiXe = row['doi_xe'] as String?;
      return _doiXeContainsYear(doiXe, year);
    }).toList();
  }

  /// Lấy giá trị từ cells (Map hoặc JSON string) theo tên cột (thử cả dấu cách và gạch dưới).
  static String _cellFromRow(Map<String, dynamic> row, String columnName) {
    final cells = row['cells'];
    Map<String, dynamic> map = {};
    if (cells is String && cells.isNotEmpty) {
      try {
        final decoded = jsonDecode(cells);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    } else if (cells != null && cells is Map) {
      try {
        map = Map<String, dynamic>.from(cells);
      } catch (_) {}
    }
    final v = map[columnName] ?? map[columnName.replaceAll(' ', '_')];
    return v?.toString().trim() ?? '';
  }

  /// Mở rộng mỗi dòng gốc thành 1–4 dòng: mỗi mã (Mã Masuma, Mã GSP, Mã CTR, Mã kiot) không rỗng → 1 dòng, cột "Mã sản phẩm" = mã đó. Bỏ 4 cột gốc.
  List<Map<String, dynamic>> _expandRowsByProductCodes(List<Map<String, dynamic>> list) {
    const codeColumns = ['Mã Masuma', 'Mã GSP', 'Mã CTR', 'Mã kiot'];
    final result = <Map<String, dynamic>>[];
    for (final row in list) {
      final codes = <String>[];
      for (final col in codeColumns) {
        final v = _cellFromRow(row, col);
        if (v.isNotEmpty) codes.add(v);
      }
      if (codes.isEmpty) {
        result.add({...row, 'ma_san_pham': ''});
      } else {
        for (final code in codes) {
          result.add({...row, 'ma_san_pham': code});
        }
      }
    }
    return result;
  }

  /// Chuẩn hóa chuỗi để so khớp (bỏ dấu gạch ngang, khoảng trắng, lowercase).
  static String _normalizeForMatch(String s) {
    return s
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '');
  }

  /// Bổ sung product_code_full và product_name_from_lookup. Tìm trong productNameLookup (kiotviet2.xlsx) nơi productcode chứa mã sản phẩm. Nếu nhiều product code khớp thì mỗi product code thành một dòng mới.
  List<Map<String, dynamic>> _enrichRowsWithProductCodeLookup(
    List<Map<String, dynamic>> rows,
    Map<String, String> productNameLookup,
  ) {
    if (productNameLookup.isEmpty) {
      return rows.map((row) => {...row, 'product_code_full': '', 'product_name_from_lookup': ''}).toList();
    }
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final ma = (row['ma_san_pham'] as String? ?? '').trim();
      if (ma.isEmpty) {
        result.add({...row, 'product_code_full': '', 'product_name_from_lookup': ''});
        continue;
      }
      var matches = productNameLookup.entries.where((e) {
        final code = e.key.toString().trim();
        if (code.isEmpty) return false;
        return code == ma || code.contains(ma);
      }).toList();
      if (matches.isEmpty) {
        final maNorm = _normalizeForMatch(ma);
        matches = productNameLookup.entries.where((e) {
          final code = e.key.toString().trim();
          if (code.isEmpty) return false;
          final codeNorm = _normalizeForMatch(code);
          return codeNorm.contains(maNorm);
        }).toList();
      }
      if (matches.isEmpty) {
        result.add({...row, 'product_code_full': '', 'product_name_from_lookup': ''});
      } else {
        for (final match in matches) {
          result.add({
            ...row,
            'product_code_full': match.key,
            'product_name_from_lookup': match.value,
          });
        }
      }
    }
    return result;
  }

  /// Gợi ý Tên xe: chưa tra cứu (_rows rỗng) → lấy từ DB; đã có kết quả → lấy distinct từ _rows.
  Future<List<String>> _getTenXeSuggestions(String query) async {
    if (_rows.isNotEmpty) {
      final q = query.trim().toLowerCase();
      final distinct = <String>{};
      for (final row in _rows) {
        final v = (row['ten_xe'] as String? ?? '').trim();
        if (v.isEmpty) continue;
        if (q.isEmpty || v.toLowerCase().contains(q)) distinct.add(v);
      }
      final list = distinct.toList()..sort();
      return list.take(20).toList();
    }
    final auth = context.read<AuthProvider>();
    final shopId = auth.shop?.id;
    if (shopId == null) return [];
    final doiXe = _doiXeValue;
    final chungLoai = _chungLoaiAcCtrl?.text.trim() ?? '';
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (auth.shop?.isKiotVietEnabled == true && hasGlobal) {
      return _local.getGlobalPartsCatalogTenXeSuggestions(
        query,
        namSanXuat: doiXe.isEmpty ? null : doiXe,
        chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
      );
    }
    return _local.getKiotVietTenXeSuggestions(
      shopId,
      query,
      namSanXuat: doiXe.isEmpty ? null : doiXe,
      chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
    );
  }

  /// Gợi ý Đời xe: chưa tra cứu → lấy từ DB; đã có kết quả → khoảng năm min–max từ _rows (vd. 2017-2022 và 2018-2024 → 2017..2024).
  Future<List<String>> _getDoiXeSuggestions(String query) async {
    if (_rows.isNotEmpty) {
      final doiXeSet = <String>{};
      for (final row in _rows) {
        final d = (row['doi_xe'] as String? ?? '').trim();
        if (d.isNotEmpty) doiXeSet.add(d);
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
    final auth = context.read<AuthProvider>();
    final shopId = auth.shop?.id;
    if (shopId == null) return [];
    final tenXe = _tenXeAcCtrl?.text.trim() ?? '';
    final chungLoai = _chungLoaiAcCtrl?.text.trim() ?? '';
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (auth.shop?.isKiotVietEnabled == true && hasGlobal) {
      return _local.getGlobalPartsCatalogDoiXeSuggestions(
        query,
        tenXe: tenXe.isEmpty ? null : tenXe,
        chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
      );
    }
    return _local.getKiotVietDoiXeSuggestions(
      shopId,
      query,
      tenXe: tenXe.isEmpty ? null : tenXe,
      chungLoaiPhuTung: chungLoai.isEmpty ? null : chungLoai,
    );
  }

  /// Gợi ý Chủng loại: chưa tra cứu → lấy từ DB; đã có kết quả → lấy distinct từ _rows.
  Future<List<String>> _getChungLoaiSuggestions(String query) async {
    if (_rows.isNotEmpty) {
      final q = query.trim().toLowerCase();
      final distinct = <String>{};
      for (final row in _rows) {
        final v = (row['chung_loai'] as String? ?? '').trim();
        if (v.isEmpty) continue;
        if (q.isEmpty || v.toLowerCase().contains(q)) distinct.add(v);
      }
      final list = distinct.toList()..sort();
      return list.take(20).toList();
    }
    final auth = context.read<AuthProvider>();
    final shopId = auth.shop?.id;
    if (shopId == null) return [];
    final tenXe = _tenXeAcCtrl?.text.trim() ?? '';
    final doiXe = _doiXeValue;
    final hasGlobal = await _local.hasGlobalPartsCatalogData();
    if (auth.shop?.isKiotVietEnabled == true && hasGlobal) {
      return _local.getGlobalPartsCatalogChungLoaiSuggestions(
        query,
        tenXe: tenXe.isEmpty ? null : tenXe,
        namSanXuat: doiXe.isEmpty ? null : doiXe,
      );
    }
    return _local.getKiotVietChungLoaiSuggestions(
      shopId,
      query,
      tenXe: tenXe.isEmpty ? null : tenXe,
      namSanXuat: doiXe.isEmpty ? null : doiXe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra dữ liệu'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Hàng chọn chi nhánh KiotViet (đăng nhập tự động khi đã có Client ID/Secret)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Chi nhánh KiotViet:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 12),
                if (_kiotAuthLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_kiotAuthError != null)
                  Expanded(
                    child: Text(
                      _kiotAuthError!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else if (_kiotAccessToken == null)
                  Text(
                    'Vào Cài đặt → Đồng bộ KiotViet để nhập Client ID & Secret',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                      child: DropdownButton<KiotVietBranch?>(
                        value: _selectedKiotBranch,
                        isExpanded: true,
                        hint: const Text('Chọn chi nhánh KiotViet'),
                        items: [
                          const DropdownMenuItem<KiotVietBranch?>(
                            value: null,
                            child: Text('Tất cả chi nhánh KiotViet'),
                          ),
                          ..._kiotBranches.map(
                            (b) => DropdownMenuItem<KiotVietBranch?>(
                              value: b,
                              child: Text(
                                b.name.isNotEmpty ? b.name : 'Chi nhánh KiotViet #${b.id}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (KiotVietBranch? b) {
                          setState(() {
                            _selectedKiotBranch = b;
                            _kiotProductCache = {};
                          });
                          // Giá/tồn kho theo chi nhánh mới chỉ tải khi user bấm Tra cứu lại.
                        },
                      ),
                    ),
                  ),
                if (_kiotProductCacheLoading && _kiotAccessToken != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Đang tải giá, tồn kho...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bộ lọc',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (value) async {
                              if (value.text.isEmpty) return const Iterable<String>.empty();
                              return _getTenXeSuggestions(value.text);
                            },
                            onSelected: (value) => _search(),
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              _tenXeAcCtrl = controller;
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Tên xe',
                                  hintText: 'Nhập tên xe',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) {
                                  onFieldSubmitted();
                                  _search();
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              final optionsList = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (value) async {
                              if (value.text.isEmpty) return const Iterable<String>.empty();
                              return _getDoiXeSuggestions(value.text);
                            },
                            onSelected: (value) => _search(),
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              _doiXeAcCtrl = controller;
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Đời xe',
                                  hintText: 'Nhập đời xe',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) {
                                  onFieldSubmitted();
                                  _search();
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              final optionsList = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (value) async {
                              if (value.text.isEmpty) return const Iterable<String>.empty();
                              return _getChungLoaiSuggestions(value.text);
                            },
                            onSelected: (value) => _search(),
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              _chungLoaiAcCtrl = controller;
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Chủng loại',
                                  hintText: 'Nhập chủng loại',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) {
                                  onFieldSubmitted();
                                  _search();
                                },
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              final optionsList = options.toList();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
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
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _loading ? null : _search,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Tra cứu'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _clearFiltersAndResults(),
                          icon: const Icon(Icons.clear_all, size: 20),
                          label: const Text('Xóa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if ((_error ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_rows.length} kết quả',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Sao chép dữ liệu bảng',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: _rows.isEmpty ? null : _copyTableToClipboard,
                ),
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
                                children: _displayColumns.map((col) {
                                  return CheckboxListTile(
                                    title: Text(_columnHeaderLabel(col)),
                                    value: _columnVisibility[col] != false,
                                    onChanged: (v) {
                                      if (!mounted) return;
                                      setState(() => _columnVisibility[col] = v ?? true);
                                      setDialogState(() {}); // Cập nhật trạng thái checkbox ngay trong dialog
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
          const SizedBox(height: 8),
          Expanded(
            child: _rows.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nhập bộ lọc (Tên xe, Đời xe, Chủng loại) và bấm Tra cứu.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dữ liệu tra cứu từ file Excel đã lưu (Cài đặt → Nội dung Excel KiotViet).\nChưa có kết quả? Thử đăng nhập lại để đồng bộ dữ liệu xuống máy.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _buildTableWithStickyHeader(context),
          ),
        ],
      ),
      if (_kiotProductCacheLoading) ...[
        Positioned.fill(
          child: ModalBarrier(color: Colors.black54),
        ),
        Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải giá, tồn kho từ KiotViet...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
    ),
    );
  }

  static const double _indexWidth = 48.0;

  /// Bảng luôn nằm trong màn hình: chia đều độ rộng cho các cột hiển thị.
  /// Khi ẩn cột thì các cột còn lại tự giãn ra.
  Widget _buildTableWithStickyHeader(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final bodyStyle = theme.textTheme.bodyMedium ?? theme.textTheme.bodyLarge ?? theme.textTheme.bodySmall ?? const TextStyle();
    const headerHeight = 48.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final n = _visibleColumns.isEmpty ? 1 : _visibleColumns.length;
        final dataWidth = (maxWidth - _indexWidth).clamp(0.0, double.infinity);
        final colWidth = dataWidth / n;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row (cố định phía trên)
            SizedBox(
              height: headerHeight,
              child: Material(
                elevation: 2,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: _indexWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text('#', style: headerStyle, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    ..._visibleColumns.map(
                      (col) => SizedBox(
                        width: colWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text(_columnHeaderLabel(col), style: headerStyle, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Danh sách dòng kết quả (cuộn dọc)
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  if (i < 0 || i >= _rows.length) return const SizedBox.shrink();
                  final row = _rows[i];
                  return Material(
                    color: i.isEven ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _indexWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Text('${i + 1}', style: bodyStyle, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        ..._visibleColumns.map(
                          (col) => SizedBox(
                            width: colWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: SelectableText(
                                _cellDisplayText(row, col),
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

