import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/branch_model.dart';
import '../services/branch_service.dart';
import 'auth_provider.dart';

/// Provider quản lý danh sách chi nhánh và state
class BranchProvider with ChangeNotifier {
  final AuthProvider authProvider;
  BranchService? _branchService;

  List<BranchModel> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false; // Flag để track xem provider đã bị dispose chưa
  String? _currentBranchId; // ID của chi nhánh hiện tại đang được chọn

  // Getters
  List<BranchModel> get branches => _branches;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get branchCount => _branches.length;
  String? get currentBranchId => _currentBranchId;

  BranchProvider(this.authProvider) {
    // Lắng nghe thay đổi từ AuthProvider để cập nhật BranchService
    authProvider.addListener(_onAuthChanged);
    _initializeService();
    // Tải currentBranchId từ SharedPreferences khi khởi tạo
    _loadCurrentBranchId();
  }

  /// Khởi tạo BranchService dựa trên trạng thái auth
  void _initializeService() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      _branchService = BranchService(
        isPro: isPro,
        userId: user.uid,
      );
    } else {
      _branchService = null;
      _branches = [];
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      _branchService = BranchService(
        isPro: isPro,
        userId: user.uid,
      );
      // Load lại branches
      loadBranches();
    } else {
      _branchService = null;
      _branches = [];
      _safeNotifyListeners();
    }
  }

  /// Load danh sách chi nhánh
  Future<void> loadBranches({bool includeInactive = false}) async {
    if (_branchService == null) {
      // Không set error message nếu chưa đăng nhập, chỉ để branches rỗng
      _branches = [];
      _errorMessage = null;
      _isLoading = false;
      _safeNotifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      _branches = await _branchService!.getBranches(includeInactive: includeInactive);

      // Kiểm tra nếu provider đã bị dispose trước khi cập nhật state
      if (_disposed) return;

      // Tự động tạo chi nhánh mặc định "Cửa hàng chính" nếu chưa có
      final hasMainStore = _branches.any((b) => b.id == kMainStoreBranchId);
      if (!hasMainStore) {
        final mainStore = BranchModel(
          id: kMainStoreBranchId,
          name: 'Cửa hàng chính',
          isActive: true,
        );
        try {
          await _branchService!.addBranch(mainStore);
          _branches.insert(0, mainStore); // Thêm vào đầu danh sách
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error creating default branch: $e');
          }
        }
      } else {
        // Đảm bảo "Cửa hàng chính" luôn ở đầu danh sách
        final mainStoreIndex = _branches.indexWhere((b) => b.id == kMainStoreBranchId);
        if (mainStoreIndex > 0) {
          final mainStore = _branches.removeAt(mainStoreIndex);
          _branches.insert(0, mainStore);
        }
      }

      // Kiểm tra xem currentBranchId từ SharedPreferences có còn tồn tại trong danh sách không
      if (_currentBranchId != null) {
        final branchExists = _branches.any((b) => b.id == _currentBranchId);
        if (!branchExists) {
          // Nếu branchId đã lưu không còn tồn tại, reset về null
          _currentBranchId = null;
        }
      }

      // Xử lý logic tự động chọn chi nhánh:
      // 1. Nếu là Staff và có workingBranchId, tự động chọn chi nhánh đó
      // 2. Nếu không có workingBranchId hoặc là Admin, chọn chi nhánh đầu tiên
      if (_currentBranchId == null && _branches.isNotEmpty) {
        final userProfile = authProvider.userProfile;
        String? branchIdToSet;
        
        // Nếu là Staff và có workingBranchId, ưu tiên chọn chi nhánh đó
        if (userProfile != null && userProfile.isStaff && userProfile.workingBranchId != null && userProfile.workingBranchId!.isNotEmpty) {
          final workingBranchExists = _branches.any((b) => b.id == userProfile.workingBranchId);
          if (workingBranchExists) {
            branchIdToSet = userProfile.workingBranchId;
            if (kDebugMode) {
              debugPrint('✅ Auto-selected working branch for staff: ${userProfile.workingBranchId}');
            }
          }
        }
        
        // Nếu chưa có branchId, chọn chi nhánh đầu tiên
        branchIdToSet ??= _branches.first.id;
        _currentBranchId = branchIdToSet;
        // Lưu vào SharedPreferences
        await _saveCurrentBranchId(_currentBranchId);
      }

      _isLoading = false;
      _errorMessage = null;
      _safeNotifyListeners();
    } catch (e) {
      // Kiểm tra nếu provider đã bị dispose trước khi xử lý lỗi
      if (_disposed) return;

      _isLoading = false;
      _errorMessage = 'Lỗi khi tải danh sách chi nhánh: ${e.toString()}';
      _branches = []; // Đảm bảo branches không null
      if (kDebugMode) {
        debugPrint('BranchProvider loadBranches error: $_errorMessage');
      }
      _safeNotifyListeners();
    }
  }

  /// Thêm chi nhánh mới
  Future<bool> addBranch(BranchModel branch) async {
    if (_disposed) return false;
    
    if (_branchService == null) {
      _errorMessage = 'Chưa đăng nhập';
      _safeNotifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _branchService!.addBranch(branch);

      // Reload danh sách
      await loadBranches();

      if (_disposed) return false;
      _isLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (_disposed) return false;
      _isLoading = false;
      _errorMessage = 'Lỗi khi thêm chi nhánh: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('BranchProvider addBranch error: $_errorMessage');
      }
      _safeNotifyListeners();
      return false;
    }
  }

  /// Cập nhật chi nhánh
  Future<bool> updateBranch(BranchModel branch) async {
    if (_disposed) return false;
    
    if (_branchService == null) {
      _errorMessage = 'Chưa đăng nhập';
      _safeNotifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _branchService!.updateBranch(branch);

      // Reload danh sách
      await loadBranches();

      if (_disposed) return false;
      _isLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (_disposed) return false;
      _isLoading = false;
      _errorMessage = 'Lỗi khi cập nhật chi nhánh: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('BranchProvider updateBranch error: $_errorMessage');
      }
      _safeNotifyListeners();
      return false;
    }
  }

  /// Xóa chi nhánh (soft delete)
  Future<bool> deleteBranch(String id) async {
    if (_disposed) return false;
    
    if (_branchService == null) {
      _errorMessage = 'Chưa đăng nhập';
      _safeNotifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _branchService!.deleteBranch(id);

      // Reload danh sách
      await loadBranches();

      if (_disposed) return false;
      _isLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (_disposed) return false;
      _isLoading = false;
      _errorMessage = 'Lỗi khi xóa chi nhánh: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('BranchProvider deleteBranch error: $_errorMessage');
      }
      _safeNotifyListeners();
      return false;
    }
  }

  /// Thiết lập chi nhánh hiện tại được chọn
  /// Lưu vào SharedPreferences để nhớ khi khởi động lại app
  Future<void> setSelectedBranch(String branchId) async {
    if (_disposed) return;
    
    // Kiểm tra xem branchId có tồn tại trong danh sách không
    final branchExists = _branches.any((b) => b.id == branchId);
    if (!branchExists) {
      if (kDebugMode) {
        debugPrint('Warning: Branch ID $branchId does not exist in branches list');
      }
      // Vẫn cho phép set để tránh lỗi khi branches chưa load xong
    }

    _currentBranchId = branchId;
    await _saveCurrentBranchId(branchId);
    _safeNotifyListeners();
  }

  /// Tải currentBranchId từ SharedPreferences
  Future<void> _loadCurrentBranchId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getString('current_branch_id');
      if (branchId != null && branchId.isNotEmpty) {
        _currentBranchId = branchId;
        // Không gọi notifyListeners ở đây vì có thể chưa load xong branches
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading current branch ID: $e');
      }
    }
  }

  /// Lưu currentBranchId vào SharedPreferences
  Future<void> _saveCurrentBranchId(String? branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (branchId != null && branchId.isNotEmpty) {
        await prefs.setString('current_branch_id', branchId);
      } else {
        await prefs.remove('current_branch_id');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving current branch ID: $e');
      }
    }
  }

  /// Gọi notifyListeners() an toàn (chỉ khi chưa bị dispose)
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
