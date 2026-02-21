import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import 'admin_auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _userCountByShop = {};
  bool _userCountLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shop.id).update({
        'packageType': 'PRO',
        'licenseEndDate': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã nâng cấp "${shop.name}" lên PRO'), backgroundColor: Colors.green),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BizMate Admin'),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm theo ID shop (nội dung CK)',
                hintText: 'Dán ID shop vào đây',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
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

                if (filtered.isEmpty) {
                  return const Center(child: Text('Không có shop nào.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('ID (Shop)', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Tên', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Gói', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Tạo lúc', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Hết hạn', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('HĐ', style: TextStyle(fontWeight: FontWeight.w600))),
                        DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                      rows: filtered.map((shop) {
                        final userCount = _userCountLoaded ? (_userCountByShop[shop.id] ?? 0) : null;
                        return DataRow(
                          cells: [
                            DataCell(SelectableText(shop.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                            DataCell(Text(shop.name)),
                            DataCell(
                              Chip(
                                label: Text(shop.packageType, style: const TextStyle(fontSize: 12)),
                                backgroundColor: shop.packageType == 'PRO' ? Colors.green.shade100 : Colors.orange.shade100,
                              ),
                            ),
                            DataCell(Text(_formatDate(shop.createdAt))),
                            DataCell(Text(_formatDate(shop.licenseEndDate))),
                            DataCell(Text(_userCountLoaded ? userCount.toString() : '—')),
                            const DataCell(Text('—')),
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
      ),
    );
  }
}
