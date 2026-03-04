import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../l10n/app_localizations.dart';

/// Màn thiết lập thông tin cửa hàng (tên, SĐT, địa chỉ, email, website, MST).
/// Giao diện theo kiểu "Cửa hàng của tôi": profile avatar, form sạch, nút Lưu thay đổi.
class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxCodeController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShop());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxCodeController.dispose();
    super.dispose();
  }

  void _loadShop() {
    final authProvider = context.read<AuthProvider>();
    final shop = authProvider.shop;
    if (shop == null) return;
    setState(() {
      _nameController.text = shop.name;
      _phoneController.text = shop.phone ?? '';
      _addressController.text = shop.address ?? '';
      _emailController.text = shop.email ?? '';
      _websiteController.text = shop.website ?? '';
      _taxCodeController.text = shop.taxCode ?? '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final current = authProvider.shop;
      if (current == null) throw Exception('Chưa đăng nhập.');
      final updated = current.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        taxCode: _taxCodeController.text.trim().isEmpty
            ? null
            : _taxCodeController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await FirebaseService().saveShopData(updated);
      if (!mounted) return;
      await authProvider.updateShop(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu thông tin cửa hàng'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _shopInitials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'SH';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  static const Color _bluePrimary = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFFEFF6FF);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Cửa hàng của tôi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _blueLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _shopInitials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _bluePrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              const SizedBox(height: 8),
              _buildProfileSection(),
              const SizedBox(height: 28),
              _buildLabel(l10n.shopName),
              const SizedBox(height: 6),
              _buildField(
                controller: _nameController,
                hint: 'Bizmate',
                icon: Icons.store_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.pleaseEnterShopName : null,
              ),
              const SizedBox(height: 18),
              _buildLabel(l10n.phone),
              const SizedBox(height: 6),
              _buildField(
                controller: _phoneController,
                hint: '0799068571',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              _buildLabel(l10n.address),
              const SizedBox(height: 6),
              _buildField(
                controller: _addressController,
                hint: 'Vinhomes Marina',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              _buildLabel('Email liên hệ'),
              const SizedBox(height: 6),
              _buildField(
                controller: _emailController,
                hint: 'email@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _buildLabel('Trang web (nếu có)'),
              const SizedBox(height: 6),
              _buildField(
                controller: _websiteController,
                hint: 'https://...',
                icon: Icons.language_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 18),
              _buildLabel(l10n.taxCode),
              const SizedBox(height: 6),
              _buildField(
                controller: _taxCodeController,
                hint: '0200638946',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 32),
              _buildSaveButton(l10n),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF2563EB),
                    Color(0xFF1D4ED8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _bluePrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: _bluePrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _nameController.text.trim().isEmpty ? 'Cửa hàng' : _nameController.text.trim(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              'Tài khoản doanh nghiệp',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, size: 22, color: Colors.grey.shade600),
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
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined, size: 22),
        label: Text(
          _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _bluePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
