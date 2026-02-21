import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/customer_group_model.dart';
import '../../controllers/customer_provider.dart';
import 'customer_management_screen_data.dart';
import 'customer_detail_screen.dart';

const double _kCardRadius = 16;
const double _kShadowBlur = 10;
const double _kShadowOpacity = 0.04;
const double _kSpacing = 16;
const double _kSpacingTight = 12;
const double _kNameSize = 16;
const double _kMetaSize = 12;

/// Màn hình Quản lý khách hàng - giao diện Mobile (thiết kế hiện đại, bộ lọc trong màn "Bộ lọc").
class CustomerManagementScreenMobile extends StatelessWidget {
  const CustomerManagementScreenMobile({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onGroupChanged,
    required this.formatPrice,
    this.onEdit,
  });

  final CustomerManagementSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onGroupChanged;
  final String Function(double) formatPrice;
  final void Function(CustomerModel)? onEdit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildSearchAndFilter(context),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(_kSpacing, 0, _kSpacing, _kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT, mã...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 22),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 20, color: Colors.grey.shade600),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              isDense: true,
            ),
          ),
          const SizedBox(height: _kSpacingTight),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: snapshot.selectedGroupId == null,
                  onTap: () => onGroupChanged(null),
                ),
                const SizedBox(width: 8),
                _GroupChip(
                  groups: snapshot.customerGroups,
                  selectedId: snapshot.selectedGroupId,
                  onSelected: onGroupChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (snapshot.isLoading && snapshot.filteredCustomers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: _kSpacing),
            Text(
              'Không tìm thấy khách hàng',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Thử đổi bộ lọc hoặc nhấn nút + để thêm khách hàng',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, _) {
        return RefreshIndicator(
          onRefresh: () => customerProvider.loadCustomers(),
          color: Theme.of(context).colorScheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(_kSpacing, 0, _kSpacing, _kSpacing),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: snapshot.filteredCustomers.length,
            itemBuilder: (context, index) {
              final customer = snapshot.filteredCustomers[index];
              final group = customerProvider.getCustomerGroupById(customer.groupId);
              return Padding(
                padding: const EdgeInsets.only(bottom: _kSpacingTight),
                child: _CustomerCardMobile(
                  customer: customer,
                  group: group,
                  formatPrice: formatPrice,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerDetailScreen(customer: customer, forceMobile: true),
                      ),
                    );
                  },
                  onEdit: onEdit != null
                      ? () => onEdit!(customer)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.12) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? primary : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final List<CustomerGroupModel> groups;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _GroupChip({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isAll = selectedId == null;
    return PopupMenuButton<String?>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => onSelected(v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tất cả nhóm')),
        ...groups.map((g) => PopupMenuItem(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))),
      ],
      child: Material(
        color: !isAll ? primary.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAll ? 'Theo nhóm' : (groups.where((g) => g.id == selectedId).firstOrNull?.name ?? 'Theo nhóm'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !isAll ? FontWeight.w600 : FontWeight.w500,
                    color: !isAll ? primary : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded, size: 20, color: !isAll ? primary : Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerCardMobile extends StatelessWidget {
  final CustomerModel customer;
  final CustomerGroupModel? group;
  final String Function(double) formatPrice;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _CustomerCardMobile({
    required this.customer,
    required this.group,
    required this.formatPrice,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasDebt = customer.totalDebt > 0;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _kShadowOpacity),
            blurRadius: _kShadowBlur,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(_kSpacingTight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: hasDebt ? Colors.red.shade50 : primary.withValues(alpha: 0.12),
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: hasDebt ? Colors.red.shade700 : primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: _kNameSize,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: TextStyle(fontSize: _kMetaSize, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          group!.name,
                          style: TextStyle(fontSize: _kMetaSize, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasDebt) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dư nợ: ${formatPrice(customer.totalDebt)}',
                          style: TextStyle(
                            fontSize: _kMetaSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ] else if ((customer.totalInvoiced ?? customer.totalRevenue) > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tổng bán: ${formatPrice(customer.totalInvoiced ?? customer.totalRevenue)}',
                          style: TextStyle(
                            fontSize: _kMetaSize,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
              ],
            ),
          ),
        ),
      ),
    );

    if (onEdit != null) {
      final editCb = onEdit!;
      return Slidable(
        key: ValueKey(customer.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.35,
          children: [
            SlidableAction(
              onPressed: (_) => editCb(),
              backgroundColor: primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Sửa',
              borderRadius: BorderRadius.circular(_kCardRadius),
            ),
          ],
        ),
        child: cardContent,
      );
    }
    return cardContent;
  }
}
