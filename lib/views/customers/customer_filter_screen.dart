import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer_group_model.dart';
import 'customer_management_screen_data.dart';

/// Màn hình "Bộ lọc" cho Danh sách khách hàng (mobile) — tham khảo KiotViet.
class CustomerFilterScreen extends StatefulWidget {
  const CustomerFilterScreen({
    super.key,
    this.initialGroupId,
    this.initialGender = 0,
    this.initialBirthDateFrom,
    this.initialBirthDateTo,
    this.initialCreatedAtFrom,
    this.initialCreatedAtTo,
    this.initialTotalSalesFromText = '',
    this.initialTotalSalesToText = '',
    this.initialDebtFromText = '',
    this.initialDebtToText = '',
    this.initialStatus = 1,
    required this.customerGroups,
  });

  final String? initialGroupId;
  final int initialGender;
  final DateTime? initialBirthDateFrom;
  final DateTime? initialBirthDateTo;
  final DateTime? initialCreatedAtFrom;
  final DateTime? initialCreatedAtTo;
  final String initialTotalSalesFromText;
  final String initialTotalSalesToText;
  final String initialDebtFromText;
  final String initialDebtToText;
  final int initialStatus;
  final List<CustomerGroupModel> customerGroups;

  @override
  State<CustomerFilterScreen> createState() => _CustomerFilterScreenState();
}

class _CustomerFilterScreenState extends State<CustomerFilterScreen> {
  late String? _groupId;
  late int _gender;
  late DateTime? _birthDateFrom;
  late DateTime? _birthDateTo;
  late DateTime? _createdAtFrom;
  late DateTime? _createdAtTo;
  late TextEditingController _totalSalesFrom;
  late TextEditingController _totalSalesTo;
  late TextEditingController _debtFrom;
  late TextEditingController _debtTo;
  late int _status;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
    _gender = widget.initialGender;
    _birthDateFrom = widget.initialBirthDateFrom;
    _birthDateTo = widget.initialBirthDateTo;
    _createdAtFrom = widget.initialCreatedAtFrom;
    _createdAtTo = widget.initialCreatedAtTo;
    _totalSalesFrom = TextEditingController(text: widget.initialTotalSalesFromText);
    _totalSalesTo = TextEditingController(text: widget.initialTotalSalesToText);
    _debtFrom = TextEditingController(text: widget.initialDebtFromText);
    _debtTo = TextEditingController(text: widget.initialDebtToText);
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _totalSalesFrom.dispose();
    _totalSalesTo.dispose();
    _debtFrom.dispose();
    _debtTo.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(String field) async {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    if (field == 'birth') {
      start = _birthDateFrom;
      end = _birthDateTo ?? _birthDateFrom;
    } else {
      start = _createdAtFrom;
      end = _createdAtTo ?? _createdAtFrom;
    }
    try {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 10),
        lastDate: now,
        initialDateRange: start != null && end != null
            ? DateTimeRange(start: start, end: end)
            : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
        helpText: 'Chọn khoảng thời gian',
      );
      if (picked != null && mounted) {
        setState(() {
          if (field == 'birth') {
            _birthDateFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
            _birthDateTo = DateTime(picked.end.year, picked.end.month, picked.end.day);
          } else {
            _createdAtFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
            _createdAtTo = DateTime(picked.end.year, picked.end.month, picked.end.day);
          }
        });
      }
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _groupId = null;
      _gender = 0;
      _birthDateFrom = null;
      _birthDateTo = null;
      _createdAtFrom = null;
      _createdAtTo = null;
      _totalSalesFrom.text = '';
      _totalSalesTo.text = '';
      _debtFrom.text = '';
      _debtTo.text = '';
      _status = 1;
    });
  }

  void _apply() {
    Navigator.of(context).pop(CustomerFilterResult(
      groupId: _groupId,
      gender: _gender,
      birthDateFrom: _birthDateFrom,
      birthDateTo: _birthDateTo,
      createdAtFrom: _createdAtFrom,
      createdAtTo: _createdAtTo,
      totalSalesFromText: _totalSalesFrom.text.replaceAll(',', ''),
      totalSalesToText: _totalSalesTo.text.replaceAll(',', ''),
      debtFromText: _debtFrom.text.replaceAll(',', ''),
      debtToText: _debtTo.text.replaceAll(',', ''),
      status: _status,
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
            title: 'Nhóm khách hàng',
            child: DropdownButtonFormField<String?>(
              initialValue: _groupId,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tất cả nhóm')),
                ...widget.customerGroups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Giới tính',
            child: RadioGroup<int>(
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = v ?? 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _radioGender(0, 'Tất cả'),
                  _radioGender(1, 'Nam'),
                  _radioGender(2, 'Nữ'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Sinh nhật',
            child: InkWell(
              onTap: () => _pickDateRange('birth'),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Text(
                  _birthDateFrom != null && _birthDateTo != null
                      ? '${DateFormat('dd/MM/yyyy').format(_birthDateFrom!)} - ${DateFormat('dd/MM/yyyy').format(_birthDateTo!)}'
                      : 'Chọn khoảng thời gian',
                  style: TextStyle(
                    color: _birthDateFrom != null ? null : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Ngày tạo',
            child: InkWell(
              onTap: () => _pickDateRange('created'),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Text(
                  _createdAtFrom != null && _createdAtTo != null
                      ? '${DateFormat('dd/MM/yyyy').format(_createdAtFrom!)} - ${DateFormat('dd/MM/yyyy').format(_createdAtTo!)}'
                      : 'Chọn khoảng thời gian',
                  style: TextStyle(
                    color: _createdAtFrom != null ? null : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Nợ hiện tại',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _debtFrom,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Từ',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _debtTo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Đến',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Tổng bán',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalSalesFrom,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Từ',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _totalSalesTo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Đến',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Trạng thái',
            child: RadioGroup<int>(
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v ?? 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _radioStatus(1, 'Đang hoạt động'),
                  _radioStatus(0, 'Ngừng hoạt động'),
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

  Widget _radioGender(int value, String label) {
    return RadioListTile<int>(
      title: Text(label),
      value: value,
    );
  }

  Widget _radioStatus(int value, String label) {
    return RadioListTile<int>(
      title: Text(label),
      value: value,
    );
  }
}
