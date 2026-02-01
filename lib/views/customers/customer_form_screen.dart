import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/ad_banner_widget.dart';

/// Màn hình form thêm/sửa khách hàng (mobile/desktop theo platform).
class CustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer;
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const CustomerFormScreen({super.key, this.customer, this.forceMobile});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _selectedGroupId = widget.customer?.groupId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomerGroups();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final customerProvider = context.read<CustomerProvider>();
    
    final customer = CustomerModel(
      id: widget.customer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      groupId: _selectedGroupId,
      totalDebt: widget.customer?.totalDebt ?? 0.0,
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = widget.customer == null
        ? await customerProvider.addCustomer(customer)
        : await customerProvider.updateCustomer(customer);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null
                ? 'Đã thêm khách hàng'
                : 'Đã cập nhật khách hàng'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(customerProvider.errorMessage ?? 'Có lỗi xảy ra'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _useMobileLayout;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Thêm khách hàng' : 'Sửa khách hàng'),
      ),
      body: Column(
        children: [
          const AdBannerWidget(),
          Expanded(
            child: ResponsiveContainer(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoCol = !_useMobileLayout;
                        if (twoCol) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildNameField(),
                                    const SizedBox(height: 16),
                                    _buildPhoneField(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildAddressField(),
                                    const SizedBox(height: 16),
                                    _buildGroupDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 16),
                            _buildPhoneField(),
                            const SizedBox(height: 16),
                            _buildAddressField(),
                            const SizedBox(height: 16),
                            _buildGroupDropdown(),
                          ],
                        );
                      },
                    ),
                    if (widget.customer != null && widget.customer!.totalDebt > 0) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.money_off, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dư nợ hiện tại',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[900],
                                      ),
                                    ),
                                    Text(
                                      '${widget.customer!.totalDebt.toStringAsFixed(0)} đ',
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
                          ),
                        ),
                      ),
                    ],
                    if (!isMobile) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveCustomer,
                          child: Text(
                              widget.customer == null ? 'Thêm khách hàng' : 'Cập nhật'),
                        ),
                      ),
                    ],
                    if (isMobile) const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          if (isMobile) _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Tên khách hàng *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập tên khách hàng';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: const InputDecoration(
        labelText: 'Số điện thoại *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.phone),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập số điện thoại';
        }
        return null;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: const InputDecoration(
        labelText: 'Địa chỉ',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      maxLines: 2,
    );
  }

  Widget _buildGroupDropdown() {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        final groups = customerProvider.customerGroups;
        return DropdownButtonFormField<String?>(
          initialValue: _selectedGroupId,
          decoration: const InputDecoration(
            labelText: 'Nhóm khách hàng',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.group),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Không có nhóm'),
            ),
            ...groups.map((group) {
              return DropdownMenuItem<String?>(
                value: group.id,
                child: Text(
                    '${group.name} (${group.discountPercent >= 0 ? "-" : "+"}${group.discountPercent.abs()}%)'),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedGroupId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saveCustomer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                    widget.customer == null ? 'Thêm khách hàng' : 'Cập nhật'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
