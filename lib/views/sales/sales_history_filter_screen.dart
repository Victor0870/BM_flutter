import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/branch_model.dart';
import '../../models/sale_model.dart';
import 'sales_history_screen_data.dart';

/// Màn hình "Bộ lọc" cho Quản lý đơn hàng (mobile) — giao diện lựa chọn theo từng nhóm.
class SalesHistoryFilterScreen extends StatefulWidget {
  const SalesHistoryFilterScreen({
    super.key,
    required this.initialTimeRange,
    this.initialCustomStart,
    this.initialCustomEnd,
    this.initialBranchId,
    this.initialSellerId,
    this.initialStatusValue,
    required this.branches,
    required this.sellers,
  });

  final SalesHistoryTimeRangeKey initialTimeRange;
  final DateTime? initialCustomStart;
  final DateTime? initialCustomEnd;
  final String? initialBranchId;
  final String? initialSellerId;
  final String? initialStatusValue;
  final List<BranchModel> branches;
  final List<({String id, String name})> sellers;

  @override
  State<SalesHistoryFilterScreen> createState() => _SalesHistoryFilterScreenState();
}

class _SalesHistoryFilterScreenState extends State<SalesHistoryFilterScreen> {
  late SalesHistoryTimeRangeKey _timeRange;
  late DateTime? _customStart;
  late DateTime? _customEnd;
  late String? _branchId;
  late String? _sellerId;
  late String? _statusValue;

  @override
  void initState() {
    super.initState();
    _timeRange = widget.initialTimeRange;
    _customStart = widget.initialCustomStart;
    _customEnd = widget.initialCustomEnd;
    _branchId = widget.initialBranchId;
    _sellerId = widget.initialSellerId;
    _statusValue = widget.initialStatusValue;
  }

  String _timeRangeLabel(SalesHistoryTimeRangeKey key) {
    switch (key) {
      case SalesHistoryTimeRangeKey.today:
        return 'Hôm nay';
      case SalesHistoryTimeRangeKey.week:
        return '7 ngày qua';
      case SalesHistoryTimeRangeKey.month:
        return '30 ngày qua';
      case SalesHistoryTimeRangeKey.all:
        return 'Tất cả';
      case SalesHistoryTimeRangeKey.custom:
        if (_customStart != null && _customEnd != null) {
          return '${DateFormat('dd/MM').format(_customStart!)} - ${DateFormat('dd/MM/yyyy').format(_customEnd!)}';
        }
        return 'Tùy chỉnh';
    }
  }

  Future<void> _pickCustomDateRange() async {
    if (!mounted) return;
    final now = DateTime.now();
    try {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _customStart != null && _customEnd != null
            ? DateTimeRange(start: _customStart!, end: _customEnd!)
            : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
        helpText: 'Chọn khoảng thời gian',
      );
      if (picked != null && mounted) {
        setState(() {
          _timeRange = SalesHistoryTimeRangeKey.custom;
          _customStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
          _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
        });
      }
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _timeRange = SalesHistoryTimeRangeKey.week;
      _customStart = null;
      _customEnd = null;
      _branchId = null;
      _sellerId = null;
      _statusValue = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(SalesHistoryFilterResult(
      timeRange: _timeRange,
      customStart: _customStart,
      customEnd: _customEnd,
      branchId: _branchId,
      sellerId: _sellerId,
      statusValue: _statusValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ lọc'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSection(
            title: 'Khoảng thời gian',
            child: RadioGroup<SalesHistoryTimeRangeKey>(
              groupValue: _timeRange,
              onChanged: (v) {
                if (v == SalesHistoryTimeRangeKey.custom) {
                  _pickCustomDateRange();
                } else if (v != null) {
                  setState(() => _timeRange = v);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _radio('Hôm nay', SalesHistoryTimeRangeKey.today),
                  _radio('7 ngày qua', SalesHistoryTimeRangeKey.week),
                  _radio('30 ngày qua', SalesHistoryTimeRangeKey.month),
                  _radio('Tất cả', SalesHistoryTimeRangeKey.all),
                  InkWell(
                    onTap: _pickCustomDateRange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Radio<SalesHistoryTimeRangeKey>(
                            value: SalesHistoryTimeRangeKey.custom,
                          ),
                          const SizedBox(width: 8),
                          Text(_timeRangeLabel(SalesHistoryTimeRangeKey.custom)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Chi nhánh',
            child: DropdownButtonFormField<String?>(
              initialValue: _branchId,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tất cả chi nhánh')),
                ...widget.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
              ],
              onChanged: (v) => setState(() => _branchId = v),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Nhân viên',
            child: DropdownButtonFormField<String?>(
              initialValue: _sellerId,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tất cả nhân viên')),
                ...widget.sellers.map((s) {
                  final id = s.id.isEmpty ? s.name : s.id;
                  return DropdownMenuItem<String?>(value: id, child: Text(s.name));
                }),
              ],
              onChanged: (v) => setState(() => _sellerId = v),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Trạng thái hóa đơn',
            child: RadioGroup<String?>(
              groupValue: _statusValue,
              onChanged: (v) => setState(() => _statusValue = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _radioStatus(null, 'Tất cả trạng thái'),
                  _radioStatus(kOrderStatusProcessing, 'Đang xử lý'),
                  _radioStatus(kOrderStatusDelivered, 'Đã giao'),
                  _radioStatus(kOrderStatusCancelled, 'Đã hủy'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    foregroundColor: const Color(0xFF3B82F6),
                  ),
                  child: const Text('Đặt lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _radio(String label, SalesHistoryTimeRangeKey value) {
    return RadioListTile<SalesHistoryTimeRangeKey>(
      title: Text(label),
      value: value,
    );
  }

  Widget _radioStatus(String? value, String label) {
    return RadioListTile<String?>(
      title: Text(label),
      value: value,
    );
  }
}
