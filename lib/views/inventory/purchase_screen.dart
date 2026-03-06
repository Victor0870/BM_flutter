import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/purchase_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/branch_model.dart';
import '../../models/unit_conversion.dart';
import '../../models/supplier_model.dart';
import '../../services/supplier_service.dart';
import '../../core/routes.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình nhập kho (mobile/desktop theo platform).
class PurchaseScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const PurchaseScreen({super.key, this.forceMobile});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _searchHeaderController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    _supplierNameController.dispose();
    _searchHeaderController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load products và sync controller với provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      
      // Luôn load products khi mở PurchaseScreen để đảm bảo có dữ liệu mới nhất
      if (!productProvider.isLoading) {
        productProvider.loadProducts();
      }
      
      // Sync controller với provider
      _supplierNameController.text = purchaseProvider.supplierName;
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
      _barcodeController.text = result;
      _searchAndAddProduct(result);
    }
  }

  Future<void> _searchAndAddProduct(String barcode) async {
    final productProvider = context.read<ProductProvider>();

    // Đảm bảo products đã được load trước khi tìm kiếm
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      await productProvider.loadProducts();
    }

    // Tìm sản phẩm theo barcode
    await productProvider.searchProducts(barcode);
    final products = productProvider.products
        .where((p) => p.barcode?.toLowerCase() == barcode.toLowerCase())
        .toList();

    if (products.isNotEmpty) {
      _showPurchaseItemDialog(products.first);
      _barcodeController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy sản phẩm với mã vạch này'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showProductSelection() async {
    final product = await Navigator.push<ProductModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const PurchaseProductSelectionScreen(),
      ),
    );

    if (product != null && mounted) {
      _showPurchaseItemDialog(product);
    }
  }

  Future<void> _showPurchaseItemDialog(ProductModel product) async {
    final purchaseProvider = context.read<PurchaseProvider>();
    final existingItem = purchaseProvider.cart[product.id];

    final quantityController = TextEditingController(
      text: existingItem?.quantity.toStringAsFixed(0) ?? '1',
    );
    final importPriceController = TextEditingController(
      text: existingItem?.importPrice.toStringAsFixed(0) ?? product.importPrice.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nhập hàng: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Số lượng nhập',
                hintText: 'Nhập số lượng',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: importPriceController,
              decoration: const InputDecoration(
                labelText: 'Giá nhập',
                hintText: 'Nhập giá nhập',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (existingItem != null) ...[
              const SizedBox(height: 8),
              Text(
                'Giá nhập hiện tại: ${product.importPrice.toStringAsFixed(0)} đ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              final importPrice = double.tryParse(importPriceController.text) ?? 0;

              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Số lượng phải lớn hơn 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (importPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giá nhập không hợp lệ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              purchaseProvider.addToCart(
                product,
                quantity: quantity,
                importPrice: importPrice,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã thêm vào giỏ nhập kho'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    quantityController.dispose();
    importPriceController.dispose();
  }

  Future<void> _handleSavePurchase({bool complete = false}) async {
    final purchaseProvider = context.read<PurchaseProvider>();

    if (purchaseProvider.supplierName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nhà cung cấp'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị dialog xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(complete ? 'Xác nhận nhập kho' : 'Lưu nháp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhà cung cấp: ${purchaseProvider.supplierName}'),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${_formatPrice(purchaseProvider.cartTotal)} đ'),
            const SizedBox(height: 8),
            Text('Số sản phẩm: ${purchaseProvider.cartItemCount}'),
            if (complete) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ Lưu ý: Khi xác nhận, số lượng sẽ được cộng vào tồn kho!',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: complete ? Colors.green : Colors.blue,
            ),
            child: Text(complete ? 'Xác nhận' : 'Lưu'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await purchaseProvider.savePurchase(complete: complete);
      if (mounted) {
        if (success) {
          // Reload products để cập nhật stock mới
          final productProvider = context.read<ProductProvider>();
          await productProvider.loadProducts();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                complete
                    ? 'Nhập kho thành công! Số lượng đã được cập nhật.'
                    : 'Đã lưu nháp thành công!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Quay lại màn hình trước
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                purchaseProvider.errorMessage ?? 'Lưu phiếu nhập thất bại',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  static const Color _bluePrimary = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFFEFF6FF);

  Widget _buildMobileModernForm(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 26, color: _bluePrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhập kho',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nhà cung cấp, chi nhánh và quét mã vạch',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildMobileLabel('Nhà cung cấp *'),
          const SizedBox(height: 6),
          _buildMobileSupplierField(context),
          const SizedBox(height: 18),
          _buildMobileLabel('Chi nhánh nhập *'),
          const SizedBox(height: 6),
          Consumer2<AuthProvider, BranchProvider>(
            builder: (context, authProvider, branchProvider, _) {
              final isPro = authProvider.isPro;
              final branches = branchProvider.branches.where((b) => b.isActive).toList();
              // Basic: chỉ Cửa hàng chính. Pro: chọn được; chưa có thêm chi nhánh thì mặc định Cửa hàng chính.
              final selectedBranchId = authProvider.selectedBranchId ?? branchProvider.currentBranchId ?? kMainStoreBranchId;
              final effectiveId = isPro
                  ? (branches.any((b) => b.id == selectedBranchId)
                      ? selectedBranchId
                      : (branches.isNotEmpty ? branches.first.id : kMainStoreBranchId))
                  : kMainStoreBranchId;
              final displayName = effectiveId == kMainStoreBranchId
                  ? 'Cửa hàng chính'
                  : (branches.where((b) => b.id == effectiveId).firstOrNull?.name ?? 'Cửa hàng chính');
              // Bản Basic: không cho chọn chi nhánh; Pro: mở bottom sheet chọn (hoặc chỉ hiển thị nếu chỉ có 1 chi nhánh).
              final canTap = isPro && branches.isNotEmpty;
              return InkWell(
                onTap: canTap
                    ? () => _showMobileBranchPicker(
                          context,
                          branches: branches,
                          currentId: effectiveId,
                          onSelect: (branchId) async {
                            await authProvider.setSelectedBranchId(branchId);
                            await branchProvider.setSelectedBranch(branchId);
                          },
                        )
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _mobileInputDecoration('Chọn chi nhánh').copyWith(
                    prefixIcon: const Icon(Icons.store_outlined, size: 22, color: Color(0xFF64748B)),
                    suffixIcon: canTap ? const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)) : null,
                  ),
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _buildMobileLabel('Mã vạch'),
          const SizedBox(height: 6),
          TextField(
            controller: _barcodeController,
            decoration: _mobileInputDecoration('Nhập hoặc quét mã vạch').copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: _bluePrimary),
                onPressed: _scanBarcode,
                tooltip: 'Quét mã vạch',
              ),
            ),
            onSubmitted: _searchAndAddProduct,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _showProductSelection,
              icon: const Icon(Icons.list_alt, size: 22),
              label: const Text('Chọn sản phẩm từ danh sách', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: _bluePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSupplierField(BuildContext context) {
    final purchaseProvider = context.read<PurchaseProvider>();
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.uid;
        if (userId == null) {
          return TextField(
            controller: _supplierNameController,
            decoration: _mobileInputDecoration('Nhập tên nhà cung cấp'),
            onChanged: (v) => purchaseProvider.setSupplierName(v),
          );
        }
        final service = SupplierService(userId: userId);
        return StreamBuilder<List<SupplierModel>>(
          stream: service.streamByShop(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return TextField(
                controller: _supplierNameController,
                decoration: _mobileInputDecoration('Nhập tên nhà cung cấp'),
                onChanged: (v) => purchaseProvider.setSupplierName(v),
              );
            }
            final selectedFromList = list.where((s) => s.name == purchaseProvider.supplierName).firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SupplierModel?>(
                  initialValue: selectedFromList,
                  decoration: _mobileInputDecoration('Chọn nhà cung cấp').copyWith(
                    prefixIcon: const Icon(Icons.business_center_outlined, size: 22, color: Color(0xFF64748B)),
                  ),
                  items: [
                    ...list.map((s) => DropdownMenuItem<SupplierModel?>(value: s, child: Text(s.name))),
                    const DropdownMenuItem<SupplierModel?>(value: null, child: Text('Nhập tên khác')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      purchaseProvider.setSupplierName(v.name);
                      _supplierNameController.text = v.name;
                    }
                  },
                ),
                if (selectedFromList == null) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supplierNameController,
                    decoration: _mobileInputDecoration('Nhập tên nhà cung cấp'),
                    onChanged: (v) => purchaseProvider.setSupplierName(v),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopSupplierField(BuildContext context, PurchaseProvider purchaseProvider) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.uid;
        if (userId == null) {
          return TextField(
            controller: _supplierNameController,
            decoration: InputDecoration(
              hintText: 'Nhập tên nhà cung cấp',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => Navigator.pushNamed(context, AppRoutes.supplierForm), tooltip: 'Thêm nhà cung cấp'),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => purchaseProvider.setSupplierName(v),
          );
        }
        final service = SupplierService(userId: userId);
        return StreamBuilder<List<SupplierModel>>(
          stream: service.streamByShop(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            final selectedFromList = list.where((s) => s.name == purchaseProvider.supplierName).firstOrNull;
            if (list.isEmpty) {
              return TextField(
                controller: _supplierNameController,
                decoration: InputDecoration(
                  hintText: 'Nhập tên nhà cung cấp',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => Navigator.pushNamed(context, AppRoutes.supplierForm), tooltip: 'Thêm nhà cung cấp'),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => purchaseProvider.setSupplierName(v),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<SupplierModel?>(
                  initialValue: selectedFromList,
                  decoration: InputDecoration(
                    hintText: 'Chọn nhà cung cấp',
                    prefixIcon: const Icon(Icons.business_center_outlined, size: 20),
                    suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => Navigator.pushNamed(context, AppRoutes.supplierForm), tooltip: 'Thêm nhà cung cấp'),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    ...list.map((s) => DropdownMenuItem<SupplierModel?>(value: s, child: Text(s.name))),
                    const DropdownMenuItem<SupplierModel?>(value: null, child: Text('Nhập tên khác')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      purchaseProvider.setSupplierName(v.name);
                      _supplierNameController.text = v.name;
                    }
                  },
                ),
                if (selectedFromList == null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _supplierNameController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhà cung cấp',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) => purchaseProvider.setSupplierName(v),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormSupplierField(BuildContext context) {
    final purchaseProvider = context.read<PurchaseProvider>();
    final decoration = InputDecoration(
      labelText: 'Nhà cung cấp *',
      hintText: 'Nhập tên nhà cung cấp',
      prefixIcon: const Icon(Icons.business),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.uid;
        if (userId == null) {
          return TextField(
            controller: _supplierNameController,
            decoration: decoration,
            onChanged: (v) => purchaseProvider.setSupplierName(v),
          );
        }
        final service = SupplierService(userId: userId);
        return StreamBuilder<List<SupplierModel>>(
          stream: service.streamByShop(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return TextField(
                controller: _supplierNameController,
                decoration: decoration,
                onChanged: (v) => purchaseProvider.setSupplierName(v),
              );
            }
            final selectedFromList = list.where((s) => s.name == purchaseProvider.supplierName).firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SupplierModel?>(
                  initialValue: selectedFromList,
                  decoration: decoration.copyWith(hintText: 'Chọn nhà cung cấp'),
                  items: [
                    ...list.map((s) => DropdownMenuItem<SupplierModel?>(value: s, child: Text(s.name))),
                    const DropdownMenuItem<SupplierModel?>(value: null, child: Text('Nhập tên khác')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      purchaseProvider.setSupplierName(v.name);
                      _supplierNameController.text = v.name;
                    }
                  },
                ),
                if (selectedFromList == null) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supplierNameController,
                    decoration: decoration,
                    onChanged: (v) => purchaseProvider.setSupplierName(v),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showMobileBranchPicker(
    BuildContext context, {
    required List<BranchModel> branches,
    required String currentId,
    required Future<void> Function(String branchId) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn chi nhánh nhập',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: branches.length,
                  itemBuilder: (_, i) {
                    final b = branches[i];
                    final name = b.id == kMainStoreBranchId ? 'Cửa hàng chính' : b.name;
                    final isSelected = b.id == currentId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? _bluePrimary : const Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: _bluePrimary, size: 22)
                          : null,
                      onTap: () async {
                        await onSelect(b.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
    );
  }

  InputDecoration _mobileInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bluePrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  /// Giao diện desktop theo ảnh minh họa: header (back, title, search, icons, nhân viên, ngày giờ) + bảng trái + sidebar phải.
  Widget _buildDesktopLayout(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final employeeName = authProvider.userProfile?.displayName ?? authProvider.user?.email?.split('@').first ?? 'Nhân viên';
    final now = DateTime.now();

    return Column(
      children: [
        // Header
        Material(
          elevation: 0,
          color: Colors.white,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Quay lại',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Nhập hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchHeaderController,
                    decoration: InputDecoration(
                      hintText: 'Q KH',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.dehaze), onPressed: () {}, tooltip: 'Xem'),
                IconButton(icon: const Icon(Icons.dehaze), onPressed: () {}, tooltip: 'Xem'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showProductSelection,
                  tooltip: 'Thêm sản phẩm',
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.print_outlined), onPressed: () {}, tooltip: 'In'),
                IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () {}, tooltip: 'Xem'),
                IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}, tooltip: 'Thông tin'),
                const SizedBox(width: 16),
                Text(
                  employeeName.length > 12 ? '${employeeName.substring(0, 12)}...' : employeeName,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(now),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Body: bảng trái + sidebar phải
        Expanded(
          child: Consumer<PurchaseProvider>(
            builder: (context, purchaseProvider, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildDesktopTable(context, purchaseProvider)),
                  SizedBox(width: 360, child: _buildDesktopSidebar(context, purchaseProvider)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context, PurchaseProvider purchaseProvider) {
    final productProvider = context.read<ProductProvider>();
    if (purchaseProvider.isCartEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có mặt hàng nào',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showProductSelection,
              icon: const Icon(Icons.add),
              label: const Text('Thêm mặt hàng'),
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
            DataColumn(label: SizedBox(width: 40)),
            DataColumn(label: Text('STT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Mã hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Tên hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('ĐVT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Số lượng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Đơn giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Giảm giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Thành tiền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          ],
          rows: List.generate(purchaseProvider.cartItems.length, (index) {
            final item = purchaseProvider.cartItems[index];
            final stt = index + 1;
            ProductModel? product;
            for (final p in productProvider.products) {
              if (p.id == item.productId) { product = p; break; }
            }
            final unitName = product?.units.isNotEmpty == true ? product!.units.first.unitName : 'cái';
            final code = (product?.code?.isNotEmpty == true ? product!.code! : item.productId);
            final displayCode = code.length > 14 ? '${code.substring(0, 14)}...' : code;
            final productForDialog = product ?? ProductModel(
              id: item.productId,
              name: item.productName,
              units: [UnitConversion(id: '1', unitName: 'cái', conversionValue: 1, price: 0)],
              branchPrices: {'default': 0},
              importPrice: item.importPrice,
              branchStock: {'default': 0},
            );
            return DataRow(
              cells: [
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => purchaseProvider.removeFromCart(item.productId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                  ),
                ),
                DataCell(Text('$stt', style: const TextStyle(fontSize: 13))),
                DataCell(
                  GestureDetector(
                    onTap: () => _showPurchaseItemDialog(productForDialog),
                    child: Text(displayCode, style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Ghi chú...', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(unitName, style: const TextStyle(fontSize: 13))),
                DataCell(
                  GestureDetector(
                    onTap: () => _showPurchaseItemDialog(productForDialog),
                    child: Text(item.quantity.toStringAsFixed(0), style: const TextStyle(fontSize: 13)),
                  ),
                ),
                DataCell(
                  GestureDetector(
                    onTap: () => _showPurchaseItemDialog(productForDialog),
                    child: Text(_formatPrice(item.importPrice), style: const TextStyle(fontSize: 13)),
                  ),
                ),
                DataCell(Text('0', style: const TextStyle(fontSize: 13))),
                DataCell(Text(_formatPrice(item.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, PurchaseProvider purchaseProvider) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDesktopSupplierField(context, purchaseProvider),
            const SizedBox(height: 16),
            _sidebarLabel('Mã phiếu nhập'),
            const SizedBox(height: 4),
            Text('Mã phiếu tự động', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            _sidebarLabel('Mã đặt hàng nhập'),
            const SizedBox(height: 4),
            TextField(
              decoration: InputDecoration(
                hintText: 'Nhập mã đặt hàng',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _sidebarLabel('Trạng thái'),
            const SizedBox(height: 4),
            Text('Phiếu tạm', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            _sidebarLabel('Tổng tiền hàng'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (purchaseProvider.cartItemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('${purchaseProvider.cartItemCount}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                  ),
                const SizedBox(width: 8),
                Text(_formatPrice(purchaseProvider.cartTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _sidebarLabel('Giảm giá'),
            const SizedBox(height: 4),
            Text('0', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            _sidebarLabel('Cần trả nhà cung cấp'),
            const SizedBox(height: 4),
            Text(_formatPrice(purchaseProvider.cartTotal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
            const SizedBox(height: 12),
            _sidebarLabel('Tiền trả nhà cung cấp (F8)'),
            const SizedBox(height: 4),
            TextField(
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _sidebarLabel('Ghi chú'),
            const SizedBox(height: 4),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ghi chú phiếu nhập',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: purchaseProvider.isLoading ? null : () => _handleSavePurchase(complete: false),
                icon: const Icon(Icons.save, size: 20),
                label: const Text('Lưu tạm'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: purchaseProvider.isLoading ? null : () => _handleSavePurchase(complete: true),
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Hoàn thành'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_useMobileLayout) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildDesktopLayout(context),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Nhập kho',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _useMobileLayout ? const Color(0xFF1E293B) : null,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined, size: 22),
            onPressed: () => Navigator.pushNamed(context, '/purchase-history'),
            tooltip: 'Lịch sử nhập kho',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveContainer(
              maxWidth: 800,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Thanh tìm kiếm mã vạch và nhà cung cấp (responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < kBreakpointMobile;
                      if (isNarrow) return _buildMobileModernForm(context);
                      return Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: Column(
                          children: [
                            // Nhà cung cấp
                            _buildFormSupplierField(context),
                  const SizedBox(height: 12),
                  // Chi nhánh nhập kho: Basic = chỉ Cửa hàng chính; Pro = chọn được, mặc định Cửa hàng chính nếu chưa có thêm chi nhánh
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Consumer2<AuthProvider, BranchProvider>(
                      builder: (context, authProvider, branchProvider, child) {
                        final isPro = authProvider.isPro;
                        final branches = branchProvider.branches
                            .where((b) => b.isActive)
                            .toList();
                        final selectedBranchId = authProvider.selectedBranchId ?? branchProvider.currentBranchId ?? kMainStoreBranchId;
                        final effectiveId = isPro && branches.any((b) => b.id == selectedBranchId)
                            ? selectedBranchId
                            : (branches.isNotEmpty ? branches.first.id : kMainStoreBranchId);
                        final hasValue = branches.any((b) => b.id == effectiveId);
                        final showDropdown = isPro && branches.isNotEmpty;

                        if (!showDropdown) {
                          return SizedBox(
                            width: isNarrow ? double.infinity : 320,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Chi nhánh nhập *',
                                prefixIcon: const Icon(Icons.store),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cửa hàng chính', style: TextStyle(fontSize: 16)),
                            ),
                          );
                        }
                        return SizedBox(
                          width: isNarrow ? double.infinity : 320,
                          child: DropdownButtonFormField<String?>(
                            initialValue: hasValue ? effectiveId : (branches.isNotEmpty ? branches.first.id : null),
                            decoration: InputDecoration(
                              labelText: 'Chi nhánh nhập *',
                              prefixIcon: const Icon(Icons.store),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: branches.map(
                              (branch) => DropdownMenuItem<String?>(
                                value: branch.id,
                                child: Text(branch.id == kMainStoreBranchId ? 'Cửa hàng chính' : branch.name),
                              ),
                            ).toList(),
                            onChanged: (value) {
                              authProvider.setSelectedBranchId(value ?? kMainStoreBranchId);
                              branchProvider.setSelectedBranch(value ?? kMainStoreBranchId);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tìm kiếm mã vạch (trên mobile xuống dòng)
                  isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _barcodeController,
                              decoration: InputDecoration(
                                hintText: 'Nhập hoặc quét mã vạch',
                                prefixIcon: const Icon(Icons.qr_code_scanner),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _scanBarcode,
                                  tooltip: 'Quét mã vạch',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onSubmitted: _searchAndAddProduct,
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.list),
                              onPressed: _showProductSelection,
                              tooltip: 'Chọn sản phẩm',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                decoration: InputDecoration(
                                  hintText: 'Nhập hoặc quét mã vạch',
                                  prefixIcon: const Icon(Icons.qr_code_scanner),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.camera_alt),
                                    onPressed: _scanBarcode,
                                    tooltip: 'Quét mã vạch',
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: _searchAndAddProduct,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.list),
                              onPressed: _showProductSelection,
                              tooltip: 'Chọn sản phẩm',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                            ],
                          ),
                        );
                      },
                    ),
                  // Giỏ hàng nhập kho
                  Expanded(
            child: Consumer<PurchaseProvider>(
              builder: (context, purchaseProvider, child) {
                if (purchaseProvider.isCartEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Giỏ nhập kho trống',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quét mã vạch hoặc chọn sản phẩm để bắt đầu',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Danh sách sản phẩm trong giỏ
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: purchaseProvider.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = purchaseProvider.cartItems[index];
                          return _PurchaseItemCard(
                            item: item,
                            onEdit: () {
                              // Lấy product để edit
                              context.read<ProductProvider>().loadProducts();
                              final products = context.read<ProductProvider>().products;
                              final product = products.firstWhere(
                              (p) => p.id == item.productId,
                              orElse: () => ProductModel(
                                id: item.productId,
                                name: item.productName,
                                units: [
                                  UnitConversion(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    unitName: 'cái',
                                    conversionValue: 1.0,
                                    price: 0,
                                  )
                                ],
                                branchPrices: {'default': 0},
                                importPrice: item.importPrice,
                                branchStock: {'default': 0},
                              ),
                              );
                              _showPurchaseItemDialog(product);
                            },
                            onRemove: () {
                              purchaseProvider.removeFromCart(item.productId);
                            },
                            onUpdate: (quantity, importPrice) {
                              purchaseProvider.updateCartItem(
                                item.productId,
                                quantity: quantity,
                                importPrice: importPrice,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Tổng tiền và nút lưu
                    SafeArea(
                      top: false,
                      bottom: true, // Đảm bảo nội dung không bị che bởi thanh điều hướng hệ thống
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng tiền:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatPrice(purchaseProvider.cartTotal)} đ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: purchaseProvider.isLoading
                                      ? null
                                      : () => _handleSavePurchase(complete: false),
                                  child: const Text('Lưu nháp'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: purchaseProvider.isLoading
                                      ? null
                                      : () => _handleSavePurchase(complete: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: purchaseProvider.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Xác nhận nhập'),
                                ),
                              ),
                            ],
                          ),
                        ],
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
        ),
      ),
      ],
      ),
    );
  }
}

/// Widget hiển thị một item trong giỏ nhập kho với khả năng chỉnh sửa nhanh
class _PurchaseItemCard extends StatefulWidget {
  final PurchaseItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final Function(double, double) onUpdate; // quantity, importPrice

  const _PurchaseItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _priceController = TextEditingController(
      text: widget.item.importPrice.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_PurchaseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity ||
        oldWidget.item.importPrice != widget.item.importPrice) {
      _quantityController.text = widget.item.quantity.toStringAsFixed(0);
      _priceController.text = widget.item.importPrice.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    if (quantity > 0 && price >= 0) {
      widget.onUpdate(quantity, price);
      setState(() {
        _isEditing = false;
      });
    } else {
      // Reset về giá trị cũ nếu không hợp lệ
      _quantityController.text = widget.item.quantity.toStringAsFixed(0);
      _priceController.text = widget.item.importPrice.toStringAsFixed(0);
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giá trị không hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tên sản phẩm
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        tooltip: 'Sửa nhanh',
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        onPressed: widget.onRemove,
                        tooltip: 'Xóa',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: Colors.green,
                        onPressed: _saveChanges,
                        tooltip: 'Lưu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                        onPressed: () {
                          _quantityController.text = widget.item.quantity.toStringAsFixed(0);
                          _priceController.text = widget.item.importPrice.toStringAsFixed(0);
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        tooltip: 'Hủy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Thông tin số lượng và giá
            if (_isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Giá nhập',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SL: ${widget.item.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Giá nhập: ${widget.item.importPrice.toStringAsFixed(0)} đ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Thành tiền: ${widget.item.subtotal.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Màn hình chọn sản phẩm để nhập kho
class PurchaseProductSelectionScreen extends StatefulWidget {
  const PurchaseProductSelectionScreen({super.key});

  @override
  State<PurchaseProductSelectionScreen> createState() => _PurchaseProductSelectionScreenState();
}

class _PurchaseProductSelectionScreenState extends State<PurchaseProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load products khi mở màn hình chọn sản phẩm nhập kho
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      // Luôn load products khi mở màn hình này để đảm bảo có dữ liệu mới nhất
      productProvider.loadProducts();
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
      appBar: AppBar(
        title: const Text('Chọn sản phẩm nhập kho'),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductProvider>().clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                context.read<ProductProvider>().searchProducts(query);
              },
            ),
          ),
          // Danh sách sản phẩm
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (productProvider.products.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => productProvider.loadProducts(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có sản phẩm nào',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Kéo xuống để làm mới',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => productProvider.loadProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          'Giá nhập: ${product.importPrice.toStringAsFixed(0)} đ - Tồn: ${product.stock.toStringAsFixed(0)} ${product.unit}',
                        ),
                        trailing: const Icon(Icons.add_shopping_cart),
                        onTap: () => Navigator.pop(context, product),
                      );
                    },
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

/// Màn hình quét mã vạch (reuse từ sales_screen)
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
        title: const Text('Quét mã vạch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
            tooltip: 'Bật/tắt đèn flash',
          ),
        ],
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
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Đưa mã vạch vào khung hình',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

