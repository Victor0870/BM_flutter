import 'package:flutter/foundation.dart';
import '../models/employee_group_model.dart';
import '../services/employee_group_service.dart';
import 'auth_provider.dart';

/// Provider quản lý trạng thái nhóm nhân viên (phân quyền).
class EmployeeGroupProvider with ChangeNotifier {
  final AuthProvider authProvider;
  EmployeeGroupService? _service;

  List<EmployeeGroupModel> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EmployeeGroupModel> get employeeGroups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  EmployeeGroupProvider(this.authProvider) {
    authProvider.addListener(_onAuthChanged);
    _initService();
  }

  void _onAuthChanged() {
    _initService();
  }

  void _initService() {
    final shopId = authProvider.shop?.id;
    if (shopId != null) {
      _service = EmployeeGroupService(shopId: shopId);
    } else {
      _service = null;
      _groups = [];
    }
    notifyListeners();
  }

  /// Tải danh sách nhóm nhân viên.
  Future<void> loadEmployeeGroups() async {
    if (_service == null) {
      _errorMessage = 'Chưa đăng nhập hoặc chưa có shop';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _groups = await _service!.getEmployeeGroups();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi tải nhóm nhân viên: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('EmployeeGroupProvider loadEmployeeGroups error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Lấy nhóm theo ID (từ cache hoặc service).
  EmployeeGroupModel? getEmployeeGroupById(String? groupId) {
    if (groupId == null || groupId.isEmpty) return null;
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  /// Thêm nhóm. [group.id] có thể để trống.
  Future<bool> addEmployeeGroup(EmployeeGroupModel group) async {
    if (_service == null) {
      _errorMessage = 'Chưa đăng nhập hoặc chưa có shop';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _service!.addEmployeeGroup(group);
      await loadEmployeeGroups();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi thêm nhóm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('EmployeeGroupProvider addEmployeeGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật nhóm.
  Future<bool> updateEmployeeGroup(EmployeeGroupModel group) async {
    if (_service == null) {
      _errorMessage = 'Chưa đăng nhập hoặc chưa có shop';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _service!.updateEmployeeGroup(group);
      await loadEmployeeGroups();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật nhóm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('EmployeeGroupProvider updateEmployeeGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa nhóm.
  Future<bool> deleteEmployeeGroup(String id) async {
    if (_service == null) {
      _errorMessage = 'Chưa đăng nhập hoặc chưa có shop';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      await _service!.deleteEmployeeGroup(id);
      await loadEmployeeGroups();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi xóa nhóm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('EmployeeGroupProvider deleteEmployeeGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }
}
