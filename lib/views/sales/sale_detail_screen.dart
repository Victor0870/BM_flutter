import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/einvoice_service.dart';
import '../../services/sales_service.dart';
import '../../models/shop_model.dart';
import '../../widgets/responsive_container.dart';
import 'sales_return_form_screen.dart';

/// Màn hình hiển thị chi tiết hóa đơn
class SaleDetailScreen extends StatefulWidget {
  final SaleModel sale;

  const SaleDetailScreen({
    super.key,
    required this.sale,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  ShopModel? _shop;
  bool _isLoadingShop = true;
  bool _isCreatingInvoice = false;
  String? _einvoiceUrl; // Lưu link tra cứu hóa đơn điện tử

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        final firebaseService = FirebaseService();
        final shop = await firebaseService.getShopData(authProvider.user!.uid);
        setState(() {
          _shop = shop;
          _isLoadingShop = false;
        });
      } else {
        setState(() {
          _isLoadingShop = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingShop = false;
      });
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return 'Tiền mặt';
      case 'CARD':
        return 'Thẻ';
      case 'TRANSFER':
        return 'Chuyển khoản';
      default:
        return method;
    }
  }

  void _handlePrint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng in đang phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createEinvoice() async {
    if (_shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin shop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kiểm tra cấu hình hóa đơn điện tử
    if (_shop!.stax == null || _shop!.stax!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình mã số thuế trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_shop!.serial == null || _shop!.serial!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình ký hiệu hóa đơn trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_shop!.einvoiceConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình thông tin đăng nhập FPT trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingInvoice = true;
    });

    try {
      final einvoiceService = EinvoiceService();
      final authProvider = context.read<AuthProvider>();
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      
      final invoiceInfo = await einvoiceService.createInvoice(
        sale: widget.sale,
        shop: _shop!,
        salesService: salesService,
      );

      final link = invoiceInfo['link'] ?? '';
      final finalLink = link.isNotEmpty && link.startsWith('http') ? link : null;
      
      if (!mounted) return;
      
      setState(() {
        _isCreatingInvoice = false;
        _einvoiceUrl = finalLink;
      });
      
      // Hiển thị dialog với link tra cứu
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tạo hóa đơn điện tử thành công!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hóa đơn điện tử đã được tạo thành công.'),
                const SizedBox(height: 12),
                if (_einvoiceUrl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Link tra cứu:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _einvoiceUrl!,
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
              if (_einvoiceUrl != null)
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(_einvoiceUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Mở link'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCreatingInvoice = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo hóa đơn điện tử: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết hóa đơn'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _handlePrint,
            tooltip: 'In hóa đơn',
          ),
        ],
      ),
      body: _isLoadingShop
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Thông tin shop
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _shop?.name.isNotEmpty == true
                              ? _shop!.name
                              : 'Tên cửa hàng',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_shop?.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ĐT: ${_shop!.phone}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (_shop?.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _shop!.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Thông tin đơn hàng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã đơn: #${widget.sale.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.sale.timestamp)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (widget.sale.customerName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            'KH: ${widget.sale.customerName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const Divider(height: 32),

                  // Danh sách sản phẩm
                  const Text(
                    'Sản phẩm:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Header bảng
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Tên SP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'SL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Đơn giá',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Thành tiền',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Danh sách items
                  ...widget.sale.items.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                item.productName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.quantity.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: '₫',
                              ).format(item.price),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: '₫',
                              ).format(item.subtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 32),

                  // Tổng cộng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng cộng:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: '₫',
                        ).format(widget.sale.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Phương thức thanh toán
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thanh toán:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        _formatPaymentMethod(widget.sale.paymentMethod),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (widget.sale.notes != null && widget.sale.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ghi chú:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.sale.notes!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Link tra cứu hóa đơn điện tử (nếu có)
                  if (_einvoiceUrl != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Link tra cứu hóa đơn điện tử:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _einvoiceUrl!,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(_einvoiceUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Không thể mở link'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text('Xem hóa đơn online'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[300]!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Nút Tạo hóa đơn điện tử
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingInvoice ? null : _createEinvoice,
                      icon: _isCreatingInvoice
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text(
                        _isCreatingInvoice
                            ? 'Đang tạo hóa đơn...'
                            : 'Tạo hóa đơn điện tử',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút Trả hàng
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Điều hướng đến màn hình trả hàng với hóa đơn đã chọn
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesReturnFormScreen(
                              preSelectedSaleId: widget.sale.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Trả hàng'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút In
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handlePrint,
                      icon: const Icon(Icons.print),
                      label: const Text('In hóa đơn'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

