import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../services/einvoice_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/date_range_filter.dart';
import 'sale_detail_screen.dart';

/// Kết quả phát hành từng đơn (dùng cho log chi tiết phát hành hàng loạt).
class _BulkIssueResultItem {
  final String saleId;
  final String shortId;
  final bool success;
  final String? errorMessage;
  final String? invoiceNo;

  const _BulkIssueResultItem({
    required this.saleId,
    required this.shortId,
    required this.success,
    this.errorMessage,
    this.invoiceNo,
  });
}

/// Liệt kê các hóa đơn đã bán, hiển thị trạng thái HĐĐT (Đã xuất/Chưa xuất)
/// Cho phép phát hành hàng loạt và xem PDF
class EinvoiceManagementScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const EinvoiceManagementScreen({super.key, this.forceMobile});

  @override
  State<EinvoiceManagementScreen> createState() => _EinvoiceManagementScreenState();
}

class _EinvoiceManagementScreenState extends State<EinvoiceManagementScreen> {
  DateTime _startDate = DateTime.now().copyWith(day: 1); // Ngày đầu tháng
  DateTime _endDate = DateTime.now(); // Hôm nay
  String? _selectedBranchId;
  List<SaleModel> _sales = [];
  final Set<String> _selectedSaleIds = {}; // Danh sách các đơn được chọn để phát hành hàng loạt
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBulkIssuing = false;
  bool _isRefreshingStatus = false;

