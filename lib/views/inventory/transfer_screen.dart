import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/transfer_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../utils/platform_utils.dart';

const String kMainStoreBranchId = 'main_store';

/// Màn hình chuyển kho: chỉ hiển thị khi tài khoản Pro và có từ 2 chi nhánh trở lên.
/// Giao diện desktop theo ảnh minh họa (header + bảng trái + sidebar phải).
class TransferScreen extends StatefulWidget {
  final bool? forceMobile;

  const TransferScreen({super.key, this.forceMobile});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _showProductSelection() async {
    final product = await Navigator.push<ProductModel>(
      context,
      MaterialPageRoute(
        builder: (context) => _TransferProductSelectionScreen(
          onSelect: (p) => Navigator.pop(context, p),
        ),
      ),
    );
    if (product != null && mounted) {
      context.read<TransferProvider>().addItem(product, quantity: 1);
    }
  }

  Future<void> _handleSaveTransfer({required bool complete}) async {
    final tp = context.read<TransferProvider>();
    final success = await tp.saveTransfer(complete: complete);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(complete ? 'Chuyển kho hoàn thành!' : 'Đã lưu phiếu tạm.'),
          backgroundColor: Colors.green,
        ),
      );
      if (complete) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tp.errorMessage ?? 'Lưu thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final employeeName = authProvider.userProfile?.displayName ?? authProvider.user?.email?.split('@').first ?? 'Nhân viên';
    final now = DateTime.now();

    return Column(
      children: [
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
                  'Chuyển hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm hàng hóa theo mã hoặc tên (F3)',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (q) {
                      if (q.trim().isEmpty) return;
                      context.read<ProductProvider>().searchProducts(q);
                      _showProductSelection();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.grid_view), onPressed: () {}, tooltip: 'Xem'),
                IconButton(icon: const Icon(Icons.edit_note), onPressed: _showProductSelection, tooltip: 'Thêm hàng'),
                IconButton(icon: const Icon(Icons.print_outlined), onPressed: () {}, tooltip: 'In'),
                IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () {}, tooltip: 'Xem'),
                IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}, tooltip: 'Thông tin'),
                const Spacer(),
                Icon(Icons.person_outline, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
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
        Expanded(
          child: Consumer<TransferProvider>(
            builder: (context, transferProvider, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildDesktopTable(context, transferProvider)),
                  SizedBox(width: 340, child: _buildDesktopSidebar(context, transferProvider)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context, TransferProvider transferProvider) {
    final productProvider = context.read<ProductProvider>();
    final authProvider = context.read<AuthProvider>();
    final branchProvider = context.read<BranchProvider>();
    final fromBranchId = authProvider.selectedBranchId ?? branchProvider.currentBranchId ?? kMainStoreBranchId;

    if (transferProvider.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có mặt hàng nào',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showProductSelection,
              icon: const Icon(Icons.add),
              label: const Text('Thêm hàng hóa'),
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
            DataColumn(label: Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Tồn kho nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('SL chuyển', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Giá chuyển', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
            DataColumn(label: Text('Thành tiền', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
          ],
          rows: List.generate(transferProvider.items.length, (index) {
            final item = transferProvider.items[index];
            final stt = index + 1;
            ProductModel? product;
            for (final p in productProvider.products) {
              if (p.id == item.productId) { product = p; break; }
            }
            final unitName = product?.units.isNotEmpty == true ? product!.units.first.unitName : 'cái';
            final stockFrom = product?.branchStock[fromBranchId] ?? 0.0;
            final toId = transferProvider.toBranchId;
            final stockTo = (toId != null && toId.isNotEmpty) ? (product?.branchStock[toId] ?? 0.0) : 0.0;
            final code = product?.code?.isNotEmpty == true ? product!.code! : item.productId;
            final displayCode = code.length > 14 ? '${code.substring(0, 14)}...' : code;
            return DataRow(
              cells: [
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => transferProvider.removeItem(item.productId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                  ),
                ),
                DataCell(Text('$stt', style: const TextStyle(fontSize: 13))),
                DataCell(Text(displayCode, style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w500))),
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
                DataCell(Text(stockFrom.toStringAsFixed(0), style: const TextStyle(fontSize: 13))),
                DataCell(Text(stockTo.toStringAsFixed(0), style: const TextStyle(fontSize: 13))),
                DataCell(Text(item.quantity.toStringAsFixed(0), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_formatPrice(item.costPrice), style: const TextStyle(fontSize: 13))),
                DataCell(Text(_formatPrice(item.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, TransferProvider transferProvider) {
    final branchProvider = context.watch<BranchProvider>();
    final authProvider = context.watch<AuthProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final fromBranchId = authProvider.selectedBranchId ?? branchProvider.currentBranchId ?? kMainStoreBranchId;
    final toBranches = branches.where((b) => b.id != fromBranchId).toList();

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebarLabel('Mã chuyển hàng'),
            const SizedBox(height: 4),
            Text('Mã phiếu tự động', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            _sidebarLabel('Trạng thái'),
            const SizedBox(height: 4),
            Text('Phiếu tạm', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            _sidebarLabel('Tổng số lượng'),
            const SizedBox(height: 4),
            Text('${transferProvider.totalQuantity}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _sidebarLabel('Chuyển tới'),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: transferProvider.toBranchId != null && toBranches.any((b) => b.id == transferProvider.toBranchId)
                  ? transferProvider.toBranchId
                  : null,
              decoration: InputDecoration(
                hintText: 'Chọn chi nhánh',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: toBranches
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.id == kMainStoreBranchId ? 'Cửa hàng chính' : b.name),
                      ))
                  .toList(),
              onChanged: (v) => transferProvider.setToBranchId(v),
            ),
            const SizedBox(height: 12),
            _sidebarLabel('Ghi chú'),
            const SizedBox(height: 4),
            TextField(
              maxLines: 3,
              onChanged: transferProvider.setNotes,
              decoration: InputDecoration(
                hintText: 'Ghi chú phiếu chuyển',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: transferProvider.isLoading ? null : () => _handleSaveTransfer(complete: false),
                icon: const Icon(Icons.save, size: 20),
                label: const Text('Lưu tạm'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: transferProvider.isLoading ? null : () => _handleSaveTransfer(complete: true),
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
    final authProvider = context.watch<AuthProvider>();
    final branchProvider = context.watch<BranchProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final canUse = authProvider.isPro && branches.length >= 2;

    if (!canUse) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chuyển kho')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.orange.shade700),
                const SizedBox(height: 16),
                Text(
                  'Chức năng Chuyển kho chỉ dành cho tài khoản Pro và khi có ít nhất 2 chi nhánh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_useMobileLayout) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildDesktopLayout(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyển kho'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Chuyển kho: vui lòng dùng giao diện desktop.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

/// Màn hình chọn sản phẩm để thêm vào phiếu chuyển kho
class _TransferProductSelectionScreen extends StatefulWidget {
  final void Function(ProductModel) onSelect;

  const _TransferProductSelectionScreen({required this.onSelect});

  @override
  State<_TransferProductSelectionScreen> createState() => _TransferProductSelectionScreenState();
}

class _TransferProductSelectionScreenState extends State<_TransferProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
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
        title: const Text('Chọn hàng hóa chuyển kho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.read<ProductProvider>().searchProducts(_searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã hoặc tên',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (q) => context.read<ProductProvider>().searchProducts(q),
            ),
          ),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                if (productProvider.products.isEmpty && !productProvider.isLoading) {
                  return const Center(child: Text('Không có sản phẩm nào'));
                }
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: productProvider.products.length,
                  itemBuilder: (context, index) {
                    final p = productProvider.products[index];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.code ?? p.id} · Tồn: ${p.stock}'),
                      trailing: const Icon(Icons.add),
                      onTap: () => widget.onSelect(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
