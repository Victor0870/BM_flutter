import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_provider.dart';
import '../../services/purchase_service.dart';
import '../../services/product_service.dart';
import '../../models/purchase_model.dart';

/// Màn hình lịch sử nhập kho
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<PurchaseModel> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final purchaseService = PurchaseService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );

      final purchases = await purchaseService.getPurchases();
      setState(() {
        _purchases = purchases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lịch sử: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPrice(double price) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
    ).format(price);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Đã nhập';
      case 'DRAFT':
        return 'Nháp';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'DRAFT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nhập kho'),
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
      body: RefreshIndicator(
        onRefresh: _loadPurchases,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _purchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có phiếu nhập nào',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _purchases[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(purchase.status)
                                .withOpacity(0.2),
                            child: Icon(
                              purchase.status == 'COMPLETED'
                                  ? Icons.check_circle
                                  : Icons.drafts,
                              color: _getStatusColor(purchase.status),
                            ),
                          ),
                          title: Text(
                            purchase.supplierName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDate(purchase.timestamp)),
                              Text(
                                '${purchase.items.length} sản phẩm',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Chip(
                                label: Text(_getStatusText(purchase.status)),
                                backgroundColor:
                                    _getStatusColor(purchase.status)
                                        .withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: _getStatusColor(purchase.status),
                                  fontSize: 12,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          trailing: Text(
                            _formatPrice(purchase.totalAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onTap: () {
                            _showPurchaseDetail(purchase);
                          },
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showPurchaseDetail(PurchaseModel purchase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết phiếu nhập: ${purchase.supplierName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mã phiếu: ${purchase.id}'),
                const SizedBox(height: 8),
                Text('Nhà cung cấp: ${purchase.supplierName}'),
                const SizedBox(height: 8),
                Text('Ngày nhập: ${_formatDate(purchase.timestamp)}'),
                const SizedBox(height: 8),
                Text(
                  'Trạng thái: ${_getStatusText(purchase.status)}',
                  style: TextStyle(
                    color: _getStatusColor(purchase.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const Text(
                  'Danh sách sản phẩm:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...purchase.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} (x${item.quantity.toStringAsFixed(0)})',
                            ),
                          ),
                          Text(
                            _formatPrice(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
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
                      _formatPrice(purchase.totalAmount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

