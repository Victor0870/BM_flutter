import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../core/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../widgets/change_password_dialog.dart';
import '../../widgets/pro_required_dialog.dart';

/// Màn hình "Nhiều hơn" (More) - hub các chức năng và cài đặt, bố cục tương tự KiotViet More.
/// Dùng cho tab cuối bottom bar mobile.
class MoreScreen extends StatelessWidget {
  final bool? forceMobile;

  const MoreScreen({super.key, this.forceMobile});

  static const String _appVersion = '2.0.6';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildStoreCard(context, l10n),
            const SizedBox(height: 12),
            _buildSection(
              context,
              title: l10n.transactions,
              items: [
                _MenuItem(icon: Icons.point_of_sale, label: l10n.sales, onTap: () => Navigator.pushNamed(context, AppRoutes.sales)),
                _MenuItem(icon: Icons.receipt_long, label: l10n.invoices, onTap: () => Navigator.pushNamed(context, AppRoutes.salesHistory)),
                _MenuItem(icon: Icons.keyboard_return, label: l10n.returns, onTap: () => Navigator.pushNamed(context, AppRoutes.returnInvoice)),
                _MenuItem(icon: Icons.account_balance_wallet, label: l10n.cashBook, onTap: () {}),
              ],
              crossAxisCount: 2,
            ),
            const SizedBox(height: 12),
            _buildSection(
              context,
              title: l10n.goods,
              items: [
                _MenuItem(icon: Icons.inventory_2, label: l10n.productList, onTap: () => Navigator.pushNamed(context, AppRoutes.inventory)),
                _MenuItem(icon: Icons.checklist, label: l10n.inventoryCheck, onTap: () => Navigator.pushNamed(context, AppRoutes.stockOverview)),
                _MenuItem(icon: Icons.add_shopping_cart, label: l10n.goodsReceipt, onTap: () => Navigator.pushNamed(context, AppRoutes.purchase)),
                if (context.watch<AuthProvider>().isPro && context.watch<BranchProvider>().branches.where((b) => b.isActive).length >= 2)
                  _MenuItem(icon: Icons.local_shipping, label: l10n.transferStock, onTap: () => Navigator.pushNamed(context, AppRoutes.transferStock)),
              ],
              crossAxisCount: 2,
            ),
            const SizedBox(height: 12),
            _buildSection(
              context,
              title: l10n.partners,
              items: [
                _MenuItem(icon: Icons.people, label: l10n.customers, onTap: () => Navigator.pushNamed(context, AppRoutes.customerManagement)),
                _MenuItem(icon: Icons.business_center, label: l10n.suppliers, onTap: () => Navigator.pushNamed(context, AppRoutes.suppliers)),
              ],
              crossAxisCount: 2,
            ),
            const SizedBox(height: 12),
            _buildSection(
              context,
              title: l10n.employees,
              items: [
                _MenuItem(
                  icon: Icons.badge,
                  label: l10n.employees,
                  onTap: () {
                    final auth = context.read<AuthProvider>();
                    if (!auth.isPro) {
                      showProRequiredDialog(context, featureName: 'Quản lý nhân viên');
                      return;
                    }
                    Navigator.pushNamed(context, AppRoutes.employeeManagement);
                  },
                ),
              ],
              crossAxisCount: 2,
            ),
            const SizedBox(height: 12),
            _buildSection(
                  context,
                  title: l10n.reports,
                  items: [
                    _MenuItem(icon: Icons.trending_up, label: l10n.salesReport, onTap: () => Navigator.pushNamed(context, AppRoutes.salesReport)),
                    _MenuItem(icon: Icons.savings, label: l10n.profitReport, onTap: () => Navigator.pushNamed(context, AppRoutes.profitReport)),
                  ],
                  crossAxisCount: 2,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  context,
                  title: l10n.taxAndAccounting,
                  items: [
                    _MenuItem(icon: Icons.receipt, label: l10n.eInvoice, onTap: () => Navigator.pushNamed(context, AppRoutes.einvoiceSettings)),
                  ],
                  crossAxisCount: 1,
                ),
                const SizedBox(height: 12),
                _buildGeneralSettingsSection(context, l10n),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${l10n.version}: $_appVersion',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, AppLocalizations l10n) {
    final auth = context.watch<AuthProvider>();
    final branchProvider = context.watch<BranchProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final currentId = branchProvider.currentBranchId;
    final displayName = auth.userProfile?.displayName ?? auth.user?.email?.split('@').first ?? '';
    final isStaffWithFixedBranch = auth.userProfile != null &&
        auth.userProfile!.isStaff &&
        (auth.userProfile!.workingBranchId != null && auth.userProfile!.workingBranchId!.isNotEmpty);
    final effectiveBranchId = isStaffWithFixedBranch ? auth.userProfile!.workingBranchId! : currentId;
    final branchName = _getBranchDisplayName(context, branches, effectiveBranchId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    if ((auth.user?.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        auth.user!.email!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(l10n.branchLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    if (isStaffWithFixedBranch)
                      Row(
                        children: [
                          Text(branchName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                          const SizedBox(width: 4),
                          Icon(Icons.store, size: 16, color: Colors.grey[600]),
                        ],
                      )
                    else
                      InkWell(
                        onTap: () => _showBranchPicker(context, branchProvider, branches),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(branchName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
                              ),
                              Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey[600]),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.accountPackage),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 10),
                  Text(l10n.accountInfo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => showChangePasswordDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.lock_reset, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 10),
                  const Text('Đổi mật khẩu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getBranchDisplayName(BuildContext context, List<BranchModel> branches, String? branchId) {
    if (branchId == null || branchId.isEmpty) {
      return AppLocalizations.of(context)!.mainBranch;
    }
    if (branchId == kMainStoreBranchId) {
      return AppLocalizations.of(context)!.mainBranch;
    }
    try {
      final b = branches.firstWhere((e) => e.id == branchId);
      return b.name;
    } catch (_) {
      return AppLocalizations.of(context)!.mainBranch;
    }
  }

  static Future<void> _showBranchPicker(
    BuildContext context,
    BranchProvider branchProvider,
    List<BranchModel> branches,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentId = branchProvider.currentBranchId;
    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.chooseBranch, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (branches.isEmpty)
                  ListTile(
                    leading: Icon(Icons.store, color: Theme.of(ctx).colorScheme.primary),
                    title: Text(l10n.mainBranch),
                    onTap: () {
                      branchProvider.setSelectedBranch(kMainStoreBranchId);
                      Navigator.pop(ctx);
                    },
                  )
                else
                  ...branches.map((b) {
                    final name = b.id == kMainStoreBranchId ? l10n.mainBranch : b.name;
                    final isSelected = currentId == b.id;
                    return ListTile(
                      leading: Icon(isSelected ? Icons.check_circle : Icons.store_outlined, color: isSelected ? Theme.of(ctx).colorScheme.primary : null),
                      title: Text(name),
                      onTap: () {
                        branchProvider.setSelectedBranch(b.id);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_MenuItem> items,
    required int crossAxisCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (crossAxisCount == 1) {
                return Column(
                  children: items.map((e) => _buildListTile(context, e)).toList(),
                );
              }
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: items.map((e) => _buildGridTile(context, e)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridTile(BuildContext context, _MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 20, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsSection(BuildContext context, AppLocalizations l10n) {
    final auth = context.read<AuthProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.generalSettings.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildListTile(context, _MenuItem(icon: Icons.settings, label: l10n.storeSetup, onTap: () => Navigator.pushNamed(context, AppRoutes.storeSetup))),
          _buildListTile(context, _MenuItem(icon: Icons.print_outlined, label: l10n.printerConfig, onTap: () => Navigator.pushNamed(context, AppRoutes.printerSettings))),
          _buildListTile(context, _MenuItem(icon: Icons.language, label: l10n.language, onTap: () => Navigator.pushNamed(context, AppRoutes.languageSettings))),
          _buildListTile(context, _MenuItem(icon: Icons.feedback_outlined, label: 'Góp ý cho phần mềm', onTap: () => Navigator.pushNamed(context, AppRoutes.feedback))),
          _buildListTile(context, _MenuItem(icon: Icons.help_outline, label: l10n.userGuide, onTap: () {})),
          _buildListTile(
            context,
            _MenuItem(
              icon: Icons.logout,
              label: l10n.logout,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.logout),
                    content: const Text('Bạn có chắc muốn đăng xuất?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await auth.signOut();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.label, required this.onTap});
}
