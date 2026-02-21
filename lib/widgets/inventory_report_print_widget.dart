import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_report_model.dart';

/// Chiều rộng nội dung in báo cáo (A4 portrait ~ 210mm, để lề ~ 550px).
const double kReportPrintContentWidth = 550;

/// Widget nội dung báo cáo Xuất - Nhập - Tồn để xem trước / in ra máy in văn phòng.
/// Dùng trong dialog "In báo cáo nhanh"; người dùng có thể dùng Ctrl+P / Cmd+P để in.
class InventoryReportPrintWidget extends StatelessWidget {
  const InventoryReportPrintWidget({
    super.key,
    required this.report,
    required this.startDate,
    required this.endDate,
  });

  final InventoryReport report;
  final DateTime startDate;
  final DateTime endDate;

  int get _daysInPeriod =>
      endDate.difference(startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'vi_VN');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      width: kReportPrintContentWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line('BÁO CÁO XUẤT - NHẬP - TỒN', bold: true, center: true),
          _line(
            'Kỳ báo cáo: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)} ($_daysInPeriod ngày)',
            small: true,
          ),
          _line('Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', small: true),
          _line('─' * 50),
          _line('Tên SP | ĐVT | Tồn đầu | Nhập | Xuất | TĐ bán/ngày | Tồn cuối | Giá trị cuối', bold: true, small: true),
          _line('─' * 50),
          ...report.items.map((item) {
            final unit = item.product.units.isNotEmpty
                ? item.product.units.first.unitName
                : (item.product.unit.isNotEmpty ? item.product.unit : '');
            final closingValue = item.closingStock * item.product.importPrice;
            final velocity = _daysInPeriod > 0
                ? item.outgoingStock / _daysInPeriod
                : 0.0;
            final minStock = item.product.minStock ?? 0;
            final lowMark = (minStock > 0 && item.closingStock < minStock) ? ' *' : '';
            return _line(
              '${item.product.name}$lowMark | $unit | ${f.format(item.openingStock)} | ${f.format(item.incomingStock)} | ${f.format(item.outgoingStock)} | ${velocity.toStringAsFixed(2)} | ${f.format(item.closingStock)} | ${f.format(closingValue.toInt())}₫',
              small: true,
              wrap: true,
            );
          }),
          _line('─' * 50),
          _line(
            'TỔNG | - | ${f.format(report.totalOpeningStock)} | ${f.format(report.totalIncomingStock)} | ${f.format(report.totalOutgoingStock)} | ${_daysInPeriod > 0 ? (report.totalOutgoingStock / _daysInPeriod).toStringAsFixed(2) : "-"} | ${f.format(report.totalClosingStock)} | ${f.format(report.items.fold<double>(0, (s, i) => s + i.closingStock * i.product.importPrice).toInt())}₫',
            bold: true,
            small: true,
          ),
          if (report.items.any((i) => (i.product.minStock ?? 0) > 0 && i.closingStock < (i.product.minStock ?? 0)))
            _line('* Tồn cuối dưới ngưỡng tối thiểu', small: true),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _line(
    String text, {
    bool bold = false,
    bool center = false,
    bool small = false,
    bool wrap = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
        maxLines: wrap ? 3 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
