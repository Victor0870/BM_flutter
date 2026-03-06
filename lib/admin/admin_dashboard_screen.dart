import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/shop_model.dart';
import '../models/feedback_model.dart';
import '../services/feedback_service.dart';
import 'admin_auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum _AdminSortBy { nameAsc, nameDesc, salesDesc, salesAsc }

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _shopIdController = TextEditingController();
  Map<String, int> _userCountByShop = {};
  bool _userCountLoaded = false;
  _AdminSortBy _sortBy = _AdminSortBy.nameAsc;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _shopIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCounts() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, int> counts = {};
      for (final doc in snap.docs) {
        final shopId = doc.data()['shopId'] as String?;
        if (shopId != null) counts[shopId] = (counts[shopId] ?? 0) + 1;
      }
      if (mounted) {
        setState(() {
          _userCountByShop = counts;
          _userCountLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userCountLoaded = true);
    }
  }

  Future<void> _upgradeToPro(ShopModel shop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nâng cấp lên PRO'),
        content: Text(
          'Xác nhận nâng cấp shop "${shop.name}" (${shop.id}) lên gói PRO?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nâng cấp')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _applyUpgradeToPro(shop.id, shop.name);
  }

  Future<void> _applyUpgradeToPro(String shopId, String? displayName) async {
    try {
      final ref = FirebaseFirestore.instance.collection('shops').doc(shopId);
      final doc = await ref.get();
      if (doc.exists && doc.data() != null) {
        await ref.update({
          'packageType': 'PRO',
          'licenseEndDate': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          final name = displayName ?? (doc.data()!['name'] as String?) ?? shopId;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã nâng cấp "$name" lên PRO'), backgroundColor: Colors.green),
          );
        }
      } else {
        final now = FieldValue.serverTimestamp();
        await ref.set({
          'name': 'Shop $shopId',
          'packageType': 'PRO',
          'licenseEndDate': null,
          'isActive': true,
          'totalSalesCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo shop $shopId với gói PRO. Chủ shop đăng nhập app sẽ thấy PRO.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  List<ShopModel> _sortedShops(List<ShopModel> list) {
    final sorted = List<ShopModel>.from(list);
    switch (_sortBy) {
      case _AdminSortBy.nameAsc:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _AdminSortBy.nameDesc:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _AdminSortBy.salesDesc:
        sorted.sort((a, b) => b.totalSalesCount.compareTo(a.totalSalesCount));
        break;
      case _AdminSortBy.salesAsc:
        sorted.sort((a, b) => a.totalSalesCount.compareTo(b.totalSalesCount));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BizMate Admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Shops', icon: Icon(Icons.store)),
            Tab(
              child: StreamBuilder<int>(
                stream: FeedbackService.streamUnrespondedCount(),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Góp ý'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Badge(
                          label: Text('$count'),
                          child: const Icon(Icons.feedback_outlined, size: 20),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUserCounts(),
            tooltip: 'Tải lại số user',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AdminAuthProvider>().signOut(),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShopsTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  Widget _buildShopsTab() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Tìm theo tên hoặc ID shop',
                      hintText: 'Nhập tên shop hoặc ID',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<_AdminSortBy>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sắp xếp',
                  onSelected: (v) => setState(() => _sortBy = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: _AdminSortBy.nameAsc, child: Text('Tên shop A → Z')),
                    const PopupMenuItem(value: _AdminSortBy.nameDesc, child: Text('Tên shop Z → A')),
                    const PopupMenuItem(value: _AdminSortBy.salesDesc, child: Text('Số HĐ giảm dần (hoạt động nhiều trước)')),
                    const PopupMenuItem(value: _AdminSortBy.salesAsc, child: Text('Số HĐ tăng dần')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('shops').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                final shops = docs.map((d) => ShopModel.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList();
                final query = _searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? shops
                    : shops.where((s) => s.id.toLowerCase().contains(query) || s.name.toLowerCase().contains(query)).toList();
                final sorted = _sortedShops(filtered);

                if (sorted.isEmpty) {
                  return const Center(child: Text('Không có shop nào.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Tên shop', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('ID (Shop)', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Gói', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Tạo lúc', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Hết hạn', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Số HĐ', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                      rows: sorted.map((shop) {
                        final userCount = _userCountLoaded ? (_userCountByShop[shop.id] ?? 0) : null;
                        return DataRow(
                          cells: [
                            DataCell(Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(SelectableText(shop.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            DataCell(
                              Chip(
                                label: Text(shop.packageType, style: const TextStyle(fontSize: 12)),
                                backgroundColor: shop.packageType == 'PRO' ? Colors.green.shade100 : Colors.orange.shade100,
                              ),
                            ),
                            DataCell(Text(_formatDate(shop.createdAt))),
                            DataCell(Text(_formatDate(shop.licenseEndDate))),
                            DataCell(Text(_userCountLoaded ? userCount.toString() : '—')),
                            DataCell(
                              Text(
                                '${shop.totalSalesCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: shop.totalSalesCount > 0 ? Colors.green.shade700 : null,
                                ),
                              ),
                            ),
                            DataCell(
                              shop.packageType == 'PRO'
                                  ? const Text('PRO', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500))
                                  : ElevatedButton(
                                      onPressed: () => _upgradeToPro(shop),
                                      child: const Text('Nâng PRO'),
                                    ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
  }

  Widget _buildFeedbackTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FeedbackService.streamForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final list = docs
            .map((d) => FeedbackModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (list.isEmpty) {
          return const Center(
            child: Text('Chưa có góp ý nào.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final f = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: f.isResponded
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    f.isResponded ? Icons.check_circle : Icons.feedback_outlined,
                    color: f.isResponded
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                title: Text(
                  f.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        f.isResponded ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'ShopId: ${f.shopId} • ${DateFormat('dd/MM/yyyy HH:mm').format(f.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (f.isResponded && f.response != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Phản hồi: ${f.response}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                isThreeLine: true,
                trailing: f.isResponded
                    ? const Icon(Icons.done_all, color: Colors.green)
                    : TextButton.icon(
                        onPressed: () => _showRespondDialog(context, f),
                        icon: const Icon(Icons.reply, size: 18),
                        label: const Text('Phản hồi'),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRespondDialog(BuildContext context, FeedbackModel feedback) {
    final controller = TextEditingController(text: feedback.response);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Phản hồi góp ý'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      feedback.content,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung phản hồi',
                    hintText: 'Nhập phản hồi cho người góp ý...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập nội dung phản hồi.')),
                  );
                  return;
                }
                try {
                  await FeedbackService.respondToFeedback(
                    feedbackId: feedback.id,
                    responseText: text,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã phản hồi và gửi thông báo cho người góp ý.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Gửi phản hồi'),
            ),
          ],
        );
      },
    );
  }
}