  // Cấu hình kết nối HĐĐT
  EinvoiceProvider _selectedProvider = EinvoiceProvider.fpt;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _appIdController = TextEditingController();
  final _templateCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _isTestingConnection = false;
  bool _isSavingConfig = false;
  bool _configExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEinvoiceConfig());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _baseUrlController.dispose();
    _appIdController.dispose();
    _templateCodeController.dispose();
    super.dispose();
  }

  void _loadEinvoiceConfig() {
    final authProvider = context.read<AuthProvider>();
    ShopModel? shop = authProvider.shop;
    if (shop == null) return;
    final config = shop.einvoiceConfig;
    setState(() {
      _selectedProvider = config?.provider ?? EinvoiceProvider.fpt;
      _usernameController.text = config?.username ?? '';
      _passwordController.text = config?.password ?? '';
      _baseUrlController.text = config?.baseUrl ?? _defaultBaseUrl(_selectedProvider);
      _appIdController.text = config?.appId ?? '';
      _templateCodeController.text = config?.templateCode ?? '';
    });
  }

  String _defaultBaseUrl(EinvoiceProvider p) {
    switch (p) {
      case EinvoiceProvider.viettel:
        return 'https://api-vinvoice.viettel.vn/services/einvoiceapplication/api';
      case EinvoiceProvider.misa:
        return 'https://testapi.meinvoice.vn';
      case EinvoiceProvider.fpt:
        return 'https://api-uat.einvoice.fpt.com.vn/create-icr';
    }
  }

  ShopModel _buildShopWithConfig() {
    final authProvider = context.read<AuthProvider>();
    final current = authProvider.shop;
    if (current == null) throw Exception('Chưa đăng nhập.');
    final config = EinvoiceConfig(
      provider: _selectedProvider,
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? _defaultBaseUrl(_selectedProvider)
          : _baseUrlController.text.trim(),
      templateCode: _templateCodeController.text.trim().isEmpty
          ? null
          : _templateCodeController.text.trim(),
      appId: _appIdController.text.trim().isEmpty
          ? null
          : _appIdController.text.trim(),
    );
    return current.copyWith(einvoiceConfig: config);
  }

  Future<void> _testConnection() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập Username và Password để kiểm tra kết nối'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedProvider == EinvoiceProvider.misa && _appIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MISA yêu cầu nhập App ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isTestingConnection = true);
    try {
      final shop = _buildShopWithConfig();
      await EinvoiceService().testConnection(shop);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối thành công! Thông tin đăng nhập chính xác.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kiểm tra kết nối thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveEinvoiceConfig() async {
    setState(() => _isSavingConfig = true);
    try {
      final shop = _buildShopWithConfig();
      await FirebaseService().saveShopData(shop);
      if (!mounted) return;
      await context.read<AuthProvider>().updateShop(shop);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cấu hình hóa đơn điện tử'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu cấu hình: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _errorMessage = 'Chưa đăng nhập';
          _isLoading = false;
        });
        return;
      }

      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final sales = await salesService.getSales(
        startDate: _startDate,
        endDate: _endDate,
        branchId: _selectedBranchId,
      );

      // Sắp xếp theo thời gian mới nhất
      sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _sales = sales;
        _isLoading = false;
        _selectedSaleIds.clear(); // Clear selection khi reload
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải danh sách hóa đơn: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildConnectionConfigCard(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _configExpanded = !_configExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_ethernet,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cấu hình kết nối hóa đơn điện tử',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _configExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (_configExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<EinvoiceProvider>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Nhà cung cấp',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: EinvoiceProvider.viettel, child: Text('Viettel')),
                      DropdownMenuItem(value: EinvoiceProvider.fpt, child: Text('FPT')),
                      DropdownMenuItem(value: EinvoiceProvider.misa, child: Text('MISA')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedProvider = v;
                          _baseUrlController.text = _defaultBaseUrl(v);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      hintText: _defaultBaseUrl(_selectedProvider),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_selectedProvider == EinvoiceProvider.misa) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appIdController,
                      decoration: const InputDecoration(
                        labelText: 'App ID (MISA)',
                        hintText: 'Do MISA cung cấp',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_selectedProvider == EinvoiceProvider.viettel) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _templateCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Mẫu hóa đơn (templateCode)',
                        hintText: '1/001',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isTestingConnection || _isSavingConfig)
                              ? null
                              : _testConnection,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(
                            _isTestingConnection ? 'Đang kiểm tra...' : 'Kiểm tra kết nối',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_isTestingConnection || _isSavingConfig)
                              ? null
                              : _saveEinvoiceConfig,
                          icon: _isSavingConfig
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(_isSavingConfig ? 'Đang lưu...' : 'Lưu cấu hình'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kiểm tra hóa đơn đã xuất hay chưa
  bool _isInvoiceIssued(SaleModel sale) {
    return sale.invoiceNo != null &&
           sale.invoiceNo!.isNotEmpty &&
           sale.einvoiceUrl != null &&
           sale.einvoiceUrl!.isNotEmpty;
  }

  /// Trích thông báo lỗi từ Exception (ưu tiên description từ API Viettel/FPT).
  static String _extractErrorMessage(dynamic e) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.substring(11).trim();
    return s;
  }

  /// Phát hành hàng loạt hóa đơn điện tử; thu thập log chi tiết và hiển thị theo desktop/mobile.
  Future<void> _bulkIssueInvoices() async {
    if (_selectedSaleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một hóa đơn để phát hành'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedSales = _sales.where((sale) => _selectedSaleIds.contains(sale.id)).toList();
    final unissuedSales = selectedSales.where((sale) => !_isInvoiceIssued(sale)).toList();

    if (unissuedSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tất cả các hóa đơn đã được phát hành'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận phát hành hàng loạt'),
        content: Text(
          'Bạn có chắc chắn muốn phát hành ${unissuedSales.length} hóa đơn điện tử?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    setState(() => _isBulkIssuing = true);

    try {
      final firebaseService = FirebaseService();
      final shop = await firebaseService.getShopData(authProvider.user!.uid);
      if (shop == null || shop.einvoiceConfig == null) {
        throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
      }

      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );
      final einvoiceService = EinvoiceService();

      final results = <_BulkIssueResultItem>[];
      for (final sale in unissuedSales) {
        final shortId = sale.id.length >= 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id;
        try {
          final info = await einvoiceService.createInvoice(
            sale: sale,
            shop: shop,
            salesService: salesService,
          );
          results.add(_BulkIssueResultItem(
            saleId: sale.id,
            shortId: shortId,
            success: true,
            invoiceNo: info['invoiceNo'],
          ));
        } catch (e) {
          results.add(_BulkIssueResultItem(
            saleId: sale.id,
            shortId: shortId,
            success: false,
            errorMessage: _extractErrorMessage(e),
          ));
        }
      }

      await _loadSales();

      if (!mounted) return;
      final successCount = results.where((r) => r.success).length;
      final failCount = results.where((r) => !r.success).length;
      if (isDesktopPlatform) {
        _showBulkResultDialogDesktop(context, results, successCount, failCount);
      } else {
        _showBulkResultDialogMobile(context, results, successCount, failCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi phát hành hàng loạt: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkIssuing = false;
          _selectedSaleIds.clear();
        });
      }
    }
  }

  /// Dialog log chi tiết phát hành hàng loạt — giao diện Desktop (rộng, bảng).
  void _showBulkResultDialogDesktop(
    BuildContext context,
    List<_BulkIssueResultItem> results,
    int successCount,
    int failCount,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Icon(
                      failCount > 0 ? Icons.info_outline : Icons.check_circle_outline,
                      color: failCount > 0 ? Colors.orange : Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kết quả phát hành hàng loạt',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Thành công: $successCount — Thất bại: $failCount',
                  style: TextStyle(
                    color: failCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('Mã đơn', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Chi tiết', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: results.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(Text(r.shortId, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: r.success ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: r.success ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                              child: Text(
                                r.success ? 'Thành công' : 'Thất bại',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: r.success ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.success ? (r.invoiceNo ?? '—') : (r.errorMessage ?? '—'),
                              style: TextStyle(
                                fontSize: 12,
                                color: r.success ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet / dialog log chi tiết phát hành hàng loạt — giao diện Mobile (danh sách thẻ).
  void _showBulkResultDialogMobile(
    BuildContext context,
    List<_BulkIssueResultItem> results,
    int successCount,
    int failCount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    failCount > 0 ? Icons.info_outline : Icons.check_circle_outline,
                    color: failCount > 0 ? Colors.orange : Colors.green,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kết quả phát hành',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Thành công: $successCount — Thất bại: $failCount',
                style: TextStyle(
                  fontSize: 13,
                  color: failCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 24),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final r = results[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                r.shortId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: r.success ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: r.success ? Colors.green.shade300 : Colors.red.shade300,
                                  ),
                                ),
                                child: Text(
                                  r.success ? 'Thành công' : 'Thất bại',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: r.success ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r.success ? 'Số HĐĐT: ${r.invoiceNo ?? "—"}' : 'Lỗi: ${r.errorMessage ?? "—"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: r.success ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Xem PDF hóa đơn điện tử
  Future<void> _viewInvoicePdf(SaleModel sale) async {
    if (sale.einvoiceUrl == null || sale.einvoiceUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có link xem hóa đơn'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(sale.einvoiceUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Không thể mở link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Bỏ chọn tất cả
  void _clearSelection() {
    setState(() {
      _selectedSaleIds.clear();
    });
  }

  /// Làm mới trạng thái hóa đơn (Viettel: tra cứu CQT để cập nhật invoiceNo khi đã cấp mã).
  Future<void> _refreshInvoiceStatuses() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) return;
    final firebaseService = FirebaseService();
    final shop = await firebaseService.getShopData(authProvider.user!.uid);
    if (shop == null || shop.einvoiceConfig == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa cấu hình hóa đơn điện tử. Chỉ hỗ trợ kiểm tra trạng thái với Viettel.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final salesToCheck = _sales.where((s) =>
        s.einvoiceUrl != null && s.einvoiceUrl!.isNotEmpty).toList();
    if (salesToCheck.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có hóa đơn nào đã gửi lên CQT để kiểm tra trạng thái.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }
    setState(() => _isRefreshingStatus = true);
    int updatedCount = 0;
    try {
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );
      final einvoiceService = EinvoiceService();
      for (final sale in salesToCheck) {
        try {
          final info = await einvoiceService.checkInvoiceStatus(
            sale: sale,
            shop: shop,
            salesService: salesService,
          );
          if (info != null && (info['invoiceNo'] ?? '').isNotEmpty) {
            updatedCount++;
          }
        } catch (_) {}
      }
      await _loadSales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedCount > 0
                  ? 'Đã cập nhật số hóa đơn cho $updatedCount đơn (CQT đã cấp mã).'
                  : 'Đã kiểm tra trạng thái. Không có thay đổi.',
            ),
            backgroundColor: updatedCount > 0 ? Colors.green : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi kiểm tra trạng thái: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final useMobile = widget.forceMobile ?? !isDesktopPlatform;
    if (useMobile) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  /// Giao diện Desktop: bảng rộng, header ngang, DataTable.
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ResponsiveContainer(
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quản lý hóa đơn điện tử',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        if (_selectedSaleIds.isNotEmpty) ...[
                          OutlinedButton.icon(
                            onPressed: _isBulkIssuing ? null : _bulkIssueInvoices,
                            icon: _isBulkIssuing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: Text(
                              _isBulkIssuing
                                  ? 'Đang phát hành...'
                                  : 'Phát hành (${_selectedSaleIds.length})',
                            ),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          TextButton(onPressed: _clearSelection, child: const Text('Bỏ chọn')),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: _isRefreshingStatus ? null : _refreshInvoiceStatuses,
                          icon: _isRefreshingStatus
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(
                              _isRefreshingStatus ? 'Đang kiểm tra...' : 'Làm mới trạng thái HĐĐT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _loadSales,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildConnectionConfigCard(context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DateRangeFilter(
                        startDate: _startDate,
                        endDate: _endDate,
                        onStartDateChanged: (d) {
                          setState(() => _startDate = d);
                          _loadSales();
                        },
                        onEndDateChanged: (d) {
                          setState(() => _endDate = d);
                          _loadSales();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Consumer<BranchProvider>(
                      builder: (context, branchProvider, _) {
                        final branches = branchProvider.branches.where((b) => b.isActive).toList();
                        return SizedBox(
                          width: 200,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButton<String?>(
                              value: _selectedBranchId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Tất cả chi nhánh')),
                                ...branches.map(
                                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedBranchId = v);
                                _loadSales();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt,
                        iconColor: Colors.blue,
                        iconBg: Colors.blue.shade50,
                        label: 'Tổng số hóa đơn',
                        value: _sales.length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        iconBg: Colors.green.shade50,
                        label: 'Đã xuất HĐĐT',
                        value: _sales.where((s) => _isInvoiceIssued(s)).length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pending,
                        iconColor: Colors.orange,
                        iconBg: Colors.orange.shade50,
                        label: 'Chưa xuất HĐĐT',
                        value: _sales.where((s) => !_isInvoiceIssued(s)).length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildDesktopContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSales, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Không có hóa đơn trong kỳ báo cáo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Mã đơn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
            DataColumn(label: Text('Ngày bán', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
            DataColumn(label: Text('Khách hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
            DataColumn(label: Text('Tổng tiền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))), numeric: true),
            DataColumn(label: Text('Trạng thái HĐĐT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
            DataColumn(label: Text('Số HĐĐT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
            DataColumn(label: SizedBox(width: 100)),
          ],
          rows: _sales.map((sale) {
            final isIssued = _isInvoiceIssued(sale);
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    sale.id.length >= 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale))),
                ),
                DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp), style: const TextStyle(fontSize: 13))),
                DataCell(Text(sale.customerName ?? 'Khách lẻ', style: const TextStyle(fontSize: 13))),
                DataCell(
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(sale.totalAmount),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIssued ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: isIssued ? Colors.green.shade300 : Colors.orange.shade300),
                    ),
                    child: Text(
                      isIssued ? 'Đã xuất' : 'Chưa xuất',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isIssued ? Colors.green.shade700 : Colors.orange.shade700),
                    ),
                  ),
                ),
                DataCell(Text(sale.invoiceNo ?? '-', style: const TextStyle(fontSize: 13))),
                DataCell(
                  isIssued
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.picture_as_pdf, size: 18), color: Colors.red, onPressed: () => _viewInvoicePdf(sale), tooltip: 'Xem PDF'),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              color: Colors.blue,
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale))),
                              tooltip: 'Xem chi tiết',
                            ),
                          ],
                        )
                      : const SizedBox(width: 100),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Giao diện Mobile: AppBar, nút gọn, danh sách thẻ (không dùng DataTable chung).
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý hóa đơn điện tử'),
        actions: [
          IconButton(
            onPressed: _isRefreshingStatus ? null : _refreshInvoiceStatuses,
            icon: _isRefreshingStatus
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'Làm mới trạng thái HĐĐT',
          ),
          IconButton(onPressed: _loadSales, icon: const Icon(Icons.refresh), tooltip: 'Tải lại'),
        ],
      ),
      body: Column(
        children: [
          ResponsiveContainer(
            maxWidth: 800,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionConfigCard(context),
                const SizedBox(height: 12),
                DateRangeFilter(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartDateChanged: (d) {
                    setState(() => _startDate = d);
                    _loadSales();
                  },
                  onEndDateChanged: (d) {
                    setState(() => _endDate = d);
                    _loadSales();
                  },
                ),
                const SizedBox(height: 12),
                Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    final branches = branchProvider.branches.where((b) => b.isActive).toList();
                    return SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String?>(
                          value: _selectedBranchId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tất cả chi nhánh')),
                            ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedBranchId = v);
                            _loadSales();
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt,
                        iconColor: Colors.blue,
                        iconBg: Colors.blue.shade50,
                        label: 'Tổng',
                        value: _sales.length.toString(),
                        suffix: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        iconBg: Colors.green.shade50,
                        label: 'Đã xuất',
                        value: _sales.where((s) => _isInvoiceIssued(s)).length.toString(),
                        suffix: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pending,
                        iconColor: Colors.orange,
                        iconBg: Colors.orange.shade50,
                        label: 'Chưa xuất',
                        value: _sales.where((s) => !_isInvoiceIssued(s)).length.toString(),
                        suffix: '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildMobileContent(context)),
        ],
      ),
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadSales, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Không có hóa đơn trong kỳ báo cáo',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        final isIssued = _isInvoiceIssued(sale);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale))),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sale.id.length >= 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isIssued ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isIssued ? Colors.green.shade300 : Colors.orange.shade300,
                          ),
                        ),
                        child: Text(
                          isIssued ? 'Đã xuất' : 'Chưa xuất',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isIssued ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    sale.customerName ?? 'Khách lẻ',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(sale.totalAmount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (isIssued) ...[
                    const SizedBox(height: 4),
                    Text('Số HĐĐT: ${sale.invoiceNo ?? "-"}', style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF'),
                          onPressed: () => _viewInvoicePdf(sale),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Chi tiết'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale))),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String suffix;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
