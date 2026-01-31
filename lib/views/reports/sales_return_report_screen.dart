import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io' show File, Platform;
import '../../controllers/sales_return_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/customer_provider.dart';
import '../../models/sales_return_model.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/date_range_filter.dart';

/// Màn hình báo cáo tổng hợp hàng trả
class SalesReturnReportScreen extends StatefulWidget {
  const SalesReturnReportScreen({super.key});

  @override
  State<SalesReturnReportScreen> createState() => _SalesReturnReportScreenState();
}

class _SalesReturnReportScreenState extends State<SalesReturnReportScreen> {
  DateTime _startDate = DateTime.now().copyWith(day: 1); // Ngày đầu tháng
  DateTime _endDate = DateTime.now(); // Hôm nay
  String? _selectedBranchId;
  double? _returnRatePercentage;
  int _totalSalesCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    final provider = context.read<SalesReturnProvider>();
    await provider.loadSalesReturnReport(
      startDate: _startDate,
      endDate: _endDate,
      branchId: _selectedBranchId,
    );
    
    // Tính tỷ lệ % hàng trả
    final returnRate = await provider.getReturnRatePercentage(
      startDate: _startDate,
      endDate: _endDate,
      branchId: _selectedBranchId,
    );
    
    // Lấy tổng số đơn bán
    final salesCount = await provider.getTotalSalesCount(
      startDate: _startDate,
      endDate: _endDate,
      branchId: _selectedBranchId,
    );
    
