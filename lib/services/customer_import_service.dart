import 'package:excel/excel.dart';

import '../models/customer_model.dart';

/// Service import khách hàng từ file Excel (.xlsx).
/// Hỗ trợ cấu trúc tương thích KiotViet / DanhSachKhachHang.
class CustomerImportService {
  /// Tên cột Excel thường gặp -> index (sẽ map theo dòng header).
  static const _headerNames = [
    'Mã khách hàng',
    'Tên khách hàng',
    'Điện thoại',
    'Địa chỉ',
    'Khu vực giao hàng',
    'Phường/Xã',
    'Công ty',
    'Mã số thuế',
    'Ngày sinh',
    'Giới tính',
    'Email',
    'Nhóm khách hàng',
    'Ghi chú',
    'Ngày tạo',
    'Nợ cần thu hiện tại',
    'Tổng bán',
    'Tổng bán trừ trả hàng',
  ];

  /// Đọc file Excel (bytes), trả về danh sách dòng xem trước.
  /// Sheet: lấy sheet đầu tiên nếu không truyền [sheetName].
  static List<CustomerPreviewRow> parseExcelForPreview(
    List<int> bytes, {
    String? sheetName,
  }) {
    final result = <CustomerPreviewRow>[];
    final excel = Excel.decodeBytes(bytes);
    if (excel.sheets.isEmpty) return result;

    final sheet = sheetName != null && excel.sheets.containsKey(sheetName)
        ? excel.sheets[sheetName]!
        : excel.sheets.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return result;

    final headerRow = rows[0];
    final colIndex = _buildColumnIndex(headerRow);

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final preview = _rowToPreview(r + 1, row, colIndex);
      result.add(preview);
    }
    return result;
  }

  /// Map tên cột (chuẩn hóa) -> index cột (0-based).
  /// Dùng cả text header thật và tên chuẩn để lookup.
  static Map<String, int> _buildColumnIndex(List<Data?> headerRow) {
    final map = <String, int>{};
    for (var c = 0; c < headerRow.length; c++) {
      final cell = headerRow[c];
      if (cell == null) continue;
      final v = cell.value;
      String? text;
      if (v is TextCellValue) {
        text = v.value.text ?? v.value.toString();
      } else {
        text = v?.toString();
      }
      if (text == null || text.trim().isEmpty) continue;
      final key = text.trim().toLowerCase();
      map[key] = c;
    }
    for (final name in _headerNames) {
      final k = name.toLowerCase();
      if (!map.containsKey(k)) {
        for (final entry in map.entries) {
          if (entry.key.contains(k) || k.contains(entry.key)) {
            map[k] = entry.value;
            break;
          }
        }
      }
    }
    return map;
  }

  static String _cellText(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? v.value.toString();
    if (v is IntCellValue) return '${v.value}';
    if (v is DoubleCellValue) return '${v.value}';
    if (v is BoolCellValue) return v.value ? '1' : '0';
    if (v is DateCellValue) return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    if (v is DateTimeCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}'
          'T${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}:00';
    }
    return v.toString();
  }

  static CustomerPreviewRow _rowToPreview(
    int rowIndex,
    List<Data?> row,
    Map<String, int> colIndex,
  ) {
    String get(String key) {
      final i = colIndex[key.toLowerCase()];
      if (i == null || i >= row.length) return '';
      final s = _cellText(row[i]).trim();
      return s == 'null' ? '' : s;
    }

    final code = get('Mã khách hàng');
    final name = get('Tên khách hàng');
    final phone = get('Điện thoại');
    final address = get('Địa chỉ');
    final locationName = get('Khu vực giao hàng');
    final wardName = get('Phường/Xã');
    final organization = get('Công ty');
    final taxCode = get('Mã số thuế');
    final birthDateStr = get('Ngày sinh');
    final genderStr = get('Giới tính');
    final email = get('Email');
    final groupName = get('Nhóm khách hàng');
    final comments = get('Ghi chú');
    final createdAtStr = get('Ngày tạo');
    final totalDebtStr = get('Nợ cần thu hiện tại');
    final totalInvoicedStr = get('Tổng bán');
    final totalRevenueStr = get('Tổng bán trừ trả hàng');

    String? errorMsg;
    if (name.isEmpty) errorMsg = 'Tên khách hàng không được để trống';
    if (errorMsg == null && phone.isEmpty) errorMsg = 'Điện thoại không được để trống';

    return CustomerPreviewRow(
      rowIndex: rowIndex,
      code: code.isEmpty ? null : code,
      name: name,
      phone: phone,
      address: address.isEmpty ? null : address,
      locationName: locationName.isEmpty ? null : locationName,
      wardName: wardName.isEmpty ? null : wardName,
      organization: organization.isEmpty ? null : organization,
      taxCode: taxCode.isEmpty ? null : taxCode,
      birthDateStr: birthDateStr.isEmpty ? null : birthDateStr,
      genderStr: genderStr.isEmpty ? null : genderStr,
      email: email.isEmpty ? null : email,
      groupName: groupName.isEmpty ? null : groupName,
      comments: comments.isEmpty ? null : comments,
      createdAtStr: createdAtStr.isEmpty ? null : createdAtStr,
      totalDebtStr: totalDebtStr,
      totalInvoicedStr: totalInvoicedStr,
      totalRevenueStr: totalRevenueStr,
      isValid: errorMsg == null,
      errorMessage: errorMsg,
    );
  }

  /// Chuyển các dòng preview hợp lệ thành [CustomerModel].
  /// [groupIdByGroupName]: map tên nhóm -> id (từ CustomerProvider.customerGroups).
  static List<CustomerModel> previewRowsToCustomers(
    List<CustomerPreviewRow> validRows,
    Map<String, String> groupIdByGroupName, {
    String Function(int index)? idGenerator,
  }) {
    final list = <CustomerModel>[];
    for (var i = 0; i < validRows.length; i++) {
      final row = validRows[i];
      if (!row.isValid) continue;

      final id = idGenerator != null
          ? idGenerator(i)
          : 'import_${DateTime.now().millisecondsSinceEpoch}_$i';

      final groupId = row.groupName != null && row.groupName!.isNotEmpty
          ? (groupIdByGroupName[row.groupName!] ?? groupIdByGroupName[row.groupName!.trim()])
          : null;

      DateTime? birthDate;
      if (row.birthDateStr != null && row.birthDateStr!.isNotEmpty) {
        birthDate = DateTime.tryParse(row.birthDateStr!.split('T').first);
      }

      bool? gender;
      if (row.genderStr != null && row.genderStr!.isNotEmpty) {
        final g = row.genderStr!.toLowerCase();
        if (g == 'nam' || g == '1' || g == 'male' || g == 'true') gender = true;
        if (g == 'nữ' || g == 'nu' || g == '0' || g == 'nữ' || g == 'female' || g == 'false') gender = false;
      }

      DateTime? createdAt;
      if (row.createdAtStr != null && row.createdAtStr!.isNotEmpty) {
        createdAt = DateTime.tryParse(row.createdAtStr!.replaceFirst('T', ' ').split('.').first);
      }

      final totalDebt = double.tryParse(row.totalDebtStr.replaceAll(',', '')) ?? 0.0;
      final totalInvoiced = double.tryParse(row.totalInvoicedStr.replaceAll(',', ''));
      final totalRevenue = double.tryParse(row.totalRevenueStr.replaceAll(',', '')) ?? 0.0;

      list.add(CustomerModel(
        id: id,
        code: row.code,
        name: row.name,
        phone: row.phone,
        address: row.address,
        groupId: groupId,
        groups: row.groupName != null && row.groupName!.isNotEmpty ? [row.groupName!] : [],
        totalDebt: totalDebt,
        totalRevenue: totalRevenue,
        totalInvoiced: totalInvoiced,
        taxCode: row.taxCode,
        gender: gender,
        birthDate: birthDate,
        email: row.email,
        locationName: row.locationName,
        wardName: row.wardName,
        organization: row.organization,
        comments: row.comments,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    return list;
  }
}

/// Một dòng xem trước khi import khách hàng (chưa lưu DB).
class CustomerPreviewRow {
  const CustomerPreviewRow({
    required this.rowIndex,
    this.code,
    required this.name,
    required this.phone,
    this.address,
    this.locationName,
    this.wardName,
    this.organization,
    this.taxCode,
    this.birthDateStr,
    this.genderStr,
    this.email,
    this.groupName,
    this.comments,
    this.createdAtStr,
    required this.totalDebtStr,
    required this.totalInvoicedStr,
    required this.totalRevenueStr,
    required this.isValid,
    this.errorMessage,
  });

  final int rowIndex;
  final String? code;
  final String name;
  final String phone;
  final String? address;
  final String? locationName;
  final String? wardName;
  final String? organization;
  final String? taxCode;
  final String? birthDateStr;
  final String? genderStr;
  final String? email;
  final String? groupName;
  final String? comments;
  final String? createdAtStr;
  final String totalDebtStr;
  final String totalInvoicedStr;
  final String totalRevenueStr;
  final bool isValid;
  final String? errorMessage;
}
