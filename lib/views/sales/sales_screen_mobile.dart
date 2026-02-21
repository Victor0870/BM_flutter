import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/sales_provider.dart';
import '../../l10n/app_localizations.dart';

/// Layout body cho màn hình bán hàng - giao diện Mobile.
/// Nhận các section đã build sẵn từ coordinator.
/// [floatingButtonSection]: nút "Thêm sản phẩm" nổi nằm dưới giỏ, trên bottom bar.
class SalesScreenMobileBody extends StatelessWidget {
  const SalesScreenMobileBody({
    super.key,
    required this.headerSection,
    required this.cartListSection,
    required this.floatingButtonSection,
    required this.bottomBarSection,
  });

  final Widget headerSection;
  final Widget cartListSection;
  final Widget floatingButtonSection;
  final Widget bottomBarSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerSection,
        Expanded(child: cartListSection),
        floatingButtonSection,
        bottomBarSection,
      ],
    );
  }
}

/// Scene phụ thanh toán (mobile): Chi nhánh + Nhân viên, Khách hàng, Khuyến mãi, Thuế, Tổng cộng, nút THANH TOÁN.
class SalesPaymentScene extends StatelessWidget {
  final int tabId;
  final String Function(double) formatPrice;
  final String branchName;
  final String employeeName;
  final VoidCallback onBack;
  final VoidCallback onOpenCustomer;
  final VoidCallback onOpenDiscount;
  final Future<void> Function() onCheckout;

  const SalesPaymentScene({
    super.key,
    required this.tabId,
    required this.formatPrice,
    required this.branchName,
    required this.employeeName,
    required this.onBack,
    required this.onOpenCustomer,
    required this.onOpenDiscount,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: onBack,
          tooltip: AppLocalizations.of(context)!.backTooltip,
        ),
        title: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(LucideIcons.list, size: 20),
          label: Text(
            AppLocalizations.of(context)!.backToList,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chi nhánh + Nhân viên (chuyển từ scene 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade300),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.branchLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      branchName,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      employeeName.isEmpty ? '?' : employeeName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.staffShortLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employeeName,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Consumer<SalesProvider>(
                builder: (context, salesProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onOpenCustomer,
                              icon: const Icon(LucideIcons.user, size: 18),
                              label: Text(AppLocalizations.of(context)!.customer),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onOpenDiscount,
                              icon: const Icon(LucideIcons.tag, size: 18),
                              label: Text(AppLocalizations.of(context)!.promotion),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF97316),
                                side: const BorderSide(color: Color(0xFFF97316)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: _buildTotalsSection(context, salesProvider),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await onCheckout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(AppLocalizations.of(context)!.checkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(BuildContext context, SalesProvider salesProvider) {
    final totals = salesProvider.calculateTotals(tabId);
    final subTotal = totals['subTotal'] ?? 0.0;
    final taxAmount = totals['taxAmount'] ?? 0.0;
    final finalTotal = totals['finalTotal'] ?? 0.0;
    final vatRate = totals['vatRate'] ?? 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.totalAmountLabel, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Text('${formatPrice(subTotal)}đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(vatRate > 0 ? 'Thuế VAT ($vatRate%)' : 'Thuế VAT', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            Text('${formatPrice(taxAmount)}đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppLocalizations.of(context)!.totalToPay,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Text(
              '${formatPrice(finalTotal)}đ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      ],
    );
  }
}
