import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/stock_history_model.dart';
import '../../models/branch_model.dart';

/// Dialog để kiểm kê kho - cho phép chọn sản phẩm và nhập số lượng thực tế
class StockCountDialog extends StatefulWidget {
  final String? selectedBranchId;

  const StockCountDialog({super.key, this.selectedBranchId});

  @override
  State<StockCountDialog> createState() => _StockCountDialogState();
}

class _StockCountDialogState extends State<StockCountDialog> {
  ProductModel? _selectedProduct;
  final TextEditingController _actualQuantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _actualQuantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _getCurrentStock(ProductModel product, String? branchId) {
    final targetBranchId = branchId ?? kMainStoreBranchId;
    if (product.variants.isNotEmpty) {
      double total = 0;
      for (final variant in product.variants) {
        total += variant.branchStock[targetBranchId] ?? 0.0;
      }
      return total;
    } else {
      return product.branchStock[targetBranchId] ?? 0.0;
    }
  }

  Future<void> _saveStockCount() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sản phẩm')),
      );
      return;
    }

    final actualQuantityText = _actualQuantityController.text.trim();
    if (actualQuantityText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số lượng thực tế')),
      );
      return;
    }

    final actualQuantity = double.tryParse(actualQuantityText);
    if (actualQuantity == null || actualQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng không hợp lệ')),
      );
      return;
    }

    final branchId = widget.selectedBranchId ?? kMainStoreBranchId;
    final currentStock = _getCurrentStock(_selectedProduct!, branchId);
    final difference = actualQuantity - currentStock;

    if (difference == 0) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng không thay đổi')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final productProvider = context.read<ProductProvider>();
      final note = _noteController.text.trim().isEmpty
          ? 'Kiểm kê kho - Thực tế: $actualQuantity, Hệ thống: ${currentStock.toStringAsFixed(0)}'
          : _noteController.text.trim();

      final success = await productProvider.adjustProductStock(
        _selectedProduct!.id,
        branchId,
        difference,
        type: StockHistoryType.adjustment,
        note: note,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã cập nhật tồn kho: ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(0)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(productProvider.errorMessage ?? 'Có lỗi xảy ra'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kiểm kê kho',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Chọn sản phẩm
            Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                final products = productProvider.products;
                return DropdownButtonFormField<ProductModel>(
                  value: _selectedProduct,
                  decoration: InputDecoration(
                    labelText: 'Chọn sản phẩm',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: products.map((product) {
                    return DropdownMenuItem<ProductModel>(
                      value: product,
                      child: Text(product.name),
                    );
                  }).toList(),
                  onChanged: _isProcessing
                      ? null
                      : (product) {
                          setState(() {
                            _selectedProduct = product;
                            if (product != null) {
                              final currentStock = _getCurrentStock(product, widget.selectedBranchId);
                              _actualQuantityController.text = currentStock.toStringAsFixed(0);
                            }
                          });
                        },
                );
              },
            ),
            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              // Hiển thị tồn kho hiện tại
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tồn kho hệ thống:',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      _getCurrentStock(_selectedProduct!, widget.selectedBranchId)
                          .toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Nhập số lượng thực tế
            TextField(
              controller: _actualQuantityController,
              decoration: InputDecoration(
                labelText: 'Số lượng thực tế',
                hintText: 'Nhập số lượng sau khi kiểm kê',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isProcessing && _selectedProduct != null,
            ),
            const SizedBox(height: 16),
            // Ghi chú
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                hintText: 'Nhập ghi chú cho việc kiểm kê',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
              enabled: !_isProcessing,
            ),
            const SizedBox(height: 24),
            // Nút lưu
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _saveStockCount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
