import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/shop_model.dart';
import '../../services/einvoice_service.dart';
import '../../services/firebase_service.dart';
import '../../l10n/app_localizations.dart';

/// Màn hình chỉ cài đặt thông tin hóa đơn điện tử (không có danh sách hóa đơn).
/// Giao diện hiện đại giống scene "Nhiều hơn".
class EinvoiceSettingsScreen extends StatefulWidget {
  const EinvoiceSettingsScreen({super.key});

  @override
  State<EinvoiceSettingsScreen> createState() => _EinvoiceSettingsScreenState();
}

class _EinvoiceSettingsScreenState extends State<EinvoiceSettingsScreen> {
  EinvoiceProvider _selectedProvider = EinvoiceProvider.fpt;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _appIdController = TextEditingController();
  final _templateCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _isTestingConnection = false;
  bool _isSavingConfig = false;
  bool _deductStockOnEinvoiceOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
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

  void _loadConfig() {
    final authProvider = context.read<AuthProvider>();
    final shop = authProvider.shop;
    if (shop == null) return;
    final config = shop.einvoiceConfig;
    setState(() {
      _selectedProvider = config?.provider ?? EinvoiceProvider.fpt;
      _usernameController.text = config?.username ?? '';
      _passwordController.text = config?.password ?? '';
      _baseUrlController.text = config?.baseUrl ?? _defaultBaseUrl(_selectedProvider);
      _appIdController.text = config?.appId ?? '';
      _templateCodeController.text = config?.templateCode ?? '';
      _deductStockOnEinvoiceOnly = shop.deductStockOnEinvoiceOnly;
    });
  }

  String _defaultBaseUrl(EinvoiceProvider p) {
    switch (p) {
      case EinvoiceProvider.viettel:
        return 'https://api-vinvoice.viettel.vn/services/einvoiceapplication/api';
      case EinvoiceProvider.misa:
        return 'https://testapi.meinvoice.vn';
      case EinvoiceProvider.fpt:
        return 'https://api.einvoice.fpt.com.vn/create-icr';
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
    return current.copyWith(
      einvoiceConfig: config,
      deductStockOnEinvoiceOnly: _deductStockOnEinvoiceOnly,
    );
  }

  Future<void> _testConnection() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập Username và Password để kiểm tra kết nối'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedProvider == EinvoiceProvider.misa &&
        _appIdController.text.trim().isEmpty) {
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
            content: Text(
              'Kiểm tra kết nối thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveConfig() async {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(l10n.eInvoiceConfig),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.eInvoiceConfig,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<EinvoiceProvider>(
                    initialValue: _selectedProvider,
                    decoration: InputDecoration(
                      labelText: 'Nhà cung cấp hóa đơn điện tử',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: EinvoiceProvider.viettel,
                        child: Text('Viettel'),
                      ),
                      DropdownMenuItem(
                        value: EinvoiceProvider.fpt,
                        child: Text('FPT'),
                      ),
                      DropdownMenuItem(
                        value: EinvoiceProvider.misa,
                        child: Text('MISA'),
                      ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: 'Base URL',
                      hintText: _defaultBaseUrl(_selectedProvider),
                      filled: true,
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_selectedProvider == EinvoiceProvider.misa) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _appIdController,
                      decoration: InputDecoration(
                        labelText: 'App ID (MISA)',
                        hintText: 'Do MISA cung cấp',
                        filled: true,
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_selectedProvider == EinvoiceProvider.viettel) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _templateCodeController,
                      decoration: InputDecoration(
                        labelText: 'Mẫu hóa đơn (templateCode)',
                        hintText: '1/001',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(
                            _isTestingConnection
                                ? 'Đang kiểm tra...'
                                : 'Kiểm tra kết nối',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_isTestingConnection || _isSavingConfig)
                              ? null
                              : _saveConfig,
                          icon: _isSavingConfig
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(
                            _isSavingConfig ? 'Đang lưu...' : 'Lưu cấu hình',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TÙY CHỌN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      'Chỉ trừ kho khi phát hành hóa đơn điện tử',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Tắt: trừ kho ngay khi thanh toán. Bật: chỉ trừ kho khi xuất HĐĐT.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: _deductStockOnEinvoiceOnly,
                    onChanged: (v) => setState(() => _deductStockOnEinvoiceOnly = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
