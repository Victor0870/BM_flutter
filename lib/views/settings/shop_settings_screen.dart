import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../controllers/auth_provider.dart';
import '../../models/shop_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/responsive_container.dart';
import '../../core/routes.dart';

/// Màn hình cài đặt thông tin shop và hóa đơn điện tử
class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers cho form
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxCodeController = TextEditingController();
  
  // Controllers cho hóa đơn điện tử
  final _staxController = TextEditingController();
  final _serialController = TextEditingController();
  final _einvoiceUsernameController = TextEditingController();
  final _einvoicePasswordController = TextEditingController();
  final _einvoiceBaseUrlController = TextEditingController();
  
  // Controllers cho thanh toán
  PaymentProvider _selectedPaymentProvider = PaymentProvider.none;
  final _payosClientIdController = TextEditingController();
  final _payosApiKeyController = TextEditingController();
  final _payosChecksumKeyController = TextEditingController();
  final _bankBinController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  bool _autoConfirmPayment = true; // Tự động xác nhận tiền về
  
  // Cấu hình bán hàng & Kho
  bool _allowNegativeStock = false;
  bool _enableCostPrice = true;
  bool _allowRegistration = false;
  bool _allowQuickStockUpdate = true;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePayosApiKey = true;
  bool _obscurePayosChecksumKey = true;

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    // Load data sau khi widget được build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedOnce) {
        _loadShopData();
        _hasLoadedOnce = true;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _taxCodeController.dispose();
    _staxController.dispose();
    _serialController.dispose();
    _einvoiceUsernameController.dispose();
    _einvoicePasswordController.dispose();
    _einvoiceBaseUrlController.dispose();
    _payosClientIdController.dispose();
    _payosApiKeyController.dispose();
    _payosChecksumKeyController.dispose();
    _bankBinController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData({bool reloadFromFirestore = false}) async {
    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    
    // Chỉ reload từ Firestore nếu được yêu cầu và shop data đã có
    if (reloadFromFirestore && authProvider.shop != null) {
      if (!mounted) return;
      try {
        // Reload shop từ Firestore mà không trigger checkAuthStatus (để tránh lỗi dispose)
        final firebaseService = FirebaseService();
        final shop = await firebaseService.getShopData(authProvider.user!.uid);
        if (shop != null && mounted) {
          await authProvider.updateShop(shop);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error reloading shop from Firestore: $e');
        }
        // Nếu lỗi, vẫn dùng shop data hiện tại
      }
    }
    
    if (!mounted) return;
    
    // Nếu shop vẫn null, chỉ check một lần
    if (authProvider.shop == null && !reloadFromFirestore) {
      // Chỉ check auth status nếu shop chưa có
      if (authProvider.user != null) {
        // Thử load shop trực tiếp từ Firestore thay vì checkAuthStatus
        try {
          final firebaseService = FirebaseService();
          final shop = await firebaseService.getShopData(authProvider.user!.uid);
          if (shop != null && mounted) {
            await authProvider.updateShop(shop);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Error loading shop: $e');
          }
          return;
        }
      } else {
        return;
      }
    }
    
    if (!mounted) return;
    
    if (authProvider.shop != null) {
      final shop = authProvider.shop!;
      
      if (kDebugMode) {
        debugPrint('📥 Loading shop data:');
        debugPrint('  - paymentConfig: ${shop.paymentConfig?.toMap()}');
        debugPrint('  - paymentConfig is null: ${shop.paymentConfig == null}');
      }
      
      if (!mounted) return;
      
      setState(() {
        _nameController.text = shop.name;
        _phoneController.text = shop.phone ?? '';
        _addressController.text = shop.address ?? '';
        _emailController.text = shop.email ?? '';
        _taxCodeController.text = shop.taxCode ?? '';
        _staxController.text = shop.stax ?? '';
        _serialController.text = shop.serial ?? '';
        _einvoiceUsernameController.text = shop.einvoiceConfig?.username ?? '';
        _einvoicePasswordController.text = shop.einvoiceConfig?.password ?? '';
        _einvoiceBaseUrlController.text = shop.einvoiceConfig?.baseUrl ?? 
            'https://api-uat.einvoice.fpt.com.vn/create-icr';
        
        // Load payment config
        _selectedPaymentProvider = shop.paymentConfig?.provider ?? PaymentProvider.none;
        _payosClientIdController.text = shop.paymentConfig?.payosClientId ?? '';
        _payosApiKeyController.text = shop.paymentConfig?.payosApiKey ?? '';
        _payosChecksumKeyController.text = shop.paymentConfig?.payosChecksumKey ?? '';
        _bankBinController.text = shop.paymentConfig?.bankBin ?? '';
        _bankAccountNumberController.text = shop.paymentConfig?.bankAccountNumber ?? '';
        _bankAccountNameController.text = shop.paymentConfig?.bankAccountName ?? '';
        _autoConfirmPayment = shop.paymentConfig?.autoConfirmPayment ?? true;
        
        if (kDebugMode) {
          debugPrint('  ✅ Loaded payment config into form:');
          debugPrint('    - provider: $_selectedPaymentProvider');
          debugPrint('    - bankBin: ${_bankBinController.text}');
          debugPrint('    - bankAccountNumber: ${_bankAccountNumberController.text}');
        }
        
        // Load cấu hình bán hàng & kho
        _allowNegativeStock = shop.allowNegativeStock;
        _enableCostPrice = shop.enableCostPrice;
        _allowRegistration = shop.allowRegistration;
        _allowQuickStockUpdate = shop.allowQuickStockUpdate;
      });
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ Shop is null, cannot load data');
      }
    }
  }

  /// Lưu riêng allowRegistration khi toggle thay đổi
  Future<void> _saveAllowRegistration(bool value) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null || authProvider.shop == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Cannot save allowRegistration: user or shop is null');
        }
        return;
      }

      final currentShop = authProvider.shop!;
      final updatedShop = currentShop.copyWith(
        allowRegistration: value,
        updatedAt: DateTime.now(),
      );

      // Lưu vào Firestore
      final firebaseService = FirebaseService();
      await firebaseService.saveShopData(updatedShop);

      // Cập nhật trong AuthProvider
      await authProvider.updateShop(updatedShop);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                ? 'Đã bật cho phép nhân viên đăng ký' 
                : 'Đã tắt cho phép nhân viên đăng ký',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error saving allowRegistration: $e');
      }
      if (mounted) {
        // Revert lại giá trị cũ nếu lưu thất bại
        setState(() {
          _allowRegistration = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu cài đặt: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveShopData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null || authProvider.shop == null) {
        throw Exception('Chưa đăng nhập hoặc không tìm thấy thông tin shop');
      }

      final currentShop = authProvider.shop!;
      
      // Tạo EinvoiceConfig nếu có thông tin
      EinvoiceConfig? einvoiceConfig;
      if (_einvoiceUsernameController.text.isNotEmpty &&
          _einvoicePasswordController.text.isNotEmpty &&
          _einvoiceBaseUrlController.text.isNotEmpty) {
        einvoiceConfig = EinvoiceConfig(
          username: _einvoiceUsernameController.text.trim(),
          password: _einvoicePasswordController.text.trim(),
          baseUrl: _einvoiceBaseUrlController.text.trim(),
        );
      }

      // Tạo PaymentConfig
      // Tạo PaymentConfig nếu có provider được chọn HOẶC có bất kỳ thông tin thanh toán nào
      PaymentConfig? paymentConfig;
      final hasBankInfo = _bankBinController.text.trim().isNotEmpty &&
                          _bankAccountNumberController.text.trim().isNotEmpty;
      final hasAnyPaymentInfo = _selectedPaymentProvider != PaymentProvider.none ||
                                 hasBankInfo ||
                                 _bankAccountNameController.text.trim().isNotEmpty ||
                                 _payosClientIdController.text.trim().isNotEmpty ||
                                 _payosApiKeyController.text.trim().isNotEmpty;
      
      if (kDebugMode) {
        debugPrint('💾 Saving Payment Config:');
        debugPrint('  - provider: $_selectedPaymentProvider');
        debugPrint('  - hasBankInfo: $hasBankInfo');
        debugPrint('  - hasAnyPaymentInfo: $hasAnyPaymentInfo');
        debugPrint('  - bankBin: ${_bankBinController.text.trim()}');
        debugPrint('  - bankAccountNumber: ${_bankAccountNumberController.text.trim()}');
        debugPrint('  - bankAccountName: ${_bankAccountNameController.text.trim()}');
      }
      
      if (hasAnyPaymentInfo) {
        paymentConfig = PaymentConfig(
          provider: _selectedPaymentProvider,
          payosClientId: _payosClientIdController.text.trim().isEmpty 
              ? null : _payosClientIdController.text.trim(),
          payosApiKey: _payosApiKeyController.text.trim().isEmpty 
              ? null : _payosApiKeyController.text.trim(),
          payosChecksumKey: _payosChecksumKeyController.text.trim().isEmpty 
              ? null : _payosChecksumKeyController.text.trim(),
          bankBin: _bankBinController.text.trim().isEmpty 
              ? null : _bankBinController.text.trim(),
          bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty 
              ? null : _bankAccountNumberController.text.trim(),
          bankAccountName: _bankAccountNameController.text.trim().isEmpty 
              ? null : _bankAccountNameController.text.trim(),
          autoConfirmPayment: _autoConfirmPayment,
        );
        
        if (kDebugMode) {
          debugPrint('  ✅ PaymentConfig created: ${paymentConfig.toMap()}');
        }
      } else {
        // Nếu không có thông tin thanh toán nào, vẫn giữ nguyên paymentConfig cũ (nếu có)
        paymentConfig = currentShop.paymentConfig;
        if (kDebugMode) {
          debugPrint('  ⚠️ No payment info, keeping existing config: ${paymentConfig?.toMap()}');
        }
      }

      // Cập nhật shop model
      final updatedShop = currentShop.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        taxCode: _taxCodeController.text.trim().isEmpty ? null : _taxCodeController.text.trim(),
        stax: _staxController.text.trim().isEmpty ? null : _staxController.text.trim(),
        serial: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        einvoiceConfig: einvoiceConfig,
        paymentConfig: paymentConfig,
        allowNegativeStock: _allowNegativeStock,
        enableCostPrice: _enableCostPrice,
        allowRegistration: _allowRegistration,
        allowQuickStockUpdate: _allowQuickStockUpdate,
        updatedAt: DateTime.now(),
      );

      // Debug: Kiểm tra paymentConfig trước khi lưu
      if (kDebugMode) {
        debugPrint('💾 About to save shop with paymentConfig:');
        debugPrint('  - paymentConfig: ${updatedShop.paymentConfig?.toMap()}');
        debugPrint('  - isConfigured: ${updatedShop.paymentConfig?.isConfigured}');
        debugPrint('  - provider: ${updatedShop.paymentConfig?.provider}');
      }

      // Lưu vào Firestore
      final firebaseService = FirebaseService();
      await firebaseService.saveShopData(updatedShop);

      // Cập nhật trong AuthProvider trước (để UI cập nhật ngay)
      await authProvider.updateShop(updatedShop);
      
      // Đợi một chút để đảm bảo Firestore đã cập nhật
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      // Reload shop data từ Firestore trực tiếp (không dùng checkAuthStatus để tránh lỗi dispose)
      await _loadShopData(reloadFromFirestore: true);
      
      if (!mounted) return;
      
      // Kiểm tra lại sau khi reload
      if (kDebugMode && authProvider.shop != null) {
        debugPrint('✅ After reload, paymentConfig:');
        debugPrint('  - paymentConfig: ${authProvider.shop!.paymentConfig?.toMap()}');
        debugPrint('  - isConfigured: ${authProvider.shop!.paymentConfig?.isConfigured}');
        debugPrint('  - provider: ${authProvider.shop!.paymentConfig?.provider}');
        debugPrint('  - bankBin: ${authProvider.shop!.paymentConfig?.bankBin}');
        debugPrint('  - bankAccountNumber: ${authProvider.shop!.paymentConfig?.bankAccountNumber}');
      } else if (kDebugMode) {
        debugPrint('⚠️ Shop is null after reload!');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cài đặt thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu cài đặt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPaymentConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Cấu hình Thanh toán'),
            content: SingleChildScrollView(
              child: Form(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<PaymentProvider>(
                      initialValue: _selectedPaymentProvider,
                      decoration: const InputDecoration(
                        labelText: 'Nhà cung cấp thanh toán',
                        border: OutlineInputBorder(),
                      ),
                      items: PaymentProvider.values.map((provider) {
                        return DropdownMenuItem(
                          value: provider,
                          child: Text(provider.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedPaymentProvider = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedPaymentProvider == PaymentProvider.payos) ...[
                      TextFormField(
                        controller: _payosClientIdController,
                        decoration: const InputDecoration(
                          labelText: 'PayOS Client ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _payosApiKeyController,
                        decoration: InputDecoration(
                          labelText: 'PayOS API Key',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePayosApiKey ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _obscurePayosApiKey = !_obscurePayosApiKey;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePayosApiKey,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _payosChecksumKeyController,
                        decoration: InputDecoration(
                          labelText: 'PayOS Checksum Key',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePayosChecksumKey ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _obscurePayosChecksumKey = !_obscurePayosChecksumKey;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePayosChecksumKey,
                      ),
                    ],
                    if (_selectedPaymentProvider == PaymentProvider.casso || 
                        _selectedPaymentProvider == PaymentProvider.none) ...[
                      TextFormField(
                        controller: _bankBinController,
                        decoration: const InputDecoration(
                          labelText: 'Mã ngân hàng (Bank BIN)',
                          border: OutlineInputBorder(),
                          helperText: 'Ví dụ: 970422',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankAccountNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Số tài khoản ngân hàng',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankAccountNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên chủ tài khoản',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_selectedPaymentProvider != PaymentProvider.none) ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Tự động xác nhận tiền về'),
                        subtitle: Text(
                          _autoConfirmPayment 
                              ? 'Hệ thống tự động xác nhận khi nhận được tiền'
                              : 'Yêu cầu xác nhận thủ công',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        value: _autoConfirmPayment,
                        onChanged: (value) {
                          setDialogState(() {
                            _autoConfirmPayment = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {}); // Cập nhật UI chính
                  Navigator.pop(context);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEinvoiceConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Cấu hình Hóa đơn điện tử FPT'),
            content: SingleChildScrollView(
              child: Form(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _staxController,
                      decoration: const InputDecoration(
                        labelText: 'Mã số thuế người bán (10 hoặc 14 số)',
                        border: OutlineInputBorder(),
                        helperText: 'Ví dụ: 0123456789',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Ký hiệu hóa đơn',
                        border: OutlineInputBorder(),
                        helperText: 'Ví dụ: C25MAA',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _einvoiceUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _einvoicePasswordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _einvoiceBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        border: OutlineInputBorder(),
                        helperText: 'Môi trường Test: https://api-uat.einvoice.fpt.com.vn/create-icr',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {}); // Cập nhật UI chính
                  Navigator.pop(context);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Card hiển thị thông tin tài khoản: email, gói dịch vụ (PRO/BASIC).
  /// Layout khác nhau cho mobile và desktop (breakpoint từ responsive_container).
  Widget _buildAccountInfoCard(BuildContext context) {
    final isNarrow = isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final email = authProvider.user?.email ?? '—';
        final isPro = authProvider.isPro;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Thông tin tài khoản',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: isNarrow
                    ? _buildAccountInfoMobile(
                        context,
                        email: email,
                        isPro: isPro,
                        theme: theme,
                        colorScheme: colorScheme,
                      )
                    : _buildAccountInfoDesktop(
                        context,
                        email: email,
                        isPro: isPro,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Layout dọc cho mobile: Email rồi đến gói dịch vụ.
  Widget _buildAccountInfoMobile(
    BuildContext context, {
    required String email,
    required bool isPro,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.email_outlined, size: 20, color: colorScheme.onSurfaceVariant),
          title: Text(
            'Email đăng nhập',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: SelectableText(
            email,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPlanBadgeAndNote(
          context,
          isPro: isPro,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// Layout ngang cho desktop: Email bên trái, gói dịch vụ bên phải.
  Widget _buildAccountInfoDesktop(
    BuildContext context, {
    required String email,
    required bool isPro,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email_outlined, size: 20, color: colorScheme.onSurfaceVariant),
            title: Text(
              'Email đăng nhập',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: SelectableText(
              email,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildPlanBadgeAndNote(
            context,
            isPro: isPro,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  /// Nhãn gói dịch vụ (PRO/BASIC) và chú thích / nút Nâng cấp.
  Widget _buildPlanBadgeAndNote(
    BuildContext context, {
    required bool isPro,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPro
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPro ? 'Gói dịch vụ: PRO' : 'Gói dịch vụ: BASIC',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPro ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPro
              ? 'Đã mở khóa đồng bộ Cloud và tính năng Real-time.'
              : 'Chế độ Offline-only.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nếu bạn vừa được gia hạn/nâng cấp gói, hãy đăng xuất rồi đăng nhập lại để áp dụng.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        if (!isPro) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Liên hệ quản trị viên để nâng cấp lên gói PRO.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Nâng cấp'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            tooltip: 'Về trang chủ',
          ),
        ],
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin tài khoản
              _buildAccountInfoCard(context),
              const SizedBox(height: 16),
              // Nhóm 1: Thông tin cửa hàng
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text(
                            'Thông tin cửa hàng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên shop *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập tên shop';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Địa chỉ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Mã số thuế',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Hiển thị Shop ID và nút QR Code
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              final shopId = authProvider.shop?.id ?? '';
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  border: Border.all(color: Colors.blue.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.qr_code,
                                              size: 18,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Shop ID',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (shopId.isNotEmpty)
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return Dialog(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(20),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Text(
                                                            'Mã QR Cửa hàng',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                          Container(
                                                            width: 200,
                                                            height: 200,
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: Colors.grey.shade300),
                                                            ),
                                                            child: QrImageView(
                                                              data: shopId,
                                                              version: QrVersions.auto,
                                                              size: 200.0,
                                                              backgroundColor: Colors.white,
                                                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          SelectableText(
                                                            shopId,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.blueGrey,
                                                              fontFamily: 'monospace',
                                                            ),
                                                          ),
                                                          const SizedBox(height: 20),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: const Text('Đóng'),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                            icon: const Icon(Icons.qr_code_scanner, size: 16),
                                            label: const Text('Xem QR'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      shopId.isNotEmpty
                                          ? shopId
                                          : 'Chưa có Shop ID',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: shopId.isNotEmpty
                                            ? Colors.blue.shade900
                                            : Colors.grey,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if (shopId.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nhân viên có thể dùng Shop ID này để đăng ký tài khoản',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.store_mall_directory, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Quản lý chi nhánh'),
                      subtitle: const Text('Thêm, sửa, xóa các chi nhánh cửa hàng'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.branchManagement);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nhóm 2: Cấu hình thanh toán
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                      title: const Text(
                        'Cấu hình thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _selectedPaymentProvider != PaymentProvider.none
                            ? 'Đã cấu hình: ${_selectedPaymentProvider.value}'
                            : 'Chưa cấu hình',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: _showPaymentConfigDialog,
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Thiết lập'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nhóm 2b: Cấu hình đăng ký nhân viên & QR Shop
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(Icons.group_add, color: Theme.of(context).colorScheme.primary),
                      title: const Text(
                        'Đăng ký nhân viên qua QR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Cho phép nhân viên tự đăng ký tài khoản bằng Shop ID / QR Code',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Cho phép nhân viên đăng ký'),
                      subtitle: Text(
                        _allowRegistration
                            ? 'Nhân viên có thể dùng Shop ID để tự đăng ký, cần Admin phê duyệt'
                            : 'Tắt đăng ký nhân viên mới qua Shop ID',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _allowRegistration,
                      onChanged: _isLoading ? null : (value) async {
                        setState(() {
                          _allowRegistration = value;
                        });
                        // Tự động lưu khi toggle thay đổi
                        await _saveAllowRegistration(value);
                      },
                      secondary: Icon(
                        _allowRegistration ? Icons.check_circle : Icons.cancel,
                        color: _allowRegistration ? Colors.green : Colors.orange,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mã QR Cửa hàng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              final authProvider = context.read<AuthProvider>();
                              final shopId = authProvider.shop?.id ?? '';
                              if (shopId.isEmpty) return;

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return Dialog(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Mã QR Cửa hàng',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Container(
                                            width: 200,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: QrImageView(
                                              data: shopId,
                                              version: QrVersions.auto,
                                              size: 200.0,
                                              backgroundColor: Colors.white,
                                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SelectableText(
                                            shopId,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blueGrey,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Đóng'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.qr_code, size: 18),
                            label: const Text('Mã QR Cửa hàng'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Nhóm 3: Hóa đơn điện tử
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                      title: const Text(
                        'Hóa đơn điện tử',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _einvoiceUsernameController.text.isNotEmpty
                            ? 'Đã cấu hình'
                            : 'Chưa cấu hình',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: _showEinvoiceConfigDialog,
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Thiết lập'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nhóm 4: Cấu hình bán hàng & Kho
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text(
                            'Cấu hình bán hàng & Kho',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Cho phép bán âm kho'),
                      subtitle: Text(
                        _allowNegativeStock
                            ? 'Cho phép bán hàng ngay cả khi tồn kho không đủ'
                            : 'Không cho phép bán khi tồn kho không đủ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _allowNegativeStock,
                      onChanged: (value) {
                        setState(() {
                          _allowNegativeStock = value;
                        });
                      },
                      secondary: Icon(
                        _allowNegativeStock ? Icons.check_circle : Icons.cancel,
                        color: _allowNegativeStock ? Colors.green : Colors.orange,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Sử dụng giá nhập'),
                      subtitle: Text(
                        _enableCostPrice
                            ? 'Hiển thị và sử dụng trường giá nhập cho tính toán lợi nhuận'
                            : 'Ẩn trường giá nhập, chỉ hiển thị doanh thu',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _enableCostPrice,
                      onChanged: (value) {
                        setState(() {
                          _enableCostPrice = value;
                        });
                      },
                      secondary: Icon(
                        _enableCostPrice ? Icons.attach_money : Icons.money_off,
                        color: _enableCostPrice ? Colors.blue : Colors.grey,
                      ),
                    ),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final isAdmin = authProvider.isAdminUser;
                        return SwitchListTile(
                          title: const Text('Cho phép cập nhật nhanh tồn kho'),
                          subtitle: Text(
                            _allowQuickStockUpdate
                                ? 'Cho phép chỉnh sửa nhanh số lượng tồn kho tại danh sách sản phẩm'
                                : 'Chỉ cho phép điều chỉnh tồn kho qua Phiếu nhập kho',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          value: _allowQuickStockUpdate,
                          onChanged: isAdmin
                              ? (value) {
                                  setState(() {
                                    _allowQuickStockUpdate = value;
                                  });
                                }
                              : null,
                          secondary: Icon(
                            _allowQuickStockUpdate ? Icons.edit_note : Icons.inventory_2_outlined,
                            color: _allowQuickStockUpdate ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Nút lưu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveShopData,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Lưu cài đặt',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

