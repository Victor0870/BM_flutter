import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';
import '../../services/sales_service.dart';
import '../../controllers/auth_provider.dart';
import '../../widgets/responsive_container.dart';
import '../../core/routes.dart';
import 'customer_form_screen.dart';

/// Màn hình chi tiết khách hàng
class CustomerDetailScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<SaleModel> _salesHistory = [];
  bool _isLoadingSales = false;

  @override
  void initState() {
    super.initState();
    _loadSalesHistory();
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _isLoadingSales = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.user == null) {
        setState(() {
          _isLoadingSales = false;
        });
        return;
      }

      // Lấy sales từ SalesService thông qua AuthProvider
      // Tạo SalesService tạm thời để đọc sales (không cần productService để chỉ đọc)
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: null, // Không cần productService để chỉ đọc sales
      );

      // Lấy tất cả đơn hàng và lọc theo customerId
      final allSales = await salesService.getSales();
      final filteredSales = allSales
          .where((sale) => sale.customerId == widget.customer.id)
          .toList();

      // Sắp xếp theo thời gian mới nhất
      filteredSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _salesHistory = filteredSales;
        _isLoadingSales = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSales = false;
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
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final group = customerProvider.getCustomerGroupById(widget.customer.groupId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerFormScreen(customer: widget.customer),
                ),
              );
              // Reload customer data after edit
              await customerProvider.loadCustomers();
            },
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: RefreshIndicator(
          onRefresh: () async {
            await customerProvider.loadCustomers();
            await _loadSalesHistory();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Thông tin cá nhân
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: widget.customer.totalDebt > 0
                                ? Colors.red[100]
                                : Colors.blue[100],
                            child: Text(
                              widget.customer.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: widget.customer.totalDebt > 0
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.customer.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.customer.phone,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.customer.address != null &&
                          widget.customer.address!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.customer.address!,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (group != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.group, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Nhóm: ${group.name}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: group.discountPercent >= 0
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                group.discountPercent >= 0
                                    ? '-${group.discountPercent.toStringAsFixed(1)}%'
                                    : '+${group.discountPercent.abs().toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: group.discountPercent >= 0
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.customer.totalDebt > 0) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.money_off, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Dư nợ: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_formatPrice(widget.customer.totalDebt)} đ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Lịch sử mua hàng
              const Text(
                'Lịch sử mua hàng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingSales)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_salesHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có đơn hàng nào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._salesHistory.map((sale) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: sale.paymentStatus == 'COMPLETED'
                            ? Colors.green[100]
                            : Colors.orange[100],
                        child: Icon(
                          sale.paymentStatus == 'COMPLETED'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: sale.paymentStatus == 'COMPLETED'
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                      title: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${sale.items.length} sản phẩm'),
                          Text(
                            '${sale.paymentMethod == 'CASH' ? 'Tiền mặt' : sale.paymentMethod == 'DEBT' ? 'Nợ' : 'Chuyển khoản'} - ${sale.paymentStatus == 'COMPLETED' ? 'Đã thanh toán' : 'Chờ thanh toán'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${_formatPrice(sale.totalAmount)} đ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.saleDetail,
                          arguments: sale,
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
