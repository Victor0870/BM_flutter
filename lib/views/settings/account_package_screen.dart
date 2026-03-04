import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dio/dio.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/shop_model.dart';

/// Màn hình mobile: Tài khoản & Gói dịch vụ.
/// Hiển thị thông tin shop, gói đang dùng và danh sách gói để nâng cấp/gia hạn.
class AccountPackageScreen extends StatelessWidget {
  const AccountPackageScreen({super.key});

  static const String _title = 'Tài khoản & Gói dịch vụ';
  static const String _expiryLabel = 'Ngày hết hạn';
  static const String _buyMoreBranches = 'Mua thêm chi nhánh/ kho';
  static const String _viewMore = '↓ Xem thêm';
  static const String _buyNow = 'Mua ngay';
  static const String _renew = 'Gia hạn';
  static const String _inDevelopment = 'Đang phát triển';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<AuthProvider, BranchProvider>(
        builder: (context, authProvider, branchProvider, _) {
          final shop = authProvider.shop;
          if (shop == null) {
            return const Center(child: Text('Không có thông tin cửa hàng'));
          }
          final branchCount = branchProvider.branchCount;
          final packageLabel = _packageDisplayName(shop.packageType);
          final expiryStr = shop.licenseEndDate != null
              ? _formatDate(shop.licenseEndDate!)
              : '—';

          final accountEmail = authProvider.user?.email ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildShopInfo(context, shop, branchCount, accountEmail),
                const SizedBox(height: 20),
                _buildActivePackageCard(
                  context,
                  packageLabel: packageLabel,
                  expiryStr: expiryStr,
                ),
                const SizedBox(height: 24),
                _buildPackageList(context, shop),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopInfo(
    BuildContext context,
    ShopModel shop,
    int branchCount,
    String accountEmail,
  ) {
    final theme = Theme.of(context);
    final categoryLabel = 'Thời trang'; // Có thể lấy từ shop nếu có field
    final branchText =
        branchCount > 0 ? '+$branchCount Chi nhánh' : 'Chưa có chi nhánh';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.store_rounded,
              size: 28,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoryLabel / $branchText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (accountEmail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          accountEmail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePackageCard(
    BuildContext context, {
    required String packageLabel,
    required String expiryStr,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  packageLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_expiryLabel: $expiryStr',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Liên hệ Admin để mua thêm chi nhánh/kho'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text(_buyMoreBranches),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _featuresBasic = [
    'Bán hàng & in hóa đơn',
    'Quản lý kho',
    'Quản lý sản phẩm',
    'Quản lý nhà cung cấp',
    'Quản lý khách hàng',
    'Liên kết đơn vị vận chuyển',
    'Báo cáo doanh thu',
    'Xuất hóa đơn điện tử',
  ];

  static const List<String> _featuresPro = [
    'Tất cả tính năng Cơ bản',
    'Quản lý nhân viên (tối đa 15)',
    'Nhập danh sách sản phẩm từ Excel',
    'Hỗ trợ đa nền tảng Android và PC',
    'Hỗ trợ lấy hóa đơn đầu vào',
    'Hỗ trợ kê khai thuế',
  ];

  static const List<String> _featuresPremium = [
    'Tất cả tính năng Chuyên nghiệp',
    'Không giới hạn số lượng nhân viên',
    'Kết nối với các sàn thương mại điện tử',
    'Kế toán mini',
  ];

  Widget _buildPackageList(BuildContext context, ShopModel currentShop) {
    final isPro = currentShop.packageType == 'PRO';
    final packages = [
      _PackageItem(
        id: 'support',
        name: 'Cơ bản',
        description:
            'Dành cho mô hình kinh doanh nhỏ, người bắt đầu kinh doanh hoặc bán hàng online.',
        price: '0Đ',
        color: Colors.green,
        actionLabel: null, // Cơ bản là gói mặc định, không hiển thị nút mua
        isCurrent: currentShop.packageType == 'BASIC',
        features: _featuresBasic,
      ),
      _PackageItem(
        id: 'professional',
        name: 'Chuyên nghiệp',
        description:
            'Dành cho mô hình kinh doanh chuyên nghiệp, chuyên môn hóa quy trình.',
        price: '1,000,000 VND',
        color: Colors.blue,
        actionLabel: isPro ? _renew : _buyNow,
        isCurrent: isPro,
        features: _featuresPro,
      ),
      _PackageItem(
        id: 'premium',
        name: 'Cao cấp',
        description:
            'Dành cho mô hình kinh doanh lớn, nhiều kênh bán & cần dịch vụ cao cấp.',
        price: 'Liên hệ',
        color: Colors.orange,
        actionLabel: _inDevelopment,
        isCurrent: false,
        features: _featuresPremium,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: packages.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PackageCard(
            item: p,
            onViewMore: () {},
            onAction: p.id == 'professional'
                ? () => AccountPackageScreen.showProUpgradeDialog(context, currentShop.id)
                : () {},
          ),
        );
      }).toList(),
    );
  }

  static String _packageDisplayName(String packageType) {
    switch (packageType.toUpperCase()) {
      case 'PRO':
        return 'Chuyên nghiệp';
      case 'BASIC':
        return 'Cơ bản';
      default:
        return packageType;
    }
  }

  static String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    return '$day/$month/$year';
  }

  /// Popup xác nhận nâng cấp/gia hạn gói Pro: câu hỏi + ô mã KM + nút Xác nhận.
  static Future<void> showProUpgradeDialog(BuildContext context, String shopId) async {
    final promoController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nâng cấp / Gia hạn gói Pro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn có muốn nâng cấp/gia hạn gói Pro không?',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: promoController,
                  decoration: const InputDecoration(
                    labelText: 'Mã khuyến mãi',
                    hintText: 'Để trống nếu không có',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
    if (context.mounted && confirmed == true) {
      final promo = promoController.text.trim().isEmpty ? 'KKM' : promoController.text.trim();
      promoController.dispose();
      showProPaymentDialog(context, shopId, promo);
    } else {
      promoController.dispose();
    }
  }

  /// Dialog thanh toán: thông tin chuyển khoản Vietcombank + QR.
  static void showProPaymentDialog(BuildContext context, String shopId, String promoCode) {
    const bankName = 'Vietcombank';
    const accountNumber = '0031001002107';
    const accountHolderName = 'Phạm Tiến Thắng';
    const amount = 1000000; // 1,000,000 VNĐ
    final transferContent = '$shopId-Pro-$promoCode';

    showDialog(
      context: context,
      builder: (ctx) {
        final vietQrUrl = 'https://img.vietqr.io/image/970436/$accountNumber/compact.jpg?amount=$amount&addInfo=${Uri.encodeComponent(transferContent)}';
        final amountStr = '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ';
        return AlertDialog(
          title: const Text('Thanh toán gói Pro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chuyển khoản theo thông tin sau:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _paymentRow('Ngân hàng', bankName),
                _paymentRowWithCopy(ctx, 'Chủ tài khoản', accountHolderName),
                _paymentRowWithCopy(ctx, 'Số tài khoản', accountNumber),
                _paymentRow('Số tiền', amountStr),
                _paymentRowWithCopy(ctx, 'Nội dung CK', transferContent),
                const SizedBox(height: 16),
                const Center(child: Text('Quét mã QR để chuyển khoản', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                const SizedBox(height: 8),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      vietQrUrl,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => QrImageView(
                        data: transferContent,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _saveQrImageToGallery(ctx, vietQrUrl),
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Tải ảnh QR về máy'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _saveQrImageToGallery(BuildContext context, String imageUrl) async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) throw Exception('Không tải được ảnh');
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data!),
        quality: 100,
        name: 'bizmate_qr_thanhtoan',
      );
      if (context.mounted) {
        final ok = result['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Đã lưu ảnh QR vào thư viện' : 'Không lưu được ảnh'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Widget _paymentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  static Widget _paymentRowWithCopy(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: SelectableText(value)),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã copy'), duration: Duration(seconds: 1)),
              );
            },
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

class _PackageItem {
  final String id;
  final String name;
  final String description;
  final String price;
  final Color color;
  /// null = không hiển thị nút (gói Cơ bản)
  final String? actionLabel;
  final bool isCurrent;
  final List<String> features;

  _PackageItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.color,
    required this.actionLabel,
    required this.isCurrent,
    required this.features,
  });
}

class _PackageCard extends StatefulWidget {
  final _PackageItem item;
  final VoidCallback onViewMore;
  final VoidCallback onAction;

  const _PackageCard({
    required this.item,
    required this.onViewMore,
    required this.onAction,
  });

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.price,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tính năng:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...item.features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: item.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    widget.onViewMore();
                  },
                  icon: Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(_expanded ? '↑ Thu gọn' : AccountPackageScreen._viewMore),
                ),
                if (item.actionLabel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: item.id == 'premium' ? null : widget.onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: item.color,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(item.actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
