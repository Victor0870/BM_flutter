import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firebase_service.dart';
import '../../services/local_db_service.dart';
import '../../utils/platform_utils.dart';

/// Màn thiết lập máy in: khổ giấy, tự động in sau thanh toán, cài đặt nội dung in (lời cảm ơn, chính sách đổi trả), tên máy in (Desktop).
/// Dùng từ More → Thiết lập máy in (mobile) hoặc route trực tiếp.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  int _printerPaperSizeMm = 80;
  bool _autoPrintAfterPayment = false;
  final _printerNameController = TextEditingController();
  final _invoiceThankYouController = TextEditingController();
  final _invoiceReturnPolicyController = TextEditingController();
  bool _isSaving = false;

  static const Color _bluePrimary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromShop());
  }

  @override
  void dispose() {
    _printerNameController.dispose();
    _invoiceThankYouController.dispose();
    _invoiceReturnPolicyController.dispose();
    super.dispose();
  }

  void _loadFromShop() {
    final shop = context.read<AuthProvider>().shop;
    if (shop == null) return;
    setState(() {
      _printerPaperSizeMm = shop.printerPaperSizeMm == 58 ? 58 : 80;
      _autoPrintAfterPayment = shop.autoPrintAfterPayment;
      _printerNameController.text = shop.printerName ?? '';
      _invoiceThankYouController.text = shop.invoiceThankYouMessage ?? '';
      _invoiceReturnPolicyController.text = shop.invoiceReturnPolicy ?? '';
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final current = authProvider.shop;
      if (current == null) throw Exception('Chưa đăng nhập.');
      final updated = current.copyWith(
        printerPaperSizeMm: _printerPaperSizeMm,
        autoPrintAfterPayment: _autoPrintAfterPayment,
        printerName: _printerNameController.text.trim().isEmpty
            ? null
            : _printerNameController.text.trim(),
        invoiceThankYouMessage: _invoiceThankYouController.text.trim().isEmpty
            ? null
            : _invoiceThankYouController.text.trim(),
        invoiceReturnPolicy: _invoiceReturnPolicyController.text.trim().isEmpty
            ? null
            : _invoiceReturnPolicyController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await FirebaseService().saveShopData(updated);
      if (!mounted) return;
      await authProvider.updateShop(updated);
      final localDb = LocalDbService();
      await localDb.setPrinterPaperSizeMm(_printerPaperSizeMm);
      await localDb.setAutoPrintAfterPayment(_autoPrintAfterPayment);
      await localDb.setPrinterName(
        _printerNameController.text.trim().isEmpty
            ? null
            : _printerNameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cài đặt máy in'),
          backgroundColor: Colors.green,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.printerConfig,
          style: const TextStyle(
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            const SizedBox(height: 8),
            _buildSectionLabel('Khổ giấy mặc định'),
            const SizedBox(height: 6),
            _buildDropdown(),
            const SizedBox(height: 20),
            _buildSectionLabel('Tự động in sau khi thanh toán'),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _autoPrintAfterPayment,
              onChanged: _isSaving ? null : (v) => setState(() => _autoPrintAfterPayment = v),
              title: const Text(
                'In hóa đơn ngay khi đơn hàng hoàn tất',
                style: TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                _autoPrintAfterPayment
                    ? 'Hệ thống sẽ mở hộp thoại in khi thanh toán xong'
                    : 'Chỉ in khi bạn chọn in từ chi tiết đơn hàng',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _bluePrimary,
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Cài đặt nội dung in'),
            const SizedBox(height: 8),
            Text(
              'Lời cảm ơn (in ở cuối hóa đơn)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _invoiceThankYouController,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Cảm ơn quý khách!',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Chính sách đổi trả (in dưới cùng hóa đơn)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _invoiceReturnPolicyController,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Hàng không đổi trả. Bảo hành theo nhà sản xuất.',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (isDesktopPlatform) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('Tên máy in'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _printerNameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: POS-58',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  prefixIcon: Icon(Icons.print_outlined, size: 22, color: Colors.grey.shade600),
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
              ),
              const SizedBox(height: 8),
              Text(
                'Dùng cho in đúng thiết bị trên máy tính',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 32),
            _buildSaveButton(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<int>(
        value: _printerPaperSizeMm,
        isExpanded: true,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 58, child: Text('Khổ 58mm (K58)')),
          DropdownMenuItem(value: 80, child: Text('Khổ 80mm (K80)')),
        ],
        onChanged: _isSaving ? null : (value) {
          if (value != null) setState(() => _printerPaperSizeMm = value);
        },
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
