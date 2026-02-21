import '../../models/customer_model.dart';
import '../../models/customer_group_model.dart';

/// Định nghĩa cột có thể hiển thị trong bảng khách hàng.
class CustomerColumnDef {
  final String id;
  final String label;
  final bool hasTotal;
  const CustomerColumnDef(this.id, this.label, this.hasTotal);
}

/// Danh sách cột chuẩn cho bảng khách hàng.
const List<CustomerColumnDef> customerColumnDefs = [
  CustomerColumnDef('code', 'Mã khách hàng', false),
  CustomerColumnDef('name', 'Tên khách hàng', false),
  CustomerColumnDef('customerType', 'Loại khách hàng', false),
  CustomerColumnDef('phone', 'Điện thoại', false),
  CustomerColumnDef('groupName', 'Nhóm khách hàng', false),
  CustomerColumnDef('gender', 'Giới tính', false),
  CustomerColumnDef('birthDate', 'Ngày sinh', false),
  CustomerColumnDef('email', 'Email', false),
  CustomerColumnDef('facebook', 'Facebook', false),
  CustomerColumnDef('organization', 'Công ty', false),
  CustomerColumnDef('taxCode', 'Mã số thuế', false),
  CustomerColumnDef('idCard', 'Số CCCD/CMND', false),
  CustomerColumnDef('address', 'Địa chỉ', false),
  CustomerColumnDef('deliveryArea', 'Khu vực giao hàng', false),
  CustomerColumnDef('wardName', 'Phường/Xã', false),
  CustomerColumnDef('createdBy', 'Người tạo', false),
  CustomerColumnDef('createdAt', 'Ngày tạo', false),
  CustomerColumnDef('comments', 'Ghi chú', false),
  CustomerColumnDef('lastTransactionDate', 'Ngày giao dịch cuối', false),
  CustomerColumnDef('createdBranch', 'Chi nhánh tạo', false),
  CustomerColumnDef('totalDebt', 'Nợ hiện tại', true),
  CustomerColumnDef('totalInvoiced', 'Tổng bán', true),
  CustomerColumnDef('currentPoints', 'Điểm hiện tại', false),
  CustomerColumnDef('totalPoints', 'Tổng điểm', false),
  CustomerColumnDef('totalRevenue', 'Tổng bán trừ trả hàng', true),
  CustomerColumnDef('status', 'Trạng thái', false),
];

/// Kết quả chọn từ màn Bộ lọc khách hàng (mobile).
class CustomerFilterResult {
  const CustomerFilterResult({
    this.groupId,
    this.gender = 0,
    this.birthDateFrom,
    this.birthDateTo,
    this.createdAtFrom,
    this.createdAtTo,
    this.totalSalesFromText = '',
    this.totalSalesToText = '',
    this.debtFromText = '',
    this.debtToText = '',
    this.status = 1,
  });

  final String? groupId;
  /// 0: tất cả, 1: Nam, 2: Nữ
  final int gender;
  final DateTime? birthDateFrom;
  final DateTime? birthDateTo;
  final DateTime? createdAtFrom;
  final DateTime? createdAtTo;
  final String totalSalesFromText;
  final String totalSalesToText;
  final String debtFromText;
  final String debtToText;
  /// 1: Đang hoạt động, 0: Ngừng hoạt động
  final int status;
}

/// Snapshot dữ liệu cho màn hình Quản lý khách hàng (dùng chung Mobile/Desktop).
class CustomerManagementSnapshot {
  const CustomerManagementSnapshot({
    required this.filteredCustomers,
    required this.selectedGroupId,
    this.selectedCustomer,
    required this.visibleColumns,
    required this.customerGroups,
    required this.isLoading,
  });

  final List<CustomerModel> filteredCustomers;
  final String? selectedGroupId;
  final CustomerModel? selectedCustomer;
  final Map<String, bool> visibleColumns;
  final List<CustomerGroupModel> customerGroups;
  final bool isLoading;
}
