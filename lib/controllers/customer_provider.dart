import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../models/customer_group_model.dart';
import '../services/customer_service.dart';
import 'auth_provider.dart';

/// Provider quản lý state của khách hàng và nhóm khách hàng
class CustomerProvider with ChangeNotifier {
  final AuthProvider authProvider;
  CustomerService? _customerService;

  // State
  List<CustomerModel> _customers = [];
  List<CustomerGroupModel> _customerGroups = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<CustomerModel> get customers => _customers;
  List<CustomerGroupModel> get customerGroups => _customerGroups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CustomerProvider(this.authProvider) {
    authProvider.addListener(_onAuthChanged);
    _initializeService();
  }

  /// Khởi tạo service dựa trên trạng thái auth
  void _initializeService() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      _customerService = CustomerService(
        isPro: isPro,
        userId: user.uid,
      );
    } else {
      _customerService = null;
      _customers = [];
      _customerGroups = [];
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    _initializeService();
  }

  /// Tải danh sách khách hàng
  Future<void> loadCustomers() async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _customers = await _customerService!.getCustomers();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải danh sách khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider loadCustomers error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Tải danh sách nhóm khách hàng
  Future<void> loadCustomerGroups() async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _customerGroups = await _customerService!.getCustomerGroups();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải danh sách nhóm khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider loadCustomerGroups error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Tìm kiếm khách hàng
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (_customerService == null || query.trim().isEmpty) {
      return [];
    }

    try {
      return await _customerService!.searchCustomers(query.trim());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CustomerProvider searchCustomers error: $e');
      }
      return [];
    }
  }

  /// Thêm khách hàng
  Future<bool> addCustomer(CustomerModel customer) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.addCustomer(customer);
      
      // Reload danh sách
      await loadCustomers();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi thêm khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider addCustomer error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật khách hàng
  Future<bool> updateCustomer(CustomerModel customer) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.updateCustomer(customer);
      
      // Reload danh sách
      await loadCustomers();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi cập nhật khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider updateCustomer error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa khách hàng
  Future<bool> deleteCustomer(String id) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.deleteCustomer(id);
      
      // Reload danh sách
      await loadCustomers();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider deleteCustomer error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Thêm nhóm khách hàng
  Future<bool> addCustomerGroup(CustomerGroupModel group) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.addCustomerGroup(group);
      
      // Reload danh sách
      await loadCustomerGroups();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi thêm nhóm khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider addCustomerGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật nhóm khách hàng
  Future<bool> updateCustomerGroup(CustomerGroupModel group) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.updateCustomerGroup(group);
      
      // Reload danh sách
      await loadCustomerGroups();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi cập nhật nhóm khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider updateCustomerGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa nhóm khách hàng
  Future<bool> deleteCustomerGroup(String id) async {
    if (_customerService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _errorMessage = null;
      notifyListeners();

      await _customerService!.deleteCustomerGroup(id);
      
      // Reload danh sách
      await loadCustomerGroups();

      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa nhóm khách hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('CustomerProvider deleteCustomerGroup error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Lấy nhóm khách hàng theo ID
  CustomerGroupModel? getCustomerGroupById(String? groupId) {
    if (groupId == null || groupId.isEmpty) return null;
    try {
      return _customerGroups.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
