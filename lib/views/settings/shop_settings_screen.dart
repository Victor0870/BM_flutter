import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/locale_provider.dart';
import '../../controllers/tutorial_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/routes.dart';
import '../../models/shop_model.dart';
import '../../services/firebase_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import 'shop_settings_screen_mobile.dart';
import 'shop_settings_screen_desktop.dart';

/// Màn hình cài đặt thông tin shop và hóa đơn điện tử (mobile/desktop theo platform).
class ShopSettingsScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const ShopSettingsScreen({super.key, this.forceMobile});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  final _formKey = GlobalKey<FormState>();
  final GlobalKey _guideTileKey = GlobalKey();
  
  // Controllers cho form
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxCodeController = TextEditingController();
  
  // Controllers cho hóa đơn điện tử
  EinvoiceProvider _selectedEinvoiceProvider = EinvoiceProvider.fpt;
  final _staxController = TextEditingController();
  final _serialController = TextEditingController();
  final _einvoiceTemplateCodeController = TextEditingController();
  final _einvoiceUsernameController = TextEditingController();
  final _einvoicePasswordController = TextEditingController();
  final _einvoiceBaseUrlController = TextEditingController();
  final _einvoiceAppIdController = TextEditingController();
  
  // Controllers cho thanh toán
  PaymentProvider _selectedPaymentProvider = PaymentProvider.none;
  final _payosClientIdController = TextEditingController();
  final _payosApiKeyController = TextEditingController();
  final _payosChecksumKeyController = TextEditingController();
  final _bankBinController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  bool _autoConfirmPayment = true; // Tự động xác nhận tiền về
  
  // Cấu hình KiotViet (chỉ hiển thị khi shop.isKiotVietEnabled == true)
  final _kiotRetailerController = TextEditingController();
  final _kiotClientIdController = TextEditingController();
  final _kiotClientSecretController = TextEditingController();
  bool _syncWithKiotViet = false;
  
  // Cấu hình bán hàng & Kho
  final _vatRateController = TextEditingController();
  bool _allowNegativeStock = false;
  bool _enableCostPrice = true;
  bool _allowRegistration = false;
  bool _allowQuickStockUpdate = true;
  bool _deductStockOnEinvoiceOnly = false;
  
  // Cấu hình máy in
  int _printerPaperSizeMm = 80;
  bool _autoPrintAfterPayment = false;
  final _printerNameController = TextEditingController();
  final _invoiceThankYouController = TextEditingController();
  final _invoiceReturnPolicyController = TextEditingController();
  final _vietqrAccountNumberController = TextEditingController();
  final _vietqrBankBinController = TextEditingController();
  final _vietqrBankNameController = TextEditingController();
  final _vietqrAccountNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploadingLogo = false;
  bool _isUploadingKiotVietFile = false;
  bool _obscurePassword = true;
  bool _obscurePayosApiKey = true;
  bool _obscurePayosChecksumKey = true;

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    // Đăng ký key và load data sau khi build xong để tránh setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TutorialProvider>().registerSettingsGuideTileKey(_guideTileKey);
      if (!_hasLoadedOnce) {
        _loadShopData();
        _hasLoadedOnce = true;
      }
      _runPhase2GuideHighlightIfNeeded();
    });
  }

  void _runPhase2GuideHighlightIfNeeded() {
    if (!mounted) return;
    final tutorialProvider = context.read<TutorialProvider>();
    if (!tutorialProvider.shouldHighlightGuideInSettings) return;
    final keyTarget = tutorialProvider.settingsGuideTileKey ?? TutorialKeys.instance.keySettingsGuideTile;
    final tutorial = TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'guide_tile',
          keyTarget: keyTarget,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: Text(
                AppLocalizations.of(context)!.guideTouchHint,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          enableTargetTab: true,
        ),
      ],
      onClickTarget: (target) {
        if (target.identify == 'guide_tile' && mounted) {
          tutorialProvider.clearHighlightGuideInSettings();
          _showGuideMenuDialog();
        }
      },
    );
    tutorial.show(context: context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxCodeController.dispose();
    _staxController.dispose();
    _serialController.dispose();
    _einvoiceTemplateCodeController.dispose();
    _einvoiceUsernameController.dispose();
    _einvoicePasswordController.dispose();
    _einvoiceBaseUrlController.dispose();
    _einvoiceAppIdController.dispose();
    _payosClientIdController.dispose();
    _payosApiKeyController.dispose();
    _payosChecksumKeyController.dispose();
    _bankBinController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    _kiotRetailerController.dispose();
    _kiotClientIdController.dispose();
    _kiotClientSecretController.dispose();
    _vatRateController.dispose();
    _printerNameController.dispose();
    _invoiceThankYouController.dispose();
    _invoiceReturnPolicyController.dispose();
    _vietqrAccountNumberController.dispose();
    _vietqrBankBinController.dispose();
    _vietqrBankNameController.dispose();
    _vietqrAccountNameController.dispose();
    final tp = context.read<TutorialProvider>();
    if (tp.settingsGuideTileKey == _guideTileKey) tp.clearSettingsGuideTileKey();
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
        _websiteController.text = shop.website ?? '';
        _taxCodeController.text = shop.taxCode ?? '';
        _staxController.text = shop.stax ?? '';
        _serialController.text = shop.serial ?? '';
        _selectedEinvoiceProvider = shop.einvoiceConfig?.provider ?? EinvoiceProvider.fpt;
        _einvoiceTemplateCodeController.text = shop.einvoiceConfig?.templateCode ?? '';
        _einvoiceUsernameController.text = shop.einvoiceConfig?.username ?? '';
        _einvoicePasswordController.text = shop.einvoiceConfig?.password ?? '';
        _einvoiceAppIdController.text = shop.einvoiceConfig?.appId ?? '';
        _einvoiceBaseUrlController.text = shop.einvoiceConfig?.baseUrl ?? 
            (_selectedEinvoiceProvider == EinvoiceProvider.viettel
                ? 'https://api-vinvoice.viettel.vn/services/einvoiceapplication/api'
                : _selectedEinvoiceProvider == EinvoiceProvider.misa
                    ? 'https://testapi.meinvoice.vn'
                    : 'https://api-uat.einvoice.fpt.com.vn/create-icr');
        
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
        _vatRateController.text = shop.vatRate == shop.vatRate.roundToDouble()
            ? shop.vatRate.toInt().toString()
            : shop.vatRate.toString();
        _allowNegativeStock = shop.allowNegativeStock;
        _enableCostPrice = shop.enableCostPrice;
        _allowRegistration = shop.allowRegistration;
        _allowQuickStockUpdate = shop.allowQuickStockUpdate;
        _deductStockOnEinvoiceOnly = shop.deductStockOnEinvoiceOnly;
        _printerPaperSizeMm = shop.printerPaperSizeMm == 58 ? 58 : 80;
        _autoPrintAfterPayment = shop.autoPrintAfterPayment;
        _printerNameController.text = shop.printerName ?? '';
        _invoiceThankYouController.text = shop.invoiceThankYouMessage ?? '';
        _invoiceReturnPolicyController.text = shop.invoiceReturnPolicy ?? '';
        _vietqrAccountNumberController.text = shop.vietqrAccountNumber ?? '';
        _vietqrBankBinController.text = shop.vietqrBankBin ?? '';
        _vietqrBankNameController.text = shop.vietqrBankName ?? '';
        _vietqrAccountNameController.text = shop.vietqrAccountName ?? '';
        // Load cấu hình KiotViet
        _syncWithKiotViet = shop.syncWithKiotViet;
        _kiotRetailerController.text = shop.kiotRetailer ?? '';
        _kiotClientIdController.text = shop.kiotClientId ?? '';
        _kiotClientSecretController.text = shop.kiotClientSecret ?? '';
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
            content: Text(AppLocalizations.of(context)!.errorSaveSettings(e)),
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
      final hasEinvoiceCreds = _einvoiceUsernameController.text.isNotEmpty &&
          _einvoicePasswordController.text.isNotEmpty &&
          _einvoiceBaseUrlController.text.isNotEmpty;
      final misaNeedsAppId = _selectedEinvoiceProvider == EinvoiceProvider.misa &&
          _einvoiceAppIdController.text.trim().isNotEmpty;
      if (hasEinvoiceCreds && (_selectedEinvoiceProvider != EinvoiceProvider.misa || misaNeedsAppId)) {
        einvoiceConfig = EinvoiceConfig(
          provider: _selectedEinvoiceProvider,
          username: _einvoiceUsernameController.text.trim(),
          password: _einvoicePasswordController.text.trim(),
          baseUrl: _einvoiceBaseUrlController.text.trim(),
          templateCode: _selectedEinvoiceProvider == EinvoiceProvider.viettel
              ? (_einvoiceTemplateCodeController.text.trim().isEmpty
                  ? null
                  : _einvoiceTemplateCodeController.text.trim())
              : null,
          appId: _selectedEinvoiceProvider == EinvoiceProvider.misa
              ? _einvoiceAppIdController.text.trim()
              : null,
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
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        taxCode: _taxCodeController.text.trim().isEmpty ? null : _taxCodeController.text.trim(),
        stax: _staxController.text.trim().isEmpty ? null : _staxController.text.trim(),
        serial: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        einvoiceConfig: einvoiceConfig,
        paymentConfig: paymentConfig,
        vatRate: () {
          final v = double.tryParse(_vatRateController.text.trim());
          if (v == null || v < 0) return 0.0;
          if (v > 100) return 100.0;
          return v;
        }(),
        allowNegativeStock: _allowNegativeStock,
        enableCostPrice: _enableCostPrice,
        allowRegistration: _allowRegistration,
        allowQuickStockUpdate: _allowQuickStockUpdate,
        deductStockOnEinvoiceOnly: _deductStockOnEinvoiceOnly,
        printerPaperSizeMm: _printerPaperSizeMm,
        autoPrintAfterPayment: _autoPrintAfterPayment,
        printerName: _printerNameController.text.trim().isEmpty
            ? null
            : _printerNameController.text.trim(),
        invoiceThankYouMessage: _invoiceThankYouController.text.trim().isEmpty
            ? null
            : _invoiceThankYouController.text.trim(),
        invoiceReturnPolicy: _invoiceReturnPolicyController.text.trim().isEmpty
            ? null
            : _invoiceReturnPolicyController.text.trim(),
        vietqrBankBin: _vietqrBankBinController.text.trim().isEmpty
            ? null
            : _vietqrBankBinController.text.trim(),
        vietqrBankName: _vietqrBankNameController.text.trim().isEmpty
            ? null
            : _vietqrBankNameController.text.trim(),
        vietqrAccountNumber: _vietqrAccountNumberController.text.trim().isEmpty
            ? null
            : _vietqrAccountNumberController.text.trim(),
        vietqrAccountName: _vietqrAccountNameController.text.trim().isEmpty
            ? null
            : _vietqrAccountNameController.text.trim(),
        // Cập nhật cấu hình KiotViet
        syncWithKiotViet: _syncWithKiotViet,
        kiotRetailer: _kiotRetailerController.text.trim().isEmpty
            ? null
            : _kiotRetailerController.text.trim(),
        kiotClientId: _kiotClientIdController.text.trim().isEmpty
            ? null
            : _kiotClientIdController.text.trim(),
        kiotClientSecret: _kiotClientSecretController.text.trim().isEmpty
            ? null
            : _kiotClientSecretController.text.trim(),
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

      // Đồng bộ cài đặt máy in vào SharedPreferences (dùng khi không có shop / offline)
      final localDb = LocalDbService();
      await localDb.setPrinterPaperSizeMm(_printerPaperSizeMm);
      await localDb.setAutoPrintAfterPayment(_autoPrintAfterPayment);
      await localDb.setPrinterName(
        _printerNameController.text.trim().isEmpty
            ? null
            : _printerNameController.text.trim(),
      );
      
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsSaved),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Không gọi Navigator.pop - ShopSettings hiển thị như tab trong MainScaffold,
        // pop sẽ gây màn hình đen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSaveSettings(e)),
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

  Future<void> _pickAndUploadLogo() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null || authProvider.shop == null) return;
    final shopId = authProvider.shop!.id;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await xFile.readAsBytes();
      final firebaseService = FirebaseService();
      final downloadUrl = await firebaseService.uploadShopLogo(shopId, bytes);

      if (!mounted) return;
      final currentShop = authProvider.shop!;
      final updatedShop = currentShop.copyWith(
        logoUrl: downloadUrl,
        updatedAt: DateTime.now(),
      );
      await firebaseService.saveShopData(updatedShop);
      await authProvider.updateShop(updatedShop);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.logoUploadSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error uploading logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.logoUploadError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  /// Chỉ gọi từ desktop khi syncWithKiotViet = true. Chọn file .xlsx, parse nội dung và lưu lên Firestore (WriteBatch).
  Future<void> _pickAndUploadKiotVietFile(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.shop == null) return;
    final shopId = authProvider.shop!.id;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được nội dung file. Vui lòng chọn file .xlsx khác.')),
        );
      }
      return;
    }

    setState(() => _isUploadingKiotVietFile = true);
    try {
      final firebaseService = FirebaseService();
      await firebaseService.saveKiotVietExcelContentToFirestore(shopId, bytes);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu nội dung Excel lên Firebase thành công.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error uploading KiotViet Excel file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải lên: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingKiotVietFile = false);
    }
  }

  Widget _buildLogoSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final logoUrl = authProvider.shop?.logoUrl;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Logo cửa hàng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        logoUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _logoPlaceholder(),
                      ),
                    )
                  else
                    _logoPlaceholder(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logo hiển thị trên đầu hóa đơn in.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                          icon: _isUploadingLogo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file, size: 18),
                          label: Text(_isUploadingLogo ? 'Đang tải...' : 'Chọn logo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Icon(Icons.store, size: 40, color: Colors.grey.shade500),
    );
  }

  void _showGuideMenuDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.userGuide),
        children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: Text(AppLocalizations.of(context)!.salesGuide),
            onTap: () {
              Navigator.pop(ctx);
              context.read<TutorialProvider>().setTutorialMode(true);
              Navigator.pushNamed(context, AppRoutes.sales);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: Text(AppLocalizations.of(context)!.purchaseGuide),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.purchase);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.purchaseGuideUpdating)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: Text(AppLocalizations.of(context)!.addProductGuide),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.inventory);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.addProductGuideUpdating)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.paymentConfig),
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
                        title: Text(AppLocalizations.of(context)!.autoConfirmPayment),
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
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {}); // Cập nhật UI chính
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.save),
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
            title: Text(AppLocalizations.of(context)!.eInvoiceConfig),
            content: SingleChildScrollView(
              child: Form(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bước 1: Chọn nhà cung cấp
                    DropdownButtonFormField<EinvoiceProvider>(
                      initialValue: _selectedEinvoiceProvider,
                      decoration: const InputDecoration(
                        labelText: 'Nhà cung cấp hóa đơn điện tử',
                        border: OutlineInputBorder(),
                      ),
                      items: EinvoiceProvider.values.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedEinvoiceProvider = value;
                            if (value == EinvoiceProvider.viettel &&
                                _einvoiceBaseUrlController.text.isEmpty) {
                              _einvoiceBaseUrlController.text =
                                  'https://api-vinvoice.viettel.vn/services/einvoiceapplication/api';
                            }
                            if (value == EinvoiceProvider.fpt &&
                                _einvoiceBaseUrlController.text.contains('viettel')) {
                              _einvoiceBaseUrlController.text =
                                  'https://api-uat.einvoice.fpt.com.vn/create-icr';
                            }
                            if (value == EinvoiceProvider.misa &&
                                (_einvoiceBaseUrlController.text.isEmpty ||
                                    _einvoiceBaseUrlController.text.contains('viettel') ||
                                    _einvoiceBaseUrlController.text.contains('fpt'))) {
                              _einvoiceBaseUrlController.text =
                                  'https://testapi.meinvoice.vn';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    // Bước 2: Cài đặt thông số theo nhà cung cấp
                    TextFormField(
                      controller: _staxController,
                      decoration: InputDecoration(
                        labelText: _selectedEinvoiceProvider == EinvoiceProvider.fpt
                            ? 'Mã số thuế người bán (10 hoặc 14 số)'
                            : 'Mã số thuế người bán (supplierTaxCode)',
                        border: const OutlineInputBorder(),
                        helperText: _selectedEinvoiceProvider == EinvoiceProvider.fpt
                            ? 'Ví dụ: 0123456789'
                            : 'Ví dụ: 0100109106 hoặc 0100109106-712',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serialController,
                      decoration: InputDecoration(
                        labelText: _selectedEinvoiceProvider == EinvoiceProvider.fpt
                            ? 'Ký hiệu hóa đơn'
                            : 'Ký hiệu hóa đơn (invoiceSeries)',
                        border: const OutlineInputBorder(),
                        helperText: _selectedEinvoiceProvider == EinvoiceProvider.fpt
                            ? 'Ví dụ: C25MAA'
                            : 'Ví dụ: C24AAA (TT78)',
                      ),
                    ),
                    if (_selectedEinvoiceProvider == EinvoiceProvider.viettel) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _einvoiceTemplateCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Mẫu hóa đơn (templateCode)',
                          border: OutlineInputBorder(),
                          helperText: 'Ví dụ: 1/001 (TT78)',
                        ),
                      ),
                    ],
                    if (_selectedEinvoiceProvider == EinvoiceProvider.misa) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _einvoiceAppIdController,
                        decoration: const InputDecoration(
                          labelText: 'AppID (MISA cung cấp)',
                          border: OutlineInputBorder(),
                          helperText: 'Bắt buộc cho MISA meInvoice',
                        ),
                      ),
                    ],
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
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        border: const OutlineInputBorder(),
                        helperText: _selectedEinvoiceProvider == EinvoiceProvider.fpt
                            ? 'Test: https://api-uat.einvoice.fpt.com.vn/create-icr'
                            : _selectedEinvoiceProvider == EinvoiceProvider.misa
                                ? 'Test: https://testapi.meinvoice.vn | Live: https://api.meinvoice.vn'
                                : 'Viettel: https://api-vinvoice.viettel.vn/services/einvoiceapplication/api',
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
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {}); // Cập nhật UI chính
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final currentLabel = localeProvider.locale.languageCode == 'vi'
            ? l10n.vietnamese
            : l10n.english;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      l10n.language,
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
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.public_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                  title: Text(
                    l10n.selectLanguage,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(
                    currentLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: PopupMenuButton<Locale>(
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    tooltip: l10n.selectLanguage,
                    onSelected: (locale) => localeProvider.setLocale(locale),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: const Locale('vi'),
                        child: Row(
                          children: [
                            Text('🇻🇳', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Text(l10n.vietnamese),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: const Locale('en'),
                        child: Row(
                          children: [
                            Text('🇬🇧', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Text(l10n.english),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.shopSettings),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            tooltip: AppLocalizations.of(context)!.goHome,
          ),
        ],
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: _useMobileLayout
              ? ShopSettingsMobileBody(formContent: _buildFormSections())
              : ShopSettingsDesktopBody(formContent: _buildFormSections()),
        ),
      ),
    );
  }

  /// Nội dung các section form (Account, Language, Shop info, Einvoice, ...).
  Widget _buildFormSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              // Thông tin tài khoản
              ShopSettingsAccountInfoCard(useMobileLayout: _useMobileLayout),
              const SizedBox(height: 16),
              // Ngôn ngữ
              _buildLanguageCard(context),
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
                          Text(
                            AppLocalizations.of(context)!.shopInfo,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (_useMobileLayout)
                      ListTile(
                        leading: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary, size: 22),
                        title: Text(AppLocalizations.of(context)!.accountInfo),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.accountPackage);
                        },
                      ),
                    if (_useMobileLayout) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: '${AppLocalizations.of(context)!.shopName} *',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.business),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AppLocalizations.of(context)!.pleaseEnterShopName;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.phone,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.address,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.email,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _websiteController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.website,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.language),
                              hintText: 'https://',
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 16),
                          _buildLogoSection(),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxCodeController,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.taxCode,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.badge),
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
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
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
                                                                child: Text(AppLocalizations.of(context)!.close),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                                icon: const Icon(Icons.qr_code_scanner, size: 16),
                                                label: Text(AppLocalizations.of(context)!.viewQr),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: shopId));
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Đã sao chép Shop ID vào clipboard'),
                                                        backgroundColor: Colors.green,
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.copy, size: 16),
                                                label: Text(AppLocalizations.of(context)!.copyShopId),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                      title: Text(AppLocalizations.of(context)!.branchManagementTile),
                      subtitle: Text(AppLocalizations.of(context)!.branchManagementSubtitle),
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
                      title: Text(
                        AppLocalizations.of(context)!.paymentConfigTile,
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
                        label: Text(AppLocalizations.of(context)!.setup),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cấu hình Máy in: chỉ hiển thị trên desktop; mobile dùng màn Thiết lập máy in (More → Thiết lập máy in)
              if (!_useMobileLayout) ...[
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.print, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text(
                              'Cấu hình Máy in',
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Khổ giấy mặc định',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<int>(
                              value: _printerPaperSizeMm,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 58, child: Text('Khổ 58mm (K58)')),
                                DropdownMenuItem(value: 80, child: Text('Khổ 80mm (K80)')),
                              ],
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      if (value != null) setState(() => _printerPaperSizeMm = value);
                                    },
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Tự động in sau khi thanh toán'),
                              subtitle: Text(
                                _autoPrintAfterPayment
                                    ? 'Hệ thống sẽ mở hộp thoại in hóa đơn ngay khi đơn hàng hoàn tất'
                                    : 'Chỉ in khi bạn chọn in từ chi tiết đơn hàng',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              value: _autoPrintAfterPayment,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() => _autoPrintAfterPayment = value);
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (isDesktopPlatform) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _printerNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Tên máy in',
                                  hintText: 'Ví dụ: POS-58',
                                  helperText: 'Dùng cho Silent Print đúng thiết bị trên Desktop',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.print_outlined),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Tùy chỉnh nội dung hóa đơn
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text(
                            'Tùy chỉnh nội dung hóa đơn',
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _invoiceThankYouController,
                            decoration: const InputDecoration(
                              labelText: 'Lời chào / Cảm ơn',
                              hintText: 'Cảm ơn quý khách, hẹn gặp lại!',
                              helperText: 'Hiển thị ở cuối hóa đơn',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.thumb_up_outlined),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _invoiceReturnPolicyController,
                            decoration: const InputDecoration(
                              labelText: 'Chính sách đổi trả',
                              hintText: 'Đổi trả trong vòng 7 ngày kèm hóa đơn',
                              helperText: 'In ở dưới cùng hóa đơn',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.policy_outlined),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Cấu hình VietQR (mã QR thanh toán trên hóa đơn)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _vietqrAccountNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Số tài khoản',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _vietqrBankBinController,
                            decoration: const InputDecoration(
                              labelText: 'Mã BIN ngân hàng (6 số)',
                              hintText: '970436',
                              helperText: 'Ví dụ: 970436 (Vietcombank), 970422 (VietinBank)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _vietqrBankNameController,
                            decoration: const InputDecoration(
                              labelText: 'Ngân hàng',
                              hintText: 'Vietcombank',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _vietqrAccountNameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên chủ tài khoản',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ],
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
                            ? 'Đã cấu hình: ${_selectedEinvoiceProvider.label}'
                            : 'Chưa cấu hình',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: _showEinvoiceConfigDialog,
                        icon: const Icon(Icons.settings, size: 18),
                        label: Text(AppLocalizations.of(context)!.setup),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nhóm 3b: Cấu hình đồng bộ KiotViet (chỉ hiển thị khi Admin bật isKiotVietEnabled)
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.shop?.isKiotVietEnabled != true) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.sync, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Đồng bộ KiotViet',
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
                              title: const Text('Bật đồng bộ với KiotViet'),
                              subtitle: Text(
                                _syncWithKiotViet
                                    ? 'Dữ liệu sẽ được đồng bộ với KiotViet'
                                    : 'Tắt đồng bộ với KiotViet',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              value: _syncWithKiotViet,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _syncWithKiotViet = value;
                                      });
                                    },
                              secondary: Icon(
                                _syncWithKiotViet ? Icons.sync : Icons.sync_disabled,
                                color: _syncWithKiotViet ? Colors.green : Colors.orange,
                              ),
                            ),
                            if (_syncWithKiotViet) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _kiotRetailerController,
                                      decoration: const InputDecoration(
                                        labelText: 'Tên kết nối KiotViet (Retailer)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.store),
                                        helperText: 'Ví dụ: danganhauto — dùng cho header API KiotViet',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _kiotClientIdController,
                                      decoration: const InputDecoration(
                                        labelText: 'KiotViet Client ID',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.key),
                                        helperText: 'Client ID từ cổng KiotViet',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _kiotClientSecretController,
                                      decoration: const InputDecoration(
                                        labelText: 'KiotViet Client Secret',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.lock_outline),
                                        helperText: 'Client Secret từ cổng KiotViet',
                                      ),
                                      obscureText: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Chỉ desktop + syncWithKiotViet: card lưu Excel (nút Tra dữ liệu nằm ngoài sidebar, trong layout chính)
                      if (isDesktopPlatform && _syncWithKiotViet) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.table_chart, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Nội dung Excel KiotViet (Data base danganh.xlsx)',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chọn file Excel để lưu nội dung (sheets, cột, dòng) lên Firestore. Có thể chọn lại file để cập nhật.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: authProvider.shop != null
                                      ? FirebaseService().getKiotVietFileMeta(authProvider.shop!.id)
                                      : Future.value(null),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      final uploadedAt = snapshot.data!['uploadedAt'];
                                      String? text;
                                      if (uploadedAt != null && uploadedAt is Timestamp) {
                                        final dt = uploadedAt.toDate();
                                        text = 'Đã tải lên: ${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                                      }
                                      if (text != null) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.green[700])),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isUploadingKiotVietFile
                                      ? null
                                      : () => _pickAndUploadKiotVietFile(context),
                                  icon: _isUploadingKiotVietFile
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save_alt, size: 20),
                                  label: Text(_isUploadingKiotVietFile ? 'Đang lưu nội dung...' : 'Chọn file và lưu nội dung / Cập nhật'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
              ),

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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextFormField(
                        controller: _vatRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Thuế bán hàng (%)',
                          hintText: '0',
                          helperText: 'Thuế VAT áp dụng khi thanh toán (0 = không thuế, ví dụ: 10)',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          final v = double.tryParse(value.trim());
                          if (v == null) return 'Nhập số hợp lệ';
                          if (v < 0 || v > 100) return 'Nhập từ 0 đến 100';
                          return null;
                        },
                      ),
                    ),
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
                    SwitchListTile(
                      title: const Text('Cho phép cập nhật nhanh tồn kho'),
                      subtitle: Text(
                        _allowQuickStockUpdate
                            ? 'Cho phép chỉnh sửa nhanh số lượng tồn kho tại danh sách sản phẩm'
                            : 'Chỉ cho phép điều chỉnh tồn kho qua Phiếu nhập kho',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _allowQuickStockUpdate,
                      onChanged: (value) {
                        setState(() {
                          _allowQuickStockUpdate = value;
                        });
                      },
                      secondary: Icon(
                        _allowQuickStockUpdate ? Icons.edit_note : Icons.inventory_2_outlined,
                        color: _allowQuickStockUpdate ? Colors.green : Colors.orange,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Bán hàng không trừ kho khi thanh toán'),
                      subtitle: Text(
                        _deductStockOnEinvoiceOnly
                            ? 'Chỉ trừ kho khi phát hành hóa đơn điện tử'
                            : 'Trừ kho ngay khi thanh toán',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      value: _deductStockOnEinvoiceOnly,
                      onChanged: (value) {
                        setState(() {
                          _deductStockOnEinvoiceOnly = value;
                        });
                      },
                      secondary: Icon(
                        _deductStockOnEinvoiceOnly ? Icons.receipt_long : Icons.point_of_sale,
                        color: _deductStockOnEinvoiceOnly ? Colors.blue : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hướng dẫn sử dụng
              Card(
                child: ListTile(
                  key: _guideTileKey,
                  leading: Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    AppLocalizations.of(context)!.userGuide,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(AppLocalizations.of(context)!.guideList),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showGuideMenuDialog,
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
    );
  }
}

