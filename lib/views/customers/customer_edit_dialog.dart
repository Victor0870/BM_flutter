import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/customer_provider.dart';
import '../../models/customer_model.dart';

/// Popup chỉnh sửa khách hàng (desktop): bố cục theo ảnh minh họa.
class CustomerEditDialog extends StatefulWidget {
  final CustomerModel customer;

  const CustomerEditDialog({super.key, required this.customer});

  /// Hiển thị dialog; trả về [CustomerModel] đã cập nhật nếu user bấm Lưu, null nếu Bỏ qua/đóng.
  static Future<CustomerModel?> show(BuildContext context, CustomerModel customer) {
    return showDialog<CustomerModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerEditDialog(customer: customer),
    );
  }

  @override
  State<CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<CustomerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _emailController;
  late TextEditingController _facebookController;
  late TextEditingController _addressController;
  late TextEditingController _locationController;
  late TextEditingController _wardController;
  late TextEditingController _notesController;
  late TextEditingController _invoiceBuyerNameController;
  late TextEditingController _invoiceTaxCodeController;
  late TextEditingController _invoiceAddressController;
  late TextEditingController _invoiceLocationController;
  late TextEditingController _invoiceWardController;
  late TextEditingController _invoiceIdCardController;
  late TextEditingController _invoicePassportController;
  late TextEditingController _invoiceEmailController;
  late TextEditingController _invoicePhoneController;
  late TextEditingController _invoiceBankAccountController;

  String? _selectedGroupId;
  bool _invoiceTypeIndividual = true; // true = Cá nhân
  String? _selectedBank; // Chọn ngân hàng
  DateTime? _birthDate;
  bool? _gender; // true = Nam, false = Nữ

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c.name);
    _codeController = TextEditingController(text: c.code ?? '');
    _phone1Controller = TextEditingController(text: c.phone);
    _phone2Controller = TextEditingController(text: '');
    _emailController = TextEditingController(text: c.email ?? '');
    _facebookController = TextEditingController(text: '');
    _addressController = TextEditingController(text: c.address ?? '');
    _locationController = TextEditingController(text: c.locationName ?? '');
    _wardController = TextEditingController(text: c.wardName ?? '');
    _notesController = TextEditingController(text: c.comments ?? '');
    _invoiceBuyerNameController = TextEditingController(text: '');
    _invoiceTaxCodeController = TextEditingController(text: c.taxCode ?? '');
    _invoiceAddressController = TextEditingController(text: c.address ?? '');
    _invoiceLocationController = TextEditingController(text: c.locationName ?? '');
    _invoiceWardController = TextEditingController(text: c.wardName ?? '');
    _invoiceIdCardController = TextEditingController(text: '');
    _invoicePassportController = TextEditingController(text: '');
    _invoiceEmailController = TextEditingController(text: c.email ?? '');
    _invoicePhoneController = TextEditingController(text: c.phone);
    _invoiceBankAccountController = TextEditingController(text: '');
    _selectedGroupId = c.groupId;
    _birthDate = c.birthDate;
    _gender = c.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _emailController.dispose();
    _facebookController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _wardController.dispose();
    _notesController.dispose();
    _invoiceBuyerNameController.dispose();
    _invoiceTaxCodeController.dispose();
    _invoiceAddressController.dispose();
    _invoiceLocationController.dispose();
    _invoiceWardController.dispose();
    _invoiceIdCardController.dispose();
    _invoicePassportController.dispose();
    _invoiceEmailController.dispose();
    _invoicePhoneController.dispose();
    _invoiceBankAccountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final c = widget.customer;
    final updated = c.copyWith(
      name: _nameController.text.trim(),
      code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      phone: _phone1Controller.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      locationName: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      wardName: _wardController.text.trim().isEmpty ? null : _wardController.text.trim(),
      groupId: _selectedGroupId,
      comments: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      taxCode: _invoiceTaxCodeController.text.trim().isEmpty ? null : _invoiceTaxCodeController.text.trim(),
      birthDate: _birthDate,
      gender: _gender,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      updatedAt: DateTime.now(),
    );
    final provider = context.read<CustomerProvider>();
    final success = await provider.updateCustomer(updated);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật khách hàng'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Có lỗi xảy ra'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoSection(),
                      const SizedBox(height: 12),
                      _buildAddressSection(),
                      const SizedBox(height: 12),
                      _buildGroupNotesSection(),
                      const SizedBox(height: 12),
                      _buildInvoiceSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        children: [
          const Text(
            'Sửa khách hàng',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Đóng',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _input('Tên khách hàng', _nameController, required: true),
                  const SizedBox(height: 12),
                  _input('Mã khách hàng', _codeController),
                  const SizedBox(height: 12),
                  _input('Điện thoại 1', _phone1Controller, keyboardType: TextInputType.phone, required: true),
                  const SizedBox(height: 12),
                  _input('Điện thoại 2', _phone2Controller, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildBirthDateField(),
                  const SizedBox(height: 12),
                  _buildGenderDropdown(),
                  const SizedBox(height: 12),
                  _input('Email', _emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _input('Facebook', _facebookController),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _buildAddPhotoArea(),
          ],
        ),
      ],
    );
  }

  Widget _input(String label, TextEditingController controller, {String? hint, bool required = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Bắt buộc';
              return null;
            }
          : null,
    );
  }

  Widget _buildBirthDateField() {
    final text = _birthDate != null ? DateFormat('dd/MM/yyyy').format(_birthDate!) : '--/--/----';
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _birthDate ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _birthDate = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Sinh nhật',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today, size: 20),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    const options = ['Chọn giới tính', 'Nam', 'Nữ'];
    final value = _gender == null ? 0 : (_gender! ? 1 : 2);
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Giới tính',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: List.generate(3, (i) => DropdownMenuItem(value: i, child: Text(options[i]))),
      onChanged: (v) => setState(() => _gender = v == 1 ? true : (v == 2 ? false : null)),
    );
  }

  Widget _buildAddPhotoArea() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: TextButton(
            onPressed: () {},
            child: const Text('Thêm ảnh', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ảnh không được vượt quá 2MB',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Địa chỉ', style: TextStyle(fontWeight: FontWeight.w600)),
      children: [
        _input('Địa chỉ', _addressController, hint: 'Nhập địa chỉ'),
        const SizedBox(height: 12),
        _input('Tỉnh/Thành phố', _locationController, hint: 'Chọn Tỉnh/Thành phố'),
        const SizedBox(height: 12),
        _input('Phường/Xã', _wardController, hint: 'Chọn Phường/Xã'),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildGroupNotesSection() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        final groups = provider.customerGroups;
        return ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Nhóm khách hàng, ghi chú', style: TextStyle(fontWeight: FontWeight.w600)),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _selectedGroupId,
              decoration: const InputDecoration(
                labelText: 'Nhóm khách hàng',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Không chọn')),
                ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text('${g.name} (${g.discountPercent >= 0 ? "-" : "+"}${g.discountPercent.abs()}%)'))),
              ],
              onChanged: (v) => setState(() => _selectedGroupId = v),
            ),
            const SizedBox(height: 12),
            _input('Ghi chú', _notesController, hint: 'Nhập ghi chú'),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceSection() {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Thông tin xuất hóa đơn', style: TextStyle(fontWeight: FontWeight.w600)),
      children: [
        RadioGroup<bool>(
          groupValue: _invoiceTypeIndividual,
          onChanged: (v) {
            if (v != null) setState(() => _invoiceTypeIndividual = v);
          },
          child: Row(
            children: [
              Radio<bool>(value: true),
              const Text('Cá nhân'),
              const SizedBox(width: 24),
              Radio<bool>(value: false),
              const Text('Tổ chức/ Hộ kinh doanh'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _input('Tên người mua', _invoiceBuyerNameController, hint: 'Nhập tên người mua'),
        const SizedBox(height: 12),
        _input('Mã số thuế', _invoiceTaxCodeController, hint: 'Nhập mã số thuế'),
        const SizedBox(height: 12),
        _input('Địa chỉ', _invoiceAddressController, hint: 'Nhập địa chỉ'),
        const SizedBox(height: 12),
        _input('Tỉnh/Thành phố', _invoiceLocationController, hint: 'Tìm Tỉnh/Thành phố'),
        const SizedBox(height: 12),
        _input('Phường/Xã', _invoiceWardController, hint: 'Tìm Phường/Xã'),
        const SizedBox(height: 12),
        _input('Số CCCD/CMND', _invoiceIdCardController, hint: 'Nhập số CCCD/CMND'),
        const SizedBox(height: 12),
        _input('Số hộ chiếu', _invoicePassportController, hint: 'Nhập số hộ chiếu'),
        const SizedBox(height: 12),
        _input('Email', _invoiceEmailController, hint: 'email@gmail.com'),
        const SizedBox(height: 12),
        _input('Số điện thoại', _invoicePhoneController, hint: 'Nhập số điện thoại', keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _selectedBank,
          decoration: const InputDecoration(
            labelText: 'Ngân hàng',
            hintText: 'Chọn ngân hàng',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Chọn ngân hàng')),
            const DropdownMenuItem(value: 'VCB', child: Text('Vietcombank')),
            const DropdownMenuItem(value: 'BIDV', child: Text('BIDV')),
            const DropdownMenuItem(value: 'CTG', child: Text('VietinBank')),
            const DropdownMenuItem(value: 'TCB', child: Text('Techcombank')),
          ],
          onChanged: (v) => setState(() => _selectedBank = v),
        ),
        const SizedBox(height: 12),
        _input('Số tài khoản ngân hàng', _invoiceBankAccountController, hint: 'Nhập số tài khoản ngân hàng'),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Bỏ qua'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
