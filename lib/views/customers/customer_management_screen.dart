import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../widgets/responsive_container.dart';
import '../../core/routes.dart';
import 'customer_form_screen.dart';
import 'customer_detail_screen.dart';

/// Màn hình quản lý khách hàng
class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGroupId; // Filter theo nhóm

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider = context.read<CustomerProvider>();
      customerProvider.loadCustomers();
      customerProvider.loadCustomerGroups();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý khách hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            tooltip: 'Về trang chủ',
          ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.customerGroupManagement);
            },
            tooltip: 'Quản lý nhóm khách hàng',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            // Thanh tìm kiếm và filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<CustomerProvider>(
                builder: (context, customerProvider, child) {
                  final groups = customerProvider.customerGroups;
                  
                  return Column(
                    children: [
                      // Tìm kiếm
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm theo tên hoặc SĐT...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (query) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      // Filter theo nhóm
                      DropdownButtonFormField<String?>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          labelText: 'Lọc theo nhóm',
                          prefixIcon: const Icon(Icons.filter_list),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả nhóm'),
                          ),
                          ...groups.map((group) {
                            return DropdownMenuItem<String?>(
                              value: group.id,
                              child: Text(group.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGroupId = value;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Danh sách khách hàng
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (context, customerProvider, child) {
                  if (customerProvider.isLoading && customerProvider.customers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Lọc danh sách
                  List<CustomerModel> filteredCustomers = customerProvider.customers;

                  // Filter theo search
                  final searchQuery = _searchController.text.trim().toLowerCase();
                  if (searchQuery.isNotEmpty) {
                    filteredCustomers = filteredCustomers.where((customer) {
                      return customer.name.toLowerCase().contains(searchQuery) ||
                          customer.phone.contains(searchQuery);
                    }).toList();
                  }

                  // Filter theo nhóm
                  if (_selectedGroupId != null) {
                    filteredCustomers = filteredCustomers.where((customer) {
                      return customer.groupId == _selectedGroupId;
                    }).toList();
                  }

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isNotEmpty || _selectedGroupId != null
                                ? 'Không tìm thấy khách hàng'
                                : 'Chưa có khách hàng nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhấn nút + để thêm khách hàng mới',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => customerProvider.loadCustomers(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final group = customerProvider.getCustomerGroupById(customer.groupId);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: customer.totalDebt > 0
                                  ? Colors.red[100]
                                  : Colors.blue[100],
                              child: Text(
                                customer.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: customer.totalDebt > 0
                                      ? Colors.red[700]
                                      : Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      customer.phone,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                if (group != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.group, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        group.name,
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ],
                                if (customer.totalDebt > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.money_off, size: 14, color: Colors.red),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Dư nợ: ${_formatPrice(customer.totalDebt)} đ',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CustomerDetailScreen(customer: customer),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CustomerFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
