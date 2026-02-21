import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/sales_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/tutorial_provider.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/branch_model.dart';
import '../../models/shop_model.dart';
import '../../models/customer_model.dart';
import '../../services/local_db_service.dart';
import '../../services/payment_service.dart';
import '../../services/printing_service.dart';
import '../../widgets/payment_qr_dialog.dart';
import '../../widgets/branch_selection_dialog.dart';
import '../../utils/platform_utils.dart';
import '../../l10n/app_localizations.dart';
import 'sales_screen_data.dart';
import 'sales_screen_mobile.dart';
import 'sales_screen_desktop.dart';

/// Màn hình bán hàng (POS).
/// Bố cục theo platform: [forceMobile] từ MainScaffold hoặc [isMobilePlatform].
/// - Mobile: 1 cột, Tab "Sản phẩm" | Tab "Giỏ hàng"; sticky bottom.
/// - Desktop: 2 cột (trái: sản phẩm/giỏ, phải: khách hàng/thanh toán).
class SalesScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform]. MainScaffold truyền true (mobile) hoặc false (desktop).
  final bool? forceMobile;

  const SalesScreen({super.key, this.forceMobile});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _customerTaxCodeController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  
  // State để quản lý việc mở/đóng phần thông tin khách hàng
  bool _isCustomerInfoExpanded = false;
  
  // Debounce timer cho tìm kiếm khách hàng
  Timer? _customerSearchDebounce;
  // Gợi ý khách hàng theo số điện thoại (tìm kiếm ngay khi nhập)
  final ValueNotifier<List<CustomerModel>?> _customerPhoneSuggestionsNotifier = ValueNotifier<List<CustomerModel>?>(null);
  final FocusNode _customerPhoneFocusNode = FocusNode();
  final GlobalKey _customerPhoneFieldKeyMobile = GlobalKey();
  final GlobalKey _customerPhoneFieldKeyDesktop = GlobalKey();
  OverlayEntry? _customerSuggestionsOverlayEntry;
  /// Trì hoãn xóa overlay khi mất focus để tap vào gợi ý kịp xử lý trước (tránh xóa overlay trước khi onTap chạy).
  Timer? _customerSuggestionsDismissTimer;
  
  // Quản lý tabs
  final List<InvoiceTab> _tabs = [];
  int _activeTabId = 0;
  int _nextTabId = 2; // Tab đầu tiên luôn "Hóa đơn 1"; tab thêm mới bắt đầu từ "Hóa đơn 2"
  bool _hasCheckedBranchSelection = false; // Flag để chỉ kiểm tra một lần

  final ScrollController _leftPanelScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tạo tab đầu tiên (dùng placeholder; cập nhật tên đã localize trong addPostFrameCallback)
    final salesProvider = context.read<SalesProvider>();
    _tabs.add(InvoiceTab(
      id: 0,
      name: '1', // Placeholder - AppLocalizations chưa sẵn sàng trong initState
      salesProvider: salesProvider,
    ));
    _activeTabId = 0;
    
    _customerPhoneFocusNode.addListener(() {
      if (!_customerPhoneFocusNode.hasFocus && mounted) {
        _customerSuggestionsDismissTimer?.cancel();
        _customerSuggestionsDismissTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted) {
            _customerPhoneSuggestionsNotifier.value = null;
            _removeCustomerSuggestionsOverlay();
          }
          _customerSuggestionsDismissTimer = null;
        });
      }
    });
    // Barcode Master: máy quét Bluetooth/USB gửi mã + Enter; tự động thêm vào giỏ không cần nhấn Enter
    _productSearchController.addListener(_onProductSearchInputForBarcode);
    // Load products và set active tab sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Cập nhật tên tab đã localize (AppLocalizations chỉ có sau khi build)
        setState(() {
          _tabs[0] = InvoiceTab(
            id: 0,
            name: AppLocalizations.of(context)!.invoiceTabName('1'),
            salesProvider: salesProvider,
          );
        });
        salesProvider.setActiveTab(0);
      }
      final productProvider = context.read<ProductProvider>();
      if (!productProvider.isLoading) {
        productProvider.loadProducts();
      }
      
      // Kiểm tra và hiển thị dialog chọn chi nhánh cho Admin
      _checkAndShowBranchSelectionDialog();
      // Chế độ hướng dẫn: thêm 1 sản phẩm mẫu vào giỏ
      final tutorialProvider = context.read<TutorialProvider>();
      if (tutorialProvider.isTutorialMode && salesProvider.cart.isEmpty) {
        salesProvider.addToCart(SalesProvider.getDummyProductForTutorial(), quantity: 1, tabId: 0);
      }
    });
  }

  /// Kiểm tra và hiển thị dialog chọn chi nhánh cho Admin nếu cần
  Future<void> _checkAndShowBranchSelectionDialog() async {
    if (_hasCheckedBranchSelection) return;
    _hasCheckedBranchSelection = true;

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final branchProvider = context.read<BranchProvider>();
    final userProfile = authProvider.userProfile;

    // Chỉ xử lý cho Admin
    if (userProfile == null || !userProfile.isAdmin) {
      return;
    }

    // Đảm bảo branches đã được load
    if (branchProvider.branches.isEmpty && !branchProvider.isLoading) {
      await branchProvider.loadBranches();
    }

    // Đợi một chút để đảm bảo branches đã load xong
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final currentBranchId = branchProvider.currentBranchId;

    // Nếu chỉ có 1 chi nhánh, tự động chọn
    if (branches.length == 1) {
      if (currentBranchId != branches.first.id) {
        await branchProvider.setSelectedBranch(branches.first.id);
      }
      return;
    }

    // Nếu có >= 2 chi nhánh và chưa có chi nhánh nào được chọn, hiển thị dialog
    if (branches.length >= 2 && (currentBranchId == null || currentBranchId.isEmpty)) {
      final selectedBranchId = await BranchSelectionDialog.show(
        context,
        branches: branches,
        currentBranchId: currentBranchId,
      );

      if (selectedBranchId != null && mounted) {
        await branchProvider.setSelectedBranch(selectedBranchId);
        if (!mounted) return;
        // Refresh products để lọc theo chi nhánh mới
        final productProvider = context.read<ProductProvider>();
        await productProvider.loadProducts();
      }
    }
  }

  /// Barcode Master: máy quét Bluetooth/USB gửi mã + Enter; tự động thêm vào giỏ không cần nhấn Enter.
  void _onProductSearchInputForBarcode() {
    final text = _productSearchController.text;
    if (text.endsWith('\n') || text.endsWith('\r')) {
      final trimmed = text.replaceAll(RegExp(r'[\r\n]+$'), '').trim();
      _productSearchController.removeListener(_onProductSearchInputForBarcode);
      _productSearchController.text = '';
      _productSearchController.selection = TextSelection.collapsed(offset: 0);
      _productSearchController.addListener(_onProductSearchInputForBarcode);
      if (trimmed.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchAndAddProduct(trimmed);
        });
      }
    }
  }

  @override
  void dispose() {
    _productSearchController.removeListener(_onProductSearchInputForBarcode);
    _customerSearchDebounce?.cancel();
    _customerSuggestionsDismissTimer?.cancel();
    _removeCustomerSuggestionsOverlay();
    _customerPhoneSuggestionsNotifier.dispose();
    _customerPhoneFocusNode.dispose();
    _leftPanelScrollController.dispose();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerTaxCodeController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  void _addNewTab() {
    setState(() {
      final salesProvider = context.read<SalesProvider>();
      final newTabId = salesProvider.createNewTab();
      _tabs.add(InvoiceTab(
        id: newTabId,
        name: AppLocalizations.of(context)!.invoiceTabName('$_nextTabId'),
        salesProvider: salesProvider,
      ));
      _activeTabId = newTabId;
      _nextTabId++;
    });
  }

  void _removeTab(int id) {
    if (_tabs.length <= 1) return; // Không cho xóa tab cuối cùng
    
    setState(() {
      final salesProvider = context.read<SalesProvider>();
      salesProvider.removeTab(id);
      _tabs.removeWhere((tab) => tab.id == id);
      if (_activeTabId == id) {
        _activeTabId = _tabs.first.id;
        salesProvider.setActiveTab(_activeTabId);
      }
    });
  }

  void _setActiveTab(int id) {
    setState(() {
      _activeTabId = id;
      // Đảm bảo SalesProvider biết tab hiện tại
      final salesProvider = context.read<SalesProvider>();
      salesProvider.setActiveTab(id);
    });
  }
  
  /// Xử lý khi nhập số điện thoại - Tìm kiếm ngay và hiện gợi ý khách hàng.
  /// Nếu đã chọn khách từ gợi ý mà user sửa SĐT thì xóa chọn và xóa tên/địa chỉ (coi như nhập khách mới), rồi gọi gợi ý lại.
  void _onCustomerPhoneChanged(String phone) {
    _customerSearchDebounce?.cancel();
    final trimmed = phone.trim();
    final salesProvider = context.read<SalesProvider>();
    final selected = salesProvider.getSelectedCustomer(_activeTabId);

    if (trimmed.length < 3) {
      _customerPhoneSuggestionsNotifier.value = null;
      _removeCustomerSuggestionsOverlay();
      if (selected != null) {
        salesProvider.clearCustomerSelection(tabId: _activeTabId);
        _customerNameController.clear();
        _customerAddressController.clear();
        _customerTaxCodeController.clear();
      }
      return;
    }

    // Đã chọn khách từ gợi ý nhưng user sửa SĐT → xóa chọn, xóa tên/địa chỉ, sau đó gọi gợi ý lại
    if (selected != null && trimmed != selected.phone.trim()) {
      salesProvider.clearCustomerSelection(tabId: _activeTabId);
      _customerNameController.clear();
      _customerAddressController.clear();
      _customerTaxCodeController.clear();
    }

    // Tìm kiếm ngay (debounce ngắn để gợi ý kịp thời)
    _customerSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      final salesProvider = context.read<SalesProvider>();
      final customers = await salesProvider.searchCustomers(trimmed);
      if (!mounted) return;
      _customerPhoneSuggestionsNotifier.value = customers.isEmpty ? null : customers;
      if (customers.isNotEmpty) {
        _removeCustomerSuggestionsOverlay();
        _showCustomerSuggestionsOverlay(customers, salesProvider);
      } else {
        // Số điện thoại mới, không có gợi ý → ẩn popup gợi ý
        _removeCustomerSuggestionsOverlay();
      }
    });
  }

  void _removeCustomerSuggestionsOverlay() {
    _customerSuggestionsOverlayEntry?.remove();
    _customerSuggestionsOverlayEntry = null;
  }

  /// Hiện popup gợi ý trong Overlay, sát ngay dưới ô SĐT (dùng GlobalKey để lấy vị trí).
  void _showCustomerSuggestionsOverlay(List<CustomerModel> list, SalesProvider salesProvider) {
    final overlay = Overlay.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Dùng key tương ứng với widget đang hiển thị (mobile bottom sheet hoặc desktop panel)
      final ctx = _customerPhoneFieldKeyDesktop.currentContext ?? _customerPhoneFieldKeyMobile.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;

      _customerSuggestionsOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: pos.dx,
        top: pos.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          shadowColor: Colors.black26,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final c = list[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    c.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    _customerSuggestionsDismissTimer?.cancel();
                    _customerSuggestionsDismissTimer = null;
                    _removeCustomerSuggestionsOverlay();
                    _pickCustomerSuggestion(c, salesProvider);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
      overlay.insert(_customerSuggestionsOverlayEntry!);
    });
  }

  /// Ẩn gợi ý và chọn khách hàng (gọi sau khi user chọn 1 item trong danh sách gợi ý)
  Future<void> _pickCustomerSuggestion(CustomerModel customer, SalesProvider salesProvider) async {
    _customerPhoneSuggestionsNotifier.value = null;
    await _selectCustomer(customer, salesProvider);
  }

  /// Chọn khách hàng và tự động điền thông tin
  Future<void> _selectCustomer(CustomerModel customer, SalesProvider salesProvider) async {
    // Set customer trong provider và áp dụng chiết khấu
    // setSelectedCustomerWithDiscount sẽ tự động điền name, phone, address
    await salesProvider.setSelectedCustomerWithDiscount(customer, tabId: _activeTabId);
    
    // Điền thông tin vào các trường input (để hiển thị trong form)
    _customerNameController.text = customer.name;
    _customerPhoneController.text = customer.phone;
    _customerAddressController.text = customer.address ?? '';
    
    // Tự động mở phần thông tin khách hàng nếu chưa mở
    if (!_isCustomerInfoExpanded) {
      setState(() {
        _isCustomerInfoExpanded = true;
      });
    }
  }
  
  /// Gọi PrintingService khi bật "Tự động in sau khi thanh toán" (từ shop hoặc SharedPreferences) và có đơn vừa hoàn tất.
  Future<void> _maybeAutoPrint(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final salesProvider = context.read<SalesProvider>();
    final shop = authProvider.shop;
    final sale = salesProvider.lastCompletedSale;
    final shouldPrint = shop?.autoPrintAfterPayment ?? await LocalDbService().getAutoPrintAfterPayment();
    if (!shouldPrint || sale == null) return;
    salesProvider.clearLastCompletedSale();
    final paperMm = shop != null && (shop.printerPaperSizeMm == 58 || shop.printerPaperSizeMm == 80)
        ? shop.printerPaperSizeMm
        : await LocalDbService().getPrinterPaperSizeMm();
    final printerNameOverride = shop?.printerName ?? await LocalDbService().getPrinterName();
    if (!context.mounted) return;
    PrintingService.requestPrint(
      context,
      sale: sale,
      shop: shop,
      paperMmOverride: paperMm,
      printerNameOverride: printerNameOverride,
    );
  }

  /// Xử lý sau khi thanh toán thành công
  /// Tự động đóng tab nếu không phải là tab duy nhất, hoặc reset về trạng thái trống
  void _handlePostCheckout(int tabId) {
    setState(() {
      if (_tabs.length > 1) {
        // Nếu có nhiều tab, đóng tab vừa thanh toán
        _tabs.removeWhere((tab) => tab.id == tabId);
        
        // Chuyển sang tab khác
        if (_tabs.isNotEmpty) {
          _activeTabId = _tabs.first.id;
          final salesProvider = context.read<SalesProvider>();
          salesProvider.setActiveTab(_activeTabId);
        } else {
          // Nếu không còn tab nào, tạo tab mới
          final salesProvider = context.read<SalesProvider>();
          final newTabId = salesProvider.createNewTab();
          _tabs.add(InvoiceTab(
            id: newTabId,
            name: AppLocalizations.of(context)!.invoiceTabName('$_nextTabId'),
            salesProvider: salesProvider,
          ));
          _activeTabId = newTabId;
          _nextTabId++;
        }
      } else {
        // Thanh toán xong hóa đơn cuối cùng: reset tên tab về "Hóa đơn 1", _nextTabId = 2
        final salesProvider = context.read<SalesProvider>();
        final id = _tabs.single.id;
        _tabs.clear();
        _tabs.add(InvoiceTab(id: id, name: AppLocalizations.of(context)!.invoiceTabName('1'), salesProvider: salesProvider));
        _activeTabId = id;
        _nextTabId = 2;
        salesProvider.setActiveTab(id);
      }
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null && result is String) {
      _productSearchController.text = result;
      _searchAndAddProduct(result);
    }
  }

  Future<void> _searchAndAddProduct(String query) async {
    if (query.trim().isEmpty) return;
    
    final productProvider = context.read<ProductProvider>();

    // Đảm bảo products đã được load
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      await productProvider.loadProducts();
    }

    final searchQuery = query.trim().toLowerCase();

    // Barcode Master: tra cứu O(1) theo mã vạch (<100ms) — ưu tiên khi quét Bluetooth/USB
    final byBarcode = productProvider.findProductByBarcode(query.trim());
    if (byBarcode != null && byBarcode.isSellable && byBarcode.isActive) {
      await _addProductToCartOrShowBatchPicker(byBarcode);
      return;
    }

    // Tìm kiếm theo tên / mã / SKU
    final allProducts = productProvider.products
        .where((p) => p.isSellable && p.isActive)
        .toList();
    
    final matchingProducts = allProducts.where((p) {
      final nameMatch = p.name.toLowerCase().contains(searchQuery);
      final barcodeMatch = p.barcode?.toLowerCase().contains(searchQuery) ?? false;
      final skuMatch = p.id.toLowerCase().contains(searchQuery);
      return nameMatch || barcodeMatch || skuMatch;
    }).toList();

    if (matchingProducts.isNotEmpty) {
      // Nếu chỉ có 1 sản phẩm, thêm trực tiếp (hoặc mở dialog chọn lô nếu isBatchExpireControl)
      if (matchingProducts.length == 1) {
        await _addProductToCartOrShowBatchPicker(matchingProducts.first);
      } else {
        // Nếu có nhiều sản phẩm, mở màn hình chọn
        if (!mounted) return;
        final product = await Navigator.push<ProductModel>(
          context,
          MaterialPageRoute(
            builder: (context) => ProductSelectionScreen(
              initialSearch: query,
            ),
          ),
        );
        if (product != null && mounted) {
          await _addProductToCartOrShowBatchPicker(product);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.productNotFound),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showProductSelection() async {
    if (!mounted) return;
    final product = await Navigator.push<ProductModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProductSelectionScreen(),
      ),
    );

    if (product != null && mounted) {
      await _addProductToCartOrShowBatchPicker(product);
    }
  }

  SalesProvider _getActiveSalesProvider() {
    return context.read<SalesProvider>(); // Tạm thời dùng chung, có thể mở rộng sau
  }

  /// Thêm sản phẩm vào giỏ: nếu sản phẩm quản lý theo lô (isBatchExpireControl), hiển thị dialog chọn lô.
  Future<void> _addProductToCartOrShowBatchPicker(ProductModel product, {double quantity = 1}) async {
    final salesProvider = _getActiveSalesProvider();
    final customer = salesProvider.getSelectedCustomer(_activeTabId);
    final branchId = context.read<BranchProvider>().currentBranchId ?? '';

    if (product.isBatchExpireControl && product.batchExpires.isNotEmpty) {
      final batches = product.batchExpires
          .where((b) => (branchId.isEmpty || b.branchId == branchId) && b.onHand > 0)
          .toList();
      if (batches.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noBatchAtBranch),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final result = await _showBatchPickerDialog(product, batches);
      if (result != null && mounted) {
        salesProvider.addToCart(
          product,
          quantity: result.$3,
          tabId: _activeTabId,
          customer: customer,
          batchName: result.$1,
          expireDate: result.$2,
        );
        _productSearchController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.addedToCart(product.name, result.$1)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      return;
    }

    salesProvider.addToCart(product, quantity: quantity, tabId: _activeTabId, customer: customer);
    _productSearchController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addedToCartSimple(product.name)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Dialog chọn lô hàng (KiotViet 2.4.1, 2.12.1 — Batch & Expire). Trả về (batchName, expireDate, quantity) hoặc null.
  Future<(String, DateTime?, double)?> _showBatchPickerDialog(
    ProductModel product,
    List<ProductBatchExpire> batches,
  ) async {
    final qtyController = TextEditingController(text: '1');
    ProductBatchExpire? selectedBatch = batches.first;

    return showDialog<(String, DateTime?, double)?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.selectBatch),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.existingBatches, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    RadioGroup<ProductBatchExpire>(
                      groupValue: selectedBatch,
                      onChanged: (v) => setState(() => selectedBatch = v),
                      child: Column(
                        children: batches.map((b) {
                          return RadioListTile<ProductBatchExpire>(
                            value: b,
                            title: Text(
                              b.batchName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'Hạn: ${b.expireDate != null ? DateFormat('dd/MM/yyyy').format(b.expireDate!) : '—'} • Tồn: ${b.onHand.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.quantity,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text.trim()) ?? 1;
                    if (qty <= 0 || selectedBatch == null) {
                      Navigator.of(ctx).pop();
                      return;
                    }
                    if (qty > selectedBatch!.onHand) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.quantityExceedsBatch(selectedBatch!.onHand.toStringAsFixed(0))),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop((selectedBatch!.batchName, selectedBatch!.expireDate, qty));
                  },
                  child: Text(AppLocalizations.of(context)!.addToCart),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatPrice(double price) {
    return NumberFormat('#,###').format(price);
  }

  Future<void> _handleCheckout() async {
    final salesProvider = _getActiveSalesProvider();
    final authProvider = context.read<AuthProvider>();
    final currentTabId = _activeTabId;

    // Kiểm tra giỏ hàng của tab hiện tại
    if (salesProvider.isCartEmptyForTab(currentTabId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.emptyCart),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị dialog chọn phương thức thanh toán
    final paymentMethod = await showDialog<PaymentMethodType>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectPaymentMethod),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: Text(AppLocalizations.of(context)!.cash),
              onTap: () => Navigator.pop(context, PaymentMethodType.cash),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.blue),
              title: Text(AppLocalizations.of(context)!.qrTransfer),
              onTap: () => Navigator.pop(context, PaymentMethodType.transfer),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );

    if (paymentMethod == null) return;

    if (paymentMethod == PaymentMethodType.cash) {
      salesProvider.setPaymentMethod('CASH', tabId: currentTabId);
      await _processCashPayment(salesProvider, currentTabId);
    } else if (paymentMethod == PaymentMethodType.transfer) {
      await _processTransferPayment(salesProvider, authProvider, currentTabId);
    }
  }

  Future<void> _processCashPayment(SalesProvider salesProvider, int tabId) async {
    final tutorialProvider = context.read<TutorialProvider>();
    final isTutorialMode = tutorialProvider.isTutorialMode;
    // Lấy tổng tiền từ tab hiện tại
    final finalTotal = salesProvider.getFinalTotal(tabId);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmPayment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.totalAmount(_formatPrice(finalTotal))),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.paymentMethodCash),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await salesProvider.checkout(tabId: tabId, isTutorialMode: isTutorialMode);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final productProvider = context.read<ProductProvider>();
      if (success) {
        if (!isTutorialMode) {
          salesProvider.clearCart(tabId: tabId);
          _handlePostCheckout(tabId);
          await _maybeAutoPrint(context);
          await productProvider.loadProducts();
        } else {
          tutorialProvider.setTutorialMode(false);
        }
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(isTutorialMode ? AppLocalizations.of(context)!.tutorialOrderSuccess : AppLocalizations.of(context)!.paymentSuccess),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(salesProvider.errorMessage ?? AppLocalizations.of(context)!.paymentFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processTransferPayment(
    SalesProvider salesProvider,
    AuthProvider authProvider,
    int tabId,
  ) async {
    final shop = authProvider.shop;
    final paymentConfig = shop?.paymentConfig;
    
    if (kDebugMode) {
      debugPrint('🔍 Checking payment config:');
      debugPrint('  - shop: ${shop != null ? "exists" : "null"}');
      debugPrint('  - paymentConfig: ${paymentConfig != null ? "exists" : "null"}');
      if (paymentConfig != null) {
        debugPrint('  - provider: ${paymentConfig.provider}');
        debugPrint('  - isConfigured: ${paymentConfig.isConfigured}');
        debugPrint('  - bankBin: ${paymentConfig.bankBin}');
        debugPrint('  - bankAccountNumber: ${paymentConfig.bankAccountNumber}');
        debugPrint('  - payosClientId: ${paymentConfig.payosClientId != null ? "exists" : "null"}');
      }
    }
    
    final hasPayOSConfig = paymentConfig != null && 
                          paymentConfig.isConfigured &&
                          paymentConfig.provider == PaymentProvider.payos;
    
    final hasBankInfo = paymentConfig != null &&
                        paymentConfig.bankBin != null &&
                        paymentConfig.bankBin!.isNotEmpty &&
                        paymentConfig.bankAccountNumber != null &&
                        paymentConfig.bankAccountNumber!.isNotEmpty;
    
    if (kDebugMode) {
      debugPrint('  - hasPayOSConfig: $hasPayOSConfig');
      debugPrint('  - hasBankInfo: $hasBankInfo');
    }

    // Lấy tổng tiền từ tab hiện tại
    final totalAmount = salesProvider.getFinalTotal(tabId);
    
    // Trường hợp 1: Không có cấu hình gì - Tạo đơn hàng thủ công
    if (!hasPayOSConfig && !hasBankInfo) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.qrPayment),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.totalAmount(_formatPrice(totalAmount))),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.qrTransferManualConfirm,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.createOrder),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final orderId = await salesProvider.checkoutWithTransferManual(tabId: tabId);
        if (mounted && orderId != null) {
          // Xóa giỏ hàng của tab hiện tại sau khi tạo đơn hàng thành công
          salesProvider.clearCart(tabId: tabId);
          
          // Tự động đóng tab hoặc reset về trạng thái trống
          _handlePostCheckout(tabId);
          await _maybeAutoPrint(context);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.orderCreatedMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }

    // Trường hợp 2: Có cấu hình PayOS hoặc Bank Info - Tạo QR code
    // paymentConfig không thể null ở đây vì hasPayOSConfig hoặc hasBankInfo đều yêu cầu nó
    // Sử dụng biến local để giúp analyzer hiểu rằng paymentConfig không null
    final config = paymentConfig;
    final paymentService = PaymentService(config: config);
    
    // Tạo đơn hàng trước
    final orderId = hasPayOSConfig
        ? await salesProvider.checkoutWithTransfer(tabId: tabId)
        : await salesProvider.checkoutWithTransferManual(tabId: tabId);

    if (orderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(salesProvider.errorMessage ?? AppLocalizations.of(context)!.cannotCreateOrder),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Tạo QR code
    if (kDebugMode) {
      debugPrint('🔄 Creating payment QR for order: $orderId, amount: $totalAmount');
    }
    
    final qrData = await paymentService.createPaymentQR(
      amount: totalAmount,
      orderId: orderId,
      description: 'Don hang $orderId',
    );

    if (qrData == null || qrData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotCreateQr),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ QR code created successfully, length: ${qrData.length}');
    }

    // Hiển thị dialog QR code
    if (mounted) {
      final productProvider = context.read<ProductProvider>();
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentQRDialog(
          orderId: orderId,
          amount: totalAmount,
          qrData: qrData,
          paymentService: paymentService,
          salesProvider: salesProvider,
          autoConfirm: hasPayOSConfig ? config.autoConfirmPayment : false,
          onCancel: () {
            // Có thể hủy đơn hàng hoặc giữ nguyên
          },
          onPaymentSuccess: () async {
            if (mounted) {
              // Trừ kho đã được xử lý trong completeTransferPayment() của SalesProvider
              // Xóa giỏ hàng của tab hiện tại
              salesProvider.clearCart(tabId: tabId);
              
              // Tự động đóng tab hoặc reset về trạng thái trống
              _handlePostCheckout(tabId);
              
              productProvider.loadProducts();
              // Đợi completeTransferPayment từ polling xong rồi mới gọi auto-print
              await Future.delayed(const Duration(milliseconds: 600));
              if (mounted) await _maybeAutoPrint(context);
              if (!mounted) return;
              // Hiển thị thông báo về hóa đơn điện tử nếu có
              final invoiceUrl = salesProvider.lastInvoiceUrl;
              if (invoiceUrl != null && invoiceUrl.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.paymentSuccessEinvoice),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: AppLocalizations.of(context)!.openInvoice,
                      textColor: Colors.white,
                      onPressed: () async {
                        try {
                          final url = Uri.parse(invoiceUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.cannotOpenLink(e)),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ ${AppLocalizations.of(context)!.paymentSuccess}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final branchProvider = context.watch<BranchProvider>();
    
    // Lấy thông tin chi nhánh từ BranchProvider.currentBranchId
    final currentBranchId = branchProvider.currentBranchId;
    final branch = currentBranchId != null
        ? branchProvider.branches.firstWhere(
            (b) => b.id == currentBranchId,
            orElse: () => BranchModel(
              id: 'default',
              name: AppLocalizations.of(context)!.mainBranch,
              address: AppLocalizations.of(context)!.defaultAddress,
            ),
          )
        : BranchModel(
            id: 'default',
            name: AppLocalizations.of(context)!.noBranchSelected,
            address: AppLocalizations.of(context)!.pleaseSelectBranch,
          );
    
    // Lấy tên nhân viên
    final employeeName = authProvider.userProfile?.displayName ?? 
                        authProvider.user?.email?.split('@').first ?? 
                        AppLocalizations.of(context)!.staffLabel;
    
    final cartItemCount = context.watch<SalesProvider>().getCart(_activeTabId).length;

    final useMobile = _useMobileLayout;
    final productGrid = !useMobile
        ? _buildLeftPanel(isMobile: false)
        : Column(
            children: [
              Expanded(
                child: _buildLeftPanel(
                  isMobile: true,
                  showCartListInPanel: false,
                ),
              ),
              _buildMobileSecondaryButtons(),
            ],
          );

    return Consumer<TutorialProvider>(
      builder: (context, tutorialProvider, _) {
        final body = useMobile
            ? SalesScreenMobileBody(
                headerSection: const SizedBox.shrink(),
                cartListSection: _buildMobileCartListSection(),
                floatingButtonSection: const SizedBox.shrink(),
                bottomBarSection: _buildMobileBottomBarSection(),
              )
            : SalesScreenDesktopBody(
                productGrid: productGrid,
                cartAndPayment: _buildRightPanel(),
                cartItemCount: cartItemCount,
              );
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9), // slate-100
          appBar: useMobile
              ? _buildMobileSalesAppBar()
              : _buildSalesAppBar(context, branch, employeeName, authProvider),
          body: tutorialProvider.isTutorialMode
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.tutorialModeHint,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          TextButton(
                            onPressed: () => tutorialProvider.setTutorialMode(false),
                            child: Text(AppLocalizations.of(context)!.exit, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }

  /// Mở scene phụ thanh toán (mobile): Chi nhánh + NV, Khách hàng, Khuyến mãi, Thuế, nút THANH TOÁN.
  void _openMobilePaymentScene() {
    final salesProvider = _getActiveSalesProvider();
    if (salesProvider.isCartEmptyForTab(_activeTabId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.emptyCart),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final branchProvider = context.read<BranchProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentBranchId = branchProvider.currentBranchId;
    final branch = currentBranchId != null
        ? branchProvider.branches.firstWhere(
              (b) => b.id == currentBranchId,
              orElse: () => BranchModel(
                id: 'default',
                name: AppLocalizations.of(context)!.mainBranch,
                address: AppLocalizations.of(context)!.defaultAddress,
              ),
            )
        : BranchModel(
            id: 'default',
            name: AppLocalizations.of(context)!.noBranchSelected,
            address: AppLocalizations.of(context)!.pleaseSelectBranch,
          );
    final employeeName = authProvider.userProfile?.displayName ??
        authProvider.user?.email?.split('@').first ??
        AppLocalizations.of(context)!.staffLabel;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SalesPaymentScene(
          tabId: _activeTabId,
          formatPrice: _formatPrice,
          branchName: branch.name,
          employeeName: employeeName,
          onBack: () => Navigator.of(context).pop(),
          onOpenCustomer: _showCustomerInfoBottomSheet,
          onOpenDiscount: () => _showDiscountDialog(salesProvider),
          onCheckout: () async {
            final navigator = Navigator.of(context);
            await _handleCheckout();
            if (!mounted) return;
            navigator.pop();
          },
        ),
      ),
    );
  }

  /// Phần danh sách giỏ hàng mobile (Expanded). Nút thêm sản phẩm nằm trong khu vực giỏ, góc dưới phải, không đè bottom bar.
  Widget _buildMobileCartListSection() {
    return Stack(
      children: [
        Consumer<SalesProvider>(
          builder: (context, salesProvider, child) {
            final cart = salesProvider.getCart(_activeTabId);
            if (cart.isEmpty) {
              return Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shoppingCart, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.emptyCartHint,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.pressAddProductHint,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 72),
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final entry = cart.entries.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMobileCartCard(entry.key, entry.value, salesProvider),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 26,
          right: 26,
          child: FloatingActionButton(
            onPressed: _showProductSelection,
            tooltip: AppLocalizations.of(context)!.addProduct,
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            elevation: 6,
            child: const Icon(LucideIcons.plus, size: 28),
          ),
        ),
      ],
    );
  }

  /// Phần bottom bar mobile: Tổng tiền + nút Thanh toán.
  Widget _buildMobileBottomBarSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Consumer<SalesProvider>(
            builder: (context, salesProvider, child) {
              final totals = salesProvider.calculateTotals(_activeTabId);
              final subTotal = totals['subTotal'] ?? 0.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)!.totalAmountLabel, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text('${_formatPrice(subTotal)}đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openMobilePaymentScene,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(AppLocalizations.of(context)!.pay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Nút mở BottomSheet Khách hàng và Khuyến mãi (chỉ Mobile).
  Widget _buildMobileSecondaryButtons() {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCustomerInfoBottomSheet(),
                  icon: const Icon(LucideIcons.user, size: 18),
                  label: Text(AppLocalizations.of(context)!.customer),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDiscountDialog(salesProvider),
                  icon: const Icon(LucideIcons.tag, size: 18),
                  label: Text(AppLocalizations.of(context)!.promotion),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF97316),
                    side: const BorderSide(color: Color(0xFFF97316)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Hiển thị form thông tin khách hàng trong BottomSheet (Mobile).
  void _showCustomerInfoBottomSheet() {
    final salesProvider = context.read<SalesProvider>();
    _customerNameController.text = salesProvider.getCustomerName(_activeTabId) ?? '';
    _customerPhoneController.text = salesProvider.getCustomerPhone(_activeTabId) ?? '';
    _customerAddressController.text = salesProvider.getCustomerAddress(_activeTabId) ?? '';
    _customerTaxCodeController.text = salesProvider.getCustomerTaxCode(_activeTabId) ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Consumer<SalesProvider>(
            builder: (context, salesProvider, _) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    AppLocalizations.of(context)!.customerInfo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    key: _customerPhoneFieldKeyMobile,
                    child: TextField(
                      controller: _customerPhoneController,
                      focusNode: _customerPhoneFocusNode,
                      keyboardType: TextInputType.phone,
                      decoration: _mobileInputDecoration(AppLocalizations.of(context)!.phone),
                      onChanged: (v) {
                        salesProvider.setCustomerPhone(v.isEmpty ? null : v, tabId: _activeTabId);
                        _onCustomerPhoneChanged(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerNameController,
                    decoration: _mobileInputDecoration(AppLocalizations.of(context)!.customerName),
                    onChanged: (v) {
                      final selected = salesProvider.getSelectedCustomer(_activeTabId);
                      if (selected != null && v.trim() != selected.name.trim()) {
                        salesProvider.clearCustomerSelection(tabId: _activeTabId);
                        _customerPhoneController.clear();
                        _customerAddressController.clear();
                        _customerTaxCodeController.clear();
                      }
                      salesProvider.setCustomerName(v.isEmpty ? null : v, tabId: _activeTabId);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerAddressController,
                    decoration: _mobileInputDecoration(AppLocalizations.of(context)!.address),
                    onChanged: (v) =>
                        salesProvider.setCustomerAddress(v.isEmpty ? null : v, tabId: _activeTabId),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerTaxCodeController,
                    keyboardType: TextInputType.text,
                    decoration: _mobileInputDecoration(AppLocalizations.of(context)!.taxCodeForInvoice),
                    onChanged: (v) =>
                        salesProvider.setCustomerTaxCode(v.isEmpty ? null : v, tabId: _activeTabId),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(AppLocalizations.of(context)!.confirm),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _mobileInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }

  /// AppBar Slate-800: Chi nhánh + Nhân viên. Safe Area tự xử lý; mobile: cỡ chữ & khoảng cách gọn.
  PreferredSizeWidget _buildSalesAppBar(
    BuildContext context,
    BranchModel branch,
    String employeeName,
    AuthProvider authProvider,
  ) {
    final mobile = _useMobileLayout;
    final fsLabel = mobile ? 11.0 : 12.0;
    final fsValue = mobile ? 11.0 : 12.0;
    final iconSize = mobile ? 12.0 : 14.0;
    final spacing = mobile ? 6.0 : 10.0;
    final avatarRadius = mobile ? 8.0 : 10.0;

    return AppBar(
      backgroundColor: const Color(0xFF1E293B), // slate-800
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color(0xFF60A5FA), size: 20),
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          // Chi nhánh
          Icon(LucideIcons.mapPin, size: iconSize, color: const Color(0xFF60A5FA)),
          SizedBox(width: spacing),
          Text(
            AppLocalizations.of(context)!.branchLabel,
            style: TextStyle(
              fontSize: fsLabel,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              branch.name,
              style: TextStyle(
                fontSize: fsValue,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: mobile ? 8 : 16),
          // Nhân viên
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: const Color(0xFF3B82F6),
            child: Text(
              employeeName.isEmpty ? '?' : employeeName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: spacing),
          Text(
            AppLocalizations.of(context)!.staffShortLabel,
            style: TextStyle(
              fontSize: fsLabel,
              color: Colors.grey[300],
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              employeeName,
              style: TextStyle(
                fontSize: fsValue,
                color: const Color(0xFF60A5FA),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }

  /// AppBar mobile: chỉ tabs (Hóa đơn 1, 2...) + nút "+" thêm hóa đơn. Tiết kiệm không gian.
  PreferredSizeWidget _buildMobileSalesAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      titleSpacing: 16,
      centerTitle: false,
      title: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length + 1,
                itemBuilder: (context, index) {
                if (index == _tabs.length) {
                  return IconButton(
                    icon: const Icon(LucideIcons.plus, size: 20),
                    color: Colors.grey.shade600,
                    onPressed: _addNewTab,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  );
                }
                final tab = _tabs[index];
                final isActive = tab.id == _activeTabId;
                return GestureDetector(
                  onTap: () => _setActiveTab(tab.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tab.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade600,
                          ),
                        ),
                        if (_tabs.length > 1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeTab(tab.id),
                            child: Icon(
                              LucideIcons.x,
                              size: 12,
                              color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade400,
                            ),
                          ),
                        ],
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
      actions: const [],
    );
  }

  Widget _buildLeftPanel({bool isMobile = false, bool showCartListInPanel = true}) {
    // Desktop: Column fill height — header gọn, giỏ hàng Expanded (scroll trong), action bar gọn → bỏ khoảng trống trên/dưới.
    if (!isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Tab + Search (gọn)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tabs.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _tabs.length) {
                              return IconButton(
                                icon: const Icon(LucideIcons.plus, size: 20),
                                color: Colors.grey[400],
                                onPressed: _addNewTab,
                              );
                            }
                            final tab = _tabs[index];
                            final isActive = tab.id == _activeTabId;
                            return GestureDetector(
                              onTap: () => _setActiveTab(tab.id),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tab.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        color: isActive ? const Color(0xFF2563EB) : Colors.grey[500],
                                      ),
                                    ),
                                    if (_tabs.length > 1) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _removeTab(tab.id),
                                        child: Icon(
                                          LucideIcons.x,
                                          size: 14,
                                          color: isActive ? const Color(0xFF2563EB) : Colors.grey[400],
                                        ),
                                      ),
                                    ],
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
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _productSearchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchProductHint,
                      isDense: true,
                      prefixIcon: IconButton(
                        icon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          final query = _productSearchController.text.trim();
                          if (query.isNotEmpty) _searchAndAddProduct(query);
                        },
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.qrCode, size: 20),
                            color: Colors.grey[400],
                            onPressed: _scanBarcode,
                            tooltip: AppLocalizations.of(context)!.scanBarcode,
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.list, size: 20),
                            color: Colors.grey[400],
                            onPressed: _showProductSelection,
                            tooltip: AppLocalizations.of(context)!.selectProduct,
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) _searchAndAddProduct(value.trim());
                    },
                  ),
                ),
              ],
            ),
          ),
          // Vùng giỏ hàng: chiếm hết chiều cao còn lại, scroll bên trong
          Expanded(
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                final cart = salesProvider.getCart(_activeTabId);
                if (cart.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shoppingCart, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.emptyCartHint,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 48, child: Center(child: _buildTableHeader('#'))),
                            SizedBox(width: 64, child: Center(child: _buildTableHeader(AppLocalizations.of(context)!.deleteHeader))),
                            Expanded(child: _buildTableHeader(AppLocalizations.of(context)!.productName)),
                            SizedBox(width: 80, child: Center(child: _buildTableHeader(AppLocalizations.of(context)!.unitHeader))),
                            SizedBox(width: 160, child: Center(child: _buildTableHeader(AppLocalizations.of(context)!.quantity))),
                            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader(AppLocalizations.of(context)!.unitPriceHeader))),
                            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader(AppLocalizations.of(context)!.amountHeader))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final entry = cart.entries.elementAt(index);
                              return _buildCartItemRow(index + 1, entry.key, entry.value, salesProvider);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Action bar (gọn)
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildExpandableButton(
                        icon: LucideIcons.tag,
                        label: AppLocalizations.of(context)!.promotion,
                        onTap: () => _showDiscountDialog(salesProvider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExpandableButton(
                        icon: LucideIcons.printer,
                        label: AppLocalizations.of(context)!.printLabel,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.featureInDevelopment), backgroundColor: Colors.orange),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExpandableButton(
                        icon: LucideIcons.dollarSign,
                        label: AppLocalizations.of(context)!.selectPriceList,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.featureInDevelopment), backgroundColor: Colors.orange),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExpandableButton(
                        icon: LucideIcons.truck,
                        label: AppLocalizations.of(context)!.deliveryLabel,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.featureInDevelopment), backgroundColor: Colors.orange),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    // Mobile: khi showCartListInPanel = false (FAB layout) dùng Column + Expanded; ngược lại cuộn như cũ
    final mobileHeader = Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _tabs.length) {
                        return IconButton(
                          icon: const Icon(LucideIcons.plus, size: 18),
                          color: Colors.grey[400],
                          onPressed: _addNewTab,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        );
                      }
                      final tab = _tabs[index];
                      final isActive = tab.id == _activeTabId;
                      return GestureDetector(
                        onTap: () => _setActiveTab(tab.id),
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  color: isActive ? const Color(0xFF2563EB) : Colors.grey[500],
                                ),
                              ),
                              if (_tabs.length > 1) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _removeTab(tab.id),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 12,
                                    color: isActive ? const Color(0xFF2563EB) : Colors.grey[400],
                                  ),
                                ),
                              ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showProductSelection,
                icon: const Icon(LucideIcons.plus, size: 20),
                label: Text(AppLocalizations.of(context)!.addProductToCart),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showCartListInPanel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          mobileHeader,
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shoppingBag, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.pressCartToPay,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scrollbar(
      controller: _leftPanelScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _leftPanelScrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mobileHeader,
            Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                final cart = salesProvider.getCart(_activeTabId);
                if (cart.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Container(
                      color: Colors.white,
                      margin: const EdgeInsets.all(12),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.shoppingCart, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.emptyCartHint,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return _buildMobileCartList(salesProvider, cart);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  /// Giỏ hàng Mobile: ListView.builder với Card cho từng sản phẩm.
  /// shrinkWrap + NeverScrollableScrollPhysics khi nằm trong SingleChildScrollView của left panel.
  Widget _buildMobileCartList(SalesProvider salesProvider, Map<String, SaleItem> cart) {
    final entries = cart.entries.toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildMobileCartCard(entry.key, entry.value, salesProvider),
        );
      },
    );
  }

  /// Một Card sản phẩm trên Mobile: Tên (bold), Đơn giá, Thành tiền; nút +/- lớn bên phải.
  /// [cartKey] Key trong map giỏ (productId hoặc productId_batchName_expireDate cho sản phẩm theo lô).
  Widget _buildMobileCartCard(String cartKey, SaleItem item, SalesProvider salesProvider) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đơn giá: ${_formatPrice(item.price)}đ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thành tiền: ${_formatPrice(item.subtotal)}đ',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: () {
                      if (item.quantity > 1) {
                        salesProvider.updateCartItemQuantity(
                          cartKey,
                          item.quantity - 1.0,
                          tabId: _activeTabId,
                        );
                      } else {
                        salesProvider.removeFromCart(cartKey, tabId: _activeTabId);
                      }
                    },
                    icon: const Icon(Icons.remove, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showQuantityDialogMobile(cartKey, item, salesProvider),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
                if (_showPlusButton(item))
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () {
                        salesProvider.updateCartItemQuantity(
                          cartKey,
                          item.quantity + 1.0,
                          tabId: _activeTabId,
                        );
                      },
                      icon: const Icon(Icons.add, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () =>
                      salesProvider.removeFromCart(cartKey, tabId: _activeTabId),
                  icon: const Icon(LucideIcons.trash2, size: 20),
                  color: Colors.grey[500],
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// [cartKey] Key trong map giỏ (productId hoặc productId_batchName_expireDate cho sản phẩm theo lô).
  Widget _buildCartItemRow(int index, String cartKey, SaleItem item, SalesProvider salesProvider) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          hoverColor: const Color(0xFFEFF6FF).withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      color: Colors.grey[300],
                      onPressed: () => salesProvider.removeFromCart(cartKey, tabId: _activeTabId),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item.productId}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.defaultUnit, // ignore: todo - TODO: Get from product
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 40,
                            child: IconButton(
                              icon: const Text('-', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  salesProvider.updateCartItemQuantity(cartKey, item.quantity - 1.0, tabId: _activeTabId);
                                } else {
                                  salesProvider.removeFromCart(cartKey, tabId: _activeTabId);
                                }
                              },
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(48, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showQuantityDialogDesktop(cartKey, item, salesProvider),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 48,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Text(
                                  item.quantity.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_showPlusButton(item))
                            SizedBox(
                              width: 48,
                              height: 40,
                              child: IconButton(
                                icon: const Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  salesProvider.updateCartItemQuantity(cartKey, item.quantity + 1.0, tabId: _activeTabId);
                                },
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(48, 40),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _showItemPriceDiscountDialog(item, salesProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.discount != null && item.discount! > 0
                              ? const Color(0xFFFFF4ED)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.discount != null && item.discount! > 0
                                ? const Color(0xFFF97316)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(item.price),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: item.discount != null && item.discount! > 0
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (item.discount != null && item.discount! > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '-${_formatPrice(item.discountAmount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFF97316),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatPrice(item.subtotal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
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

  Widget _buildRightPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Customer Section - Nút "Thông tin khách hàng" (desktop: giãn thoáng)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Column(
              children: [
                // Nút "Thông tin khách hàng"
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      if (!_isCustomerInfoExpanded) {
                        final salesProvider = context.read<SalesProvider>();
                        _customerNameController.text = salesProvider.getCustomerName(_activeTabId) ?? '';
                        _customerPhoneController.text = salesProvider.getCustomerPhone(_activeTabId) ?? '';
                        _customerAddressController.text = salesProvider.getCustomerAddress(_activeTabId) ?? '';
                        _customerTaxCodeController.text = salesProvider.getCustomerTaxCode(_activeTabId) ?? '';
                      }
                      setState(() {
                        _isCustomerInfoExpanded = !_isCustomerInfoExpanded;
                      });
                    },
                    icon: Icon(
                      _isCustomerInfoExpanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 20,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.customerInfo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      alignment: Alignment.centerLeft,
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                // Expandable Content
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isCustomerInfoExpanded
                        ? Container(
                            padding: const EdgeInsets.only(top: 20, bottom: 8),
                            child: Consumer<SalesProvider>(
                              builder: (context, salesProvider, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Số điện thoại - Tìm kiếm ngay, gợi ý hiện popup Overlay sát dưới ô
                                    RepaintBoundary(
                                      key: _customerPhoneFieldKeyDesktop,
                                      child: TextField(
                                        controller: _customerPhoneController,
                                        focusNode: _customerPhoneFocusNode,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.of(context)!.phone,
                                          labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                        style: const TextStyle(fontSize: 15),
                                        onChanged: (value) {
                                          salesProvider.setCustomerPhone(value.isEmpty ? null : value, tabId: _activeTabId);
                                          _onCustomerPhoneChanged(value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    // Tên khách hàng
                                    TextField(
                                      controller: _customerNameController,
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.customerName,
                                        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      style: const TextStyle(fontSize: 15),
                                      onChanged: (value) {
                                        final selected = salesProvider.getSelectedCustomer(_activeTabId);
                                        if (selected != null && value.trim() != selected.name.trim()) {
                                          salesProvider.clearCustomerSelection(tabId: _activeTabId);
                                          _customerPhoneController.clear();
                                          _customerAddressController.clear();
                                          _customerTaxCodeController.clear();
                                        }
                                        salesProvider.setCustomerName(value.isEmpty ? null : value, tabId: _activeTabId);
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    // Địa chỉ
                                    TextField(
                                      controller: _customerAddressController,
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.address,
                                        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      style: const TextStyle(fontSize: 15),
                                      onChanged: (value) {
                                        salesProvider.setCustomerAddress(value.isEmpty ? null : value, tabId: _activeTabId);
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    // MST (Mã số thuế) - Khi khách yêu cầu xuất hóa đơn
                                    TextField(
                                      controller: _customerTaxCodeController,
                                      keyboardType: TextInputType.text,
                                      decoration: InputDecoration(
                                        labelText: AppLocalizations.of(context)!.taxCodeForInvoice,
                                        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      style: const TextStyle(fontSize: 15),
                                      onChanged: (value) {
                                        salesProvider.setCustomerTaxCode(value.isEmpty ? null : value, tabId: _activeTabId);
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    // Nút Xác nhận để ẩn lại
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isCustomerInfoExpanded = false;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.confirmLabel,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : const SizedBox(height: 0),
                  ),
                ),
              ],
            ),
          ),
          
          // Invoice Config & Summary
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid, width: 1),
                      ),
                    ),
                    child: Consumer<SalesProvider>(
                      builder: (context, salesProvider, child) {
                        // Sử dụng calculateTotals để lấy đầy đủ thông tin
                        final totals = salesProvider.calculateTotals(_activeTabId);
                        final totalBeforeDiscount = totals['totalBeforeDiscount'] ?? 0.0;
                        final discountAmount = totals['discountAmount'] ?? 0.0;
                        final taxAmount = totals['taxAmount'] ?? 0.0;
                        final vatRate = totals['vatRate'] ?? 0.0;
                        final finalTotal = totals['finalTotal'] ?? 0.0;
                        
                        return Column(
                          children: [
                            _buildSummaryRow(AppLocalizations.of(context)!.totalBeforeDiscount, '${_formatPrice(totalBeforeDiscount)}đ', Colors.grey[600]!),
                            const SizedBox(height: 12),
                            // Row chiết khấu có thể nhấn vào
                            InkWell(
                              onTap: () => _showDiscountDialog(salesProvider),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: discountAmount > 0 
                                      ? const Color(0xFFFFF4ED) 
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: discountAmount > 0 
                                        ? const Color(0xFFF97316) 
                                        : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          discountAmount > 0 
                                              ? LucideIcons.tag 
                                              : LucideIcons.plus,
                                          size: 16,
                                          color: discountAmount > 0 
                                              ? const Color(0xFFF97316) 
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(context)!.discountLabel,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: discountAmount > 0 
                                                ? const Color(0xFFF97316) 
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          discountAmount > 0 
                                              ? '-${_formatPrice(discountAmount)}đ' 
                                              : AppLocalizations.of(context)!.tapToAdd,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: discountAmount > 0 
                                                ? const Color(0xFFF97316) 
                                                : Colors.grey[400],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              vatRate > 0 ? 'Thuế ($vatRate%)' : 'Thuế',
                              '${_formatPrice(taxAmount)}đ',
                              Colors.grey[600]!,
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(AppLocalizations.of(context)!.totalLabel, '${_formatPrice(finalTotal)}đ', const Color(0xFF2563EB)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Payment Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                // Lấy tổng tiền từ tab hiện tại
                final finalTotal = salesProvider.getFinalTotal(_activeTabId);
                
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.customerToPay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(finalTotal),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'đ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Payment Options
                    // Big Checkout Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleCheckout,
                          borderRadius: BorderRadius.circular(24),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.zap,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(context)!.payButtonShort,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lấy tồn kho hiện tại của sản phẩm (theo chi nhánh đang chọn).
  double _getStockForProduct(String productId) {
    final productProvider = context.read<ProductProvider>();
    final products = productProvider.products.where((p) => p.id == productId).toList();
    if (products.isEmpty) return 0.0;
    return productProvider.getStockForCurrentBranch(products.first);
  }

  /// Trả về true nếu được phép hiển thị nút cộng: khi cho bán âm kho luôn true; khi không thì chỉ true khi số lượng < tồn kho.
  bool _showPlusButton(SaleItem item) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.shop?.allowNegativeStock == true) return true;
    final stock = _getStockForProduct(item.productId);
    return item.quantity < stock;
  }

  /// Tính số lượng hiệu lực: nếu không cho phép bán âm kho thì cap theo tồn kho.
  double _effectiveQuantityForCart(double inputQty, String productId) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.shop?.allowNegativeStock == true) return inputQty;
    final stock = _getStockForProduct(productId);
    if (inputQty > stock) return stock;
    return inputQty;
  }

  /// Desktop: bấm vào số lượng → dialog nhập số trực tiếp (TextField).
  Future<void> _showQuantityDialogDesktop(String cartKey, SaleItem item, SalesProvider salesProvider) async {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.quantity),
          content: TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterQuantity,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) {
                  salesProvider.removeFromCart(cartKey, tabId: _activeTabId);
                  Navigator.of(dialogContext).pop();
                  return;
                }
                final effective = _effectiveQuantityForCart(qty, item.productId);
                salesProvider.updateCartItemQuantity(cartKey, effective, tabId: _activeTabId);
                Navigator.of(dialogContext).pop();
              },
              child: Text(AppLocalizations.of(context)!.done),
            ),
          ],
        );
      },
    );
    qtyController.dispose();
  }

  /// Mobile: bấm vào số lượng → popup ô text + 10 nút số (0–9).
  Future<void> _showQuantityDialogMobile(String cartKey, SaleItem item, SalesProvider salesProvider) async {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(item.productName, overflow: TextOverflow.ellipsis, maxLines: 1),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Số lượng',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                    children: List.generate(10, (i) {
                      final digit = (i + 1) % 10; // 1,2,...,9,0
                      return Material(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final text = qtyController.text;
                            qtyController.text = '$text$digit';
                            qtyController.selection = TextSelection.collapsed(offset: qtyController.text.length);
                            setState(() {});
                          },
                          child: Center(
                            child: Text(
                              '$digit',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                    if (qty <= 0) {
                      salesProvider.removeFromCart(cartKey, tabId: _activeTabId);
                      Navigator.of(dialogContext).pop();
                      return;
                    }
                    final effective = _effectiveQuantityForCart(qty, item.productId);
                    salesProvider.updateCartItemQuantity(cartKey, effective, tabId: _activeTabId);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(AppLocalizations.of(context)!.done),
                ),
              ],
            );
          },
        );
      },
    );
    qtyController.dispose();
  }

  /// Hiển thị dialog chỉnh sửa giá và chiết khấu cho từng sản phẩm
  Future<void> _showItemPriceDiscountDialog(SaleItem item, SalesProvider salesProvider) async {
    final priceController = TextEditingController(
      text: item.price.toStringAsFixed(0),
    );
    final discountController = TextEditingController(
      text: item.discount != null && item.discount! > 0 
          ? item.discount!.toStringAsFixed(0) 
          : '',
    );
    
    bool discountTypeIsPercentage = item.isDiscountPercentage ?? false;
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(LucideIcons.pencil, size: 20, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Giá bán
                    const Text(
                      'Giá bán (VNĐ)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Nhập giá bán',
                        prefixIcon: const Icon(LucideIcons.coins, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Chiết khấu
                    const Text(
                      'Chiết khấu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Chọn loại chiết khấu
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => discountTypeIsPercentage = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: discountTypeIsPercentage 
                                      ? const Color(0xFFEFF6FF) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: discountTypeIsPercentage 
                                        ? const Color(0xFF2563EB) 
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.percent,
                                      size: 16,
                                      color: discountTypeIsPercentage 
                                          ? const Color(0xFF2563EB) 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '%',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => discountTypeIsPercentage = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: !discountTypeIsPercentage 
                                      ? const Color(0xFFEFF6FF) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !discountTypeIsPercentage 
                                        ? const Color(0xFF2563EB) 
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.coins,
                                      size: 16,
                                      color: !discountTypeIsPercentage 
                                          ? const Color(0xFF2563EB) 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'VNĐ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: discountTypeIsPercentage 
                            ? AppLocalizations.of(context)!.enterPercentExample 
                            : AppLocalizations.of(context)!.enterAmountExample,
                        prefixIcon: Icon(
                          discountTypeIsPercentage ? LucideIcons.percent : LucideIcons.coins,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                    ),
                    if (discountController.text.isNotEmpty && priceController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final price = double.tryParse(priceController.text) ?? 0.0;
                          final discountValue = double.tryParse(discountController.text) ?? 0.0;
                          final quantity = item.quantity;
                          
                          double itemDiscountAmount = 0.0;
                          double itemSubtotal = price * quantity;
                          
                          if (discountValue > 0) {
                            if (discountTypeIsPercentage) {
                              itemDiscountAmount = itemSubtotal * (discountValue / 100);
                              if (discountValue > 100) {
                                itemDiscountAmount = itemSubtotal;
                              }
                            } else {
                              itemDiscountAmount = discountValue > itemSubtotal ? itemSubtotal : discountValue;
                            }
                            itemSubtotal = itemSubtotal - itemDiscountAmount;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Số lượng: ${quantity.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Giá gốc: ${_formatPrice(price * quantity)}đ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (itemDiscountAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Giảm giá: -${_formatPrice(itemDiscountAmount)}đ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF97316),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Thành tiền: ${_formatPrice(itemSubtotal)}đ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () {
                    // Xóa chiết khấu
                    salesProvider.updateCartItemDiscount(
                      item.productId,
                      null,
                      null,
                      tabId: _activeTabId,
                    );
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)!.removeDiscount, style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrice = double.tryParse(priceController.text) ?? item.price;
                    final discountValue = discountController.text.isNotEmpty
                        ? double.tryParse(discountController.text)
                        : null;
                    
                    if (newPrice < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.priceCannotBeNegative),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (discountValue != null && discountValue < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.discountCannotBeNegative),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (discountTypeIsPercentage && discountValue != null && discountValue > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.discountPercentExceeds100),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Cập nhật giá
                    salesProvider.updateCartItemPrice(item.productId, newPrice, tabId: _activeTabId);
                    
                    // Cập nhật chiết khấu
                    salesProvider.updateCartItemDiscount(
                      item.productId,
                      discountValue,
                      discountValue != null ? discountTypeIsPercentage : null,
                      tabId: _activeTabId,
                    );
                    
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(AppLocalizations.of(context)!.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hiển thị dialog nhập chiết khấu
  Future<void> _showDiscountDialog(SalesProvider salesProvider) async {
    final currentDiscountValue = salesProvider.getOrderDiscountValue(_activeTabId);
    final isPercentage = salesProvider.getIsDiscountPercentage(_activeTabId);
    final totalBeforeDiscount = salesProvider.getTotalBeforeDiscount(_activeTabId);
    
    // Controller cho giá trị chiết khấu
    final discountController = TextEditingController(
      text: currentDiscountValue > 0 ? currentDiscountValue.toStringAsFixed(0) : '',
    );
    
    // State cho loại chiết khấu
    bool discountTypeIsPercentage = isPercentage;
    
    // Biến để track xem đã thêm listener chưa
    bool listenerAdded = false;
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder để rebuild khi state thay đổi
        return StatefulBuilder(
          builder: (context, setState) {
            // Thêm listener một lần để cập nhật preview khi text thay đổi
            if (!listenerAdded) {
              discountController.addListener(() {
                setState(() {}); // Rebuild để cập nhật preview
              });
              listenerAdded = true;
            }
            
            return AlertDialog(
          title: Row(
            children: [
              const Icon(LucideIcons.tag, size: 20, color: Color(0xFFF97316)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.orderDiscountTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chọn loại chiết khấu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => discountTypeIsPercentage = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: discountTypeIsPercentage 
                                ? const Color(0xFFEFF6FF) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: discountTypeIsPercentage 
                                  ? const Color(0xFF2563EB) 
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                discountTypeIsPercentage 
                                    ? LucideIcons.percent 
                                    : LucideIcons.percent,
                                size: 16,
                                color: discountTypeIsPercentage 
                                    ? const Color(0xFF2563EB) 
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.percentLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: discountTypeIsPercentage 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: discountTypeIsPercentage 
                                      ? const Color(0xFF2563EB) 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => discountTypeIsPercentage = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: !discountTypeIsPercentage 
                                ? const Color(0xFFEFF6FF) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !discountTypeIsPercentage 
                                  ? const Color(0xFF2563EB) 
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.coins,
                                size: 16,
                                color: !discountTypeIsPercentage 
                                    ? const Color(0xFF2563EB) 
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Số tiền (VNĐ)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: !discountTypeIsPercentage 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: !discountTypeIsPercentage 
                                      ? const Color(0xFF2563EB) 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Ô nhập giá trị
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: discountTypeIsPercentage ? AppLocalizations.of(context)!.discountPercentLabel : AppLocalizations.of(context)!.discountAmountLabel,
                  hintText: discountTypeIsPercentage ? AppLocalizations.of(context)!.enterPercentExample : AppLocalizations.of(context)!.enterAmountExample,
                  prefixIcon: Icon(
                    discountTypeIsPercentage ? LucideIcons.percent : LucideIcons.coins,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                ),
              ),
              if (discountController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final value = double.tryParse(discountController.text) ?? 0.0;
                    double discountAmount = 0.0;
                    double finalTotal = totalBeforeDiscount;
                    
                    if (value > 0) {
                      if (discountTypeIsPercentage) {
                        discountAmount = totalBeforeDiscount * (value / 100);
                        // Giới hạn phần trăm không vượt quá 100%
                        if (value > 100) {
                          discountAmount = totalBeforeDiscount;
                        }
                      } else {
                        discountAmount = value > totalBeforeDiscount ? totalBeforeDiscount : value;
                      }
                      finalTotal = totalBeforeDiscount - discountAmount;
                    }
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng tiền hàng: ${_formatPrice(totalBeforeDiscount)}đ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Giảm giá: -${_formatPrice(discountAmount)}đ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tổng cộng: ${_formatPrice(finalTotal)}đ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                discountController.dispose();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                // Xóa chiết khấu
                salesProvider.clearDiscount(tabId: _activeTabId);
                discountController.dispose();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(discountController.text) ?? 0.0;
                if (value > 0) {
                  // Validate giá trị
                  if (discountTypeIsPercentage && value > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.discountPercentExceeds100),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  // Kiểm tra quyền phê duyệt
                  final authProvider = context.read<AuthProvider>();
                  final totals = salesProvider.calculateTotals(_activeTabId);
                  final subTotal = totals['subTotal'] ?? 0.0;
                  
                  double actualDiscountAmount = 0.0;
                  if (discountTypeIsPercentage) {
                    actualDiscountAmount = subTotal * (value / 100);
                  } else {
                    actualDiscountAmount = value > subTotal ? subTotal : value;
                  }
                  
                  double actualDiscountPercent = 0.0;
                  if (subTotal > 0) {
                    actualDiscountPercent = (actualDiscountAmount / subTotal) * 100;
                  }
                  
                  String? approvedBy;
                  // Nếu chiết khấu > 10% và user không phải admin, yêu cầu phê duyệt
                  if (actualDiscountPercent > 10.0 && !authProvider.isAdminUser) {
                    final approved = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.approvalRequired),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.discountExceedsThreshold(actualDiscountPercent.toStringAsFixed(1)),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.onlyAdminCanApprove,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                        ],
                      ),
                    );
                    
                    if (approved != true) {
                      return; // Người dùng không phải admin, không thể phê duyệt
                    }
                  }
                  
                  // Nếu là admin, tự động phê duyệt
                  if (authProvider.isAdminUser && actualDiscountPercent > 10.0) {
                    approvedBy = authProvider.userProfile?.displayName ?? authProvider.user?.email ?? 'Admin';
                  }
                  
                  final success = salesProvider.setOrderDiscount(
                    value,
                    discountTypeIsPercentage,
                    tabId: _activeTabId,
                    approvedBy: approvedBy,
                  );
                  
                  if (!success) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(salesProvider.errorMessage ?? AppLocalizations.of(context)!.cannotApplyDiscount),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                } else {
                  salesProvider.clearDiscount(tabId: _activeTabId);
                }
                discountController.dispose();
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

}

// Import các widget còn lại từ file cũ
class ProductSelectionScreen extends StatefulWidget {
  final String? initialSearch;
  
  const ProductSelectionScreen({super.key, this.initialSearch});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    // Khi mở trang: có initialSearch thì tìm kiếm, không thì tải toàn bộ sản phẩm
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      if (widget.initialSearch != null && widget.initialSearch!.trim().isNotEmpty) {
        productProvider.searchProducts(widget.initialSearch!);
      } else {
        productProvider.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectProduct),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = productProvider.products
              .where((p) => p.isSellable && p.isActive)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchProduct,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(LucideIcons.qrCode, size: 22),
                      tooltip: AppLocalizations.of(context)!.scanBarcode,
                      onPressed: () async {
                        final barcode = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BarcodeScannerScreen(),
                          ),
                        );
                        if (barcode != null && barcode.isNotEmpty && mounted) {
                          _searchController.text = barcode;
                          await productProvider.searchProducts(barcode);
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                  onChanged: (query) {
                    productProvider.searchProducts(query);
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 0,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final stock = productProvider.getStockForCurrentBranch(product);
                    final branchId = context.read<BranchProvider>().currentBranchId;
                    final price = branchId != null && product.branchPrices.containsKey(branchId)
                        ? product.branchPrices[branchId]!
                        : product.price;
                    final canAdd = stock > 0;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (canAdd) {
                            Navigator.pop(context, product);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)!.productOutOfStock),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Giá bán: ${NumberFormat('#,###').format(price.toInt())} đ • Tồn kho: ${NumberFormat('#,###').format(stock.toInt())}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (canAdd)
                                const Icon(Icons.add_shopping_cart, color: Colors.green, size: 24)
                              else
                                Text(
                                  AppLocalizations.of(context)!.outOfStock,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scanBarcode),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