    setState(() {
      _returnRatePercentage = returnRate;
      _totalSalesCount = salesCount;
    });
  }

  Future<void> _exportToExcel() async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SalesReturnProvider>();
    final salesReturns = provider.salesReturns;
    
    if (salesReturns.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu để xuất Excel'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Tạo Excel file
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Báo cáo hàng trả'];

      // Header row
      sheet.appendRow([
        TextCellValue('Mã đơn trả'),
        TextCellValue('Mã đơn gốc'),
        TextCellValue('Khách hàng'),
        TextCellValue('Giá trị trả (₫)'),
        TextCellValue('Lý do'),
        TextCellValue('Phương thức hoàn tiền'),
        TextCellValue('Ngày thực hiện'),
      ]);

      // Data rows
      for (var salesReturn in salesReturns) {
        final customerName = await _getCustomerName(salesReturn.customerId);
        sheet.appendRow([
          TextCellValue(salesReturn.id.substring(0, 8).toUpperCase()),
          TextCellValue(salesReturn.originalSaleId.substring(0, 8).toUpperCase()),
          TextCellValue(customerName ?? 'Khách lẻ'),
          IntCellValue(salesReturn.totalRefundAmount.toInt()),
          TextCellValue(salesReturn.reason),
          TextCellValue(_formatPaymentMethod(salesReturn.paymentMethod)),
          TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(salesReturn.timestamp)),
        ]);
      }

      // Summary row
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('TỔNG CỘNG'),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(provider.totalRefundAmount.toInt()),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      // Lưu file
      final fileName = 'Bao_cao_hang_tra_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      
      if (kIsWeb) {
        // Web: Download file
        final bytes = excel.save();
        if (bytes != null) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('File Excel đã được tạo: $fileName'),
              action: SnackBarAction(
                label: 'Tải về',
                onPressed: () {
                  // ignore: todo
                  // TODO: Implement download for web
                },
              ),
            ),
          );
        }
      } else {
        // Mobile/Desktop: Lưu vào thư mục Downloads hoặc Documents
        final directory = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();
        
        if (directory != null) {
          final filePath = path.join(directory.path, fileName);
          final file = File(filePath);
          final bytes = excel.save();
          if (bytes != null) {
            await file.writeAsBytes(bytes);
            
            if (context.mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Đã xuất Excel: $fileName'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _getCustomerName(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return null;
    
    try {
      final customerProvider = context.read<CustomerProvider>();
      // Tìm trong danh sách customers đã load
      final customer = customerProvider.customers.firstWhere(
        (c) => c.id == customerId,
        orElse: () => throw Exception('Customer not found'),
      );
      return customer.name;
    } catch (e) {
      return null;
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return 'Tiền mặt';
      case 'TRANSFER':
        return 'Chuyển khoản';
      case 'DEBT':
        return 'Trừ vào công nợ';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final double maxWidth = isDesktop ? 1200 : 800;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Báo cáo hàng trả'),
            ),
      body: Column(
        children: [
          // Header và Filters
          ResponsiveContainer(
            maxWidth: maxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Báo cáo tổng hợp hàng trả',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loadReport,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Xuất Excel'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filters
                Row(
                  children: [
                    // Bộ lọc thời gian
                    Expanded(
                      child: DateRangeFilter(
                        startDate: _startDate,
                        endDate: _endDate,
                        onStartDateChanged: (date) {
                          setState(() {
                            _startDate = date;
                          });
                          _loadReport();
                        },
                        onEndDateChanged: (date) {
                          setState(() {
                            _endDate = date;
                          });
                          _loadReport();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Bộ lọc chi nhánh
                    Consumer<BranchProvider>(
                      builder: (context, branchProvider, child) {
                        final branches = branchProvider.branches.where((b) => b.isActive).toList();
                        final items = <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả chi nhánh'),
                          ),
                          ...branches.map(
                            (b) => DropdownMenuItem<String?>(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ];

                        return SizedBox(
                          width: 200,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButton<String?>(
                              value: _selectedBranchId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: items,
                              onChanged: (value) {
                                setState(() {
                                  _selectedBranchId = value;
                                });
                                _loadReport();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary Cards
                Consumer<SalesReturnProvider>(
                  builder: (context, provider, child) {
                    return _SummaryCards(
                      totalReturnCount: provider.totalReturnCount,
                      totalRefundAmount: provider.totalRefundAmount,
                      returnRatePercentage: _returnRatePercentage ?? 0.0,
                      totalSalesCount: _totalSalesCount,
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Charts and Data Table
          Expanded(
            child: ResponsiveContainer(
              maxWidth: maxWidth,
              padding: const EdgeInsets.all(16),
              child: Consumer<SalesReturnProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadReport,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.salesReturns.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Không có dữ liệu trong kỳ báo cáo',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Biểu đồ lý do trả hàng
                        if (provider.reasonStatistics.isNotEmpty) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Thống kê lý do trả hàng',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 300,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _ReasonPieChart(
                                            reasonStatistics: provider.reasonStatistics,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: _ReasonLegend(
                                            reasonStatistics: provider.reasonStatistics,
                                            totalCount: provider.totalReturnCount,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Data Table
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: const Text(
                                  'Chi tiết đơn trả hàng',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: _SalesReturnDataTable(
                                  salesReturns: provider.salesReturns,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary Cards Widget
class _SummaryCards extends StatelessWidget {
  final int totalReturnCount;
  final double totalRefundAmount;
  final double returnRatePercentage;
  final int totalSalesCount;

  const _SummaryCards({
    required this.totalReturnCount,
    required this.totalRefundAmount,
    required this.returnRatePercentage,
    required this.totalSalesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFFF1F2),
            label: 'Tổng số đơn trả',
            value: totalReturnCount.toString(),
            suffix: 'đơn',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.attach_money,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFFF1F2),
            label: 'Tổng giá trị hoàn',
            value: NumberFormat.compactCurrency(
              locale: 'vi_VN',
              symbol: '₫',
            ).format(totalRefundAmount),
            suffix: '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_down,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFFBEB),
            label: 'Tỷ lệ đơn trả',
            value: returnRatePercentage.toStringAsFixed(2),
            suffix: '%',
            subtitle: '$totalReturnCount / $totalSalesCount đơn',
          ),
        ),
      ],
    );
  }
}

/// Stat Card Widget (tái sử dụng từ stock_overview_screen.dart)
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String suffix;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.suffix,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ tròn thể hiện tỷ lệ các lý do trả hàng
class _ReasonPieChart extends StatelessWidget {
  final Map<String, int> reasonStatistics;
  final int totalCount;

  _ReasonPieChart({
    required this.reasonStatistics,
  }) : totalCount = reasonStatistics.values.fold(0, (sum, count) => sum + count);

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) {
      return const Center(
        child: Text('Không có dữ liệu'),
      );
    }

    final colors = [
      const Color(0xFFDC2626),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    int colorIndex = 0;
    final pieChartSections = reasonStatistics.entries.map((entry) {
      final percentage = (entry.value / totalCount) * 100;
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: pieChartSections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}

/// Legend cho biểu đồ
class _ReasonLegend extends StatelessWidget {
  final Map<String, int> reasonStatistics;
  final int totalCount;

  const _ReasonLegend({
    required this.reasonStatistics,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFDC2626),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    int colorIndex = 0;

    return ListView(
      children: reasonStatistics.entries.map((entry) {
        final percentage = (entry.value / totalCount) * 100;
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// DataTable hiển thị chi tiết đơn trả hàng
class _SalesReturnDataTable extends StatelessWidget {
  final List<SalesReturnModel> salesReturns;

  const _SalesReturnDataTable({
    required this.salesReturns,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        // Đảm bảo customers đã được load
        if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            customerProvider.loadCustomers();
          });
        }

        // Tạo map customer names
        final customerNames = <String, String>{};
        for (var customer in customerProvider.customers) {
          customerNames[customer.id] = customer.name;
        }

        return DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columnSpacing: 16,
          columns: const [
            DataColumn(
              label: Text(
                'Mã đơn trả',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Mã đơn gốc',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Khách hàng',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Giá trị trả',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Lý do',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Ngày thực hiện',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          rows: salesReturns.map((salesReturn) {
            final customerName = salesReturn.customerId != null && salesReturn.customerId!.isNotEmpty
                ? (customerNames[salesReturn.customerId] ?? 'Khách lẻ')
                : 'Khách lẻ';
            
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    salesReturn.id.substring(0, 8).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    salesReturn.originalSaleId.substring(0, 8).toUpperCase(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    customerName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(salesReturn.totalRefundAmount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    salesReturn.reason,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(salesReturn.timestamp),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}
