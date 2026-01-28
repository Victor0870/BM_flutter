import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shop_model.dart';
import '../models/user_model.dart';
import '../services/local_db_service.dart';

/// Provider quản lý trạng thái authentication và thông tin shop
class AuthProvider with ChangeNotifier {
  User? _user;
  ShopModel? _shop;
  UserModel? _userProfile;
  bool _isLoading = false;
  bool _isOfflineMode = false;
  String? _errorMessage;
  bool _isFirebaseReady = false;
  bool _isInitializing = true; // Trạng thái khởi tạo hệ thống
  String? _selectedBranchId; // Chi nhánh đang được chọn

  // Getters
  User? get user => _user;
  ShopModel? get shop => _shop;
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _isOfflineMode;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get selectedBranchId => _selectedBranchId;
  
  /// Kiểm tra Firebase đã sẵn sàng chưa
  bool get isFirebaseReady => _isFirebaseReady;
  
  /// Kiểm tra hệ thống đang khởi tạo
  bool get isInitializing => _isInitializing;
  
  /// Kiểm tra xem user có phải gói PRO không
  bool get isPro {
    if (_shop == null) return false;
    return _shop!.packageType == 'PRO' && _shop!.isLicenseValid;
  }

  /// Kiểm tra xem user có phải gói BASIC không
  bool get isBasic {
    if (_shop == null) return false;
    return _shop!.packageType == 'BASIC';
  }

  /// Kiểm tra quyền dựa trên UserModel (admin / staff)
  bool get isAdminUser => _userProfile?.isAdmin ?? false;
  bool get isStaffUser => _userProfile?.isStaff ?? false;

  AuthProvider() {
    _initializeFirebase();
    _loadSelectedBranchId();
    _initializeSystem();
  }
  
  /// Khởi tạo hệ thống: đợi Firebase, SQLite, và load shop data
  Future<void> _initializeSystem() async {
    try {
      // BƯỚC 1: Đợi Firebase xác định trạng thái User
      // Đợi một chút để Firebase hoàn tất khởi tạo
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Kiểm tra Firebase đã sẵn sàng chưa
      int retryCount = 0;
      while (!_isFirebaseReady && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }
      
      if (!_isFirebaseReady) {
        if (kDebugMode) {
          debugPrint('Firebase chưa sẵn sàng sau khi retry');
        }
        _isInitializing = false;
        notifyListeners();
        return;
      }
      
      // Lấy user hiện tại từ Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      _user = user;
      
      // BƯỚC 2: Đảm bảo SQLite đã sẵn sàng
      try {
        await LocalDbService().database;
        if (kDebugMode) {
          debugPrint('✅ SQLite database initialized');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error initializing SQLite: $e');
        }
        // Tiếp tục dù SQLite có lỗi (có thể là web platform)
      }
      
      // BƯỚC 3: Nếu User đã login, load thông tin Shop
      if (user != null) {
        await checkAuthStatus();
      }
      
      // BƯỚC 4: Hoàn tất khởi tạo
      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing system: $e');
      }
      _isInitializing = false;
      _errorMessage = 'Lỗi khởi tạo hệ thống: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Tải selectedBranchId từ SharedPreferences
  Future<void> _loadSelectedBranchId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final branchId = prefs.getString('selected_branch_id');
      if (branchId != null && branchId.isNotEmpty) {
        _selectedBranchId = branchId;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading selected branch ID: $e');
      }
    }
  }

  /// Lưu selectedBranchId vào SharedPreferences
  Future<void> _saveSelectedBranchId(String? branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (branchId != null && branchId.isNotEmpty) {
        await prefs.setString('selected_branch_id', branchId);
      } else {
        await prefs.remove('selected_branch_id');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving selected branch ID: $e');
      }
    }
  }

  /// Đặt chi nhánh được chọn
  Future<void> setSelectedBranchId(String? branchId) async {
    _selectedBranchId = branchId;
    await _saveSelectedBranchId(branchId);
    notifyListeners();
  }

  /// Khởi tạo và kiểm tra Firebase
  Future<void> _initializeFirebase() async {
    try {
      // Kiểm tra Firebase đã được khởi tạo chưa
      final app = Firebase.apps.isNotEmpty ? Firebase.app() : null;
      if (app != null) {
        _isFirebaseReady = true;
        if (kDebugMode) {
          debugPrint('Firebase is ready');
        }
        
        // Lắng nghe thay đổi trạng thái authentication
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          // Chỉ xử lý auth state changes sau khi khởi tạo hoàn tất
          if (!_isInitializing) {
            _user = user;
            if (user != null) {
              // Tự động kiểm tra auth status khi user đăng nhập
              checkAuthStatus();
            } else {
              // Reset state khi user đăng xuất
              _shop = null;
              _isOfflineMode = false;
              notifyListeners();
            }
          }
        });
        
        notifyListeners();
      } else {
        _isFirebaseReady = false;
        _errorMessage = 'Firebase chưa được khởi tạo';
        if (kDebugMode) {
          debugPrint('Firebase is not initialized');
        }
        notifyListeners();
      }
    } catch (e) {
      _isFirebaseReady = false;
      _errorMessage = 'Lỗi khởi tạo Firebase: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Error initializing Firebase: $e');
      }
      notifyListeners();
    }
  }

  /// Kiểm tra và tải trạng thái authentication cùng với dữ liệu shop
  /// Nếu user là gói BASIC, vẫn cho phép đăng nhập nhưng đánh dấu chế độ Offline
  Future<void> checkAuthStatus() async {
    // Kiểm tra Firebase đã sẵn sàng
    if (!_isFirebaseReady) {
      if (kDebugMode) {
        debugPrint('Firebase not ready, skipping checkAuthStatus');
      }
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _user = null;
        _shop = null;
        _userProfile = null;
        _isOfflineMode = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _user = user;

      final firestore = FirebaseFirestore.instance;

      // Kiểm tra xem user có profile trong collection 'users' (nhân viên)
      final userDoc = await firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        // Đây là nhân viên
        _userProfile = UserModel.fromFirestore(userDoc.data()!, userDoc.id);

        if (!_userProfile!.isApproved) {
          // Nhân viên chưa được duyệt -> sign out và báo lỗi
          await FirebaseAuth.instance.signOut();
          _user = null;
          _shop = null;
          _isOfflineMode = false;
          _isLoading = false;
          _errorMessage = 'Tài khoản của bạn đang chờ được phê duyệt';
          notifyListeners();
          return;
        }

        // Nhân viên đã được duyệt -> load shop theo shopId trong userProfile
        final shopId = _userProfile!.shopId;
        final shopDoc =
            await firestore.collection('shops').doc(shopId).get();

        if (shopDoc.exists && shopDoc.data() != null) {
          _shop = ShopModel.fromFirestore(shopDoc.data()!, shopDoc.id);
        } else {
          // Không tìm thấy shop tương ứng -> lỗi cấu hình
          _shop = null;
          _isOfflineMode = false;
          _errorMessage =
              'Không tìm thấy cửa hàng tương ứng với tài khoản nhân viên.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      } else {
        // Không có tài liệu trong 'users' => đây là chủ shop (admin)
        _userProfile = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          shopId: user.uid,
          role: UserRole.admin,
          isApproved: true,
          createdAt: DateTime.now(),
        );

        // Shop document ID = user.uid
        final shopDoc = await firestore.collection('shops').doc(user.uid).get();

        if (shopDoc.exists && shopDoc.data() != null) {
          _shop = ShopModel.fromFirestore(shopDoc.data()!, shopDoc.id);
        } else {
          // Không tìm thấy shop data, có thể là user mới
          // Tạo shop mặc định với gói BASIC
          _shop = ShopModel(
            id: user.uid,
            name: user.displayName ?? 'Shop Name',
            email: user.email,
            packageType: 'BASIC',
            isActive: true,
          );
          _isOfflineMode = true;

          // Lưu shop mặc định vào Firestore (optional)
          // await firestore.collection('shops').doc(user.uid).set(_shop!.toFirestore());
        }
      }

      // Thiết lập chế độ online/offline dựa trên gói dịch vụ
      if (_shop != null) {
        if (_shop!.packageType == 'BASIC') {
          _isOfflineMode = true;
          if (kDebugMode) {
            debugPrint('User is on BASIC package. App will run in Offline mode.');
          }
        } else if (_shop!.packageType == 'PRO') {
          if (_shop!.isLicenseValid) {
            _isOfflineMode = false;
          } else {
            _isOfflineMode = true;
            if (kDebugMode) {
              debugPrint('PRO license expired. App will run in Offline mode.');
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error checking auth status: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('AuthProvider checkAuthStatus error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Đăng nhập với email và password
  /// [rememberMe] nếu true, sẽ lưu email vào SharedPreferences (KHÔNG lưu mật khẩu)
  Future<bool> signInWithEmailAndPassword(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    // Kiểm tra Firebase đã sẵn sàng
    if (!_isFirebaseReady) {
      _errorMessage = 'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Lưu email nếu người dùng chọn "Ghi nhớ tài khoản"
        if (rememberMe) {
          await _saveRememberedEmail(email);
        } else {
          // Xóa email đã lưu nếu không chọn ghi nhớ
          await _clearRememberedEmail();
        }

        // checkAuthStatus sẽ được gọi tự động qua authStateChanges listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Đăng nhập thất bại: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Lưu email vào SharedPreferences (chỉ email, không lưu mật khẩu)
  Future<void> _saveRememberedEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_email', email);
      if (kDebugMode) {
        debugPrint('✅ Email đã được lưu: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Lỗi khi lưu email: $e');
      }
    }
  }

  /// Xóa email đã lưu khỏi SharedPreferences
  Future<void> _clearRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remembered_email');
      if (kDebugMode) {
        debugPrint('✅ Đã xóa email đã lưu');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Lỗi khi xóa email: $e');
      }
    }
  }

  /// Lấy email đã lưu từ SharedPreferences (nếu có)
  Future<String?> getRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('remembered_email');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Lỗi khi đọc email: $e');
      }
      return null;
    }
  }

  /// Đăng ký với email và password
  /// Tự động tạo ShopModel mặc định với gói PRO, dùng thử 14 ngày cho Chủ shop
  Future<bool> signUpOwnerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Kiểm tra Firebase đã sẵn sàng
    if (!_isFirebaseReady) {
      _errorMessage = 'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Tạo user mới cho chủ shop
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = credential.user!;
        
        // Tạo ShopModel mặc định với gói PRO, dùng thử 14 ngày
        final licenseEndDate = DateTime.now().add(const Duration(days: 14));
        
        final defaultShop = ShopModel(
          id: user.uid,
          name: '', // Tên shop trống, user sẽ cập nhật sau
          email: user.email,
          packageType: 'PRO',
          licenseEndDate: licenseEndDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        // Lưu shop vào Firestore
        final firestore = FirebaseFirestore.instance;
        try {
          await firestore.collection('shops').doc(user.uid).set(
            defaultShop.toFirestore(),
          );

          if (kDebugMode) {
            debugPrint('✅ Shop created successfully in Firestore for user: ${user.uid}');
            debugPrint('License expires on: ${licenseEndDate.toIso8601String()}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Error creating shop in Firestore: $e');
          }
          // Vẫn cập nhật state local dù Firestore lỗi
        }

        // Cập nhật state
        _shop = defaultShop;
        _isOfflineMode = false; // PRO package nên không offline

        // checkAuthStatus sẽ được gọi tự động qua authStateChanges listener
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Đăng ký thất bại: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký nhân viên với email, password và shopId
  /// Tạo document trong collection users với isApproved = false
  Future<bool> signUpStaffWithEmailAndPassword(
    String email,
    String password, {
    required String shopId,
  }) async {
    // Kiểm tra Firebase đã sẵn sàng
    if (!_isFirebaseReady) {
      _errorMessage = 'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final firestore = FirebaseFirestore.instance;

      // Kiểm tra shop có tồn tại và cho phép đăng ký hay không
      final shopDoc = await firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists || shopDoc.data() == null) {
        _isLoading = false;
        _errorMessage = 'Shop ID không hợp lệ.';
        notifyListeners();
        return false;
      }

      final shop = ShopModel.fromFirestore(shopDoc.data()!, shopDoc.id);
      // So sánh != true để tránh lỗi nếu dữ liệu cũ có allowRegistration = null
      if (shop.allowRegistration != true) {
        _isLoading = false;
        _errorMessage =
            'Cửa hàng hiện không cho phép đăng ký tài khoản nhân viên.';
        notifyListeners();
        return false;
      }

      // Tạo user Firebase cho nhân viên
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final firebaseUser = credential.user!;

        // Tạo document trong collection users
        final userModel = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          shopId: shopId,
          role: UserRole.staff,
          isApproved: false,
          createdAt: DateTime.now(),
        );

        await firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(userModel.toFirestore());

        // Sau khi đăng ký xong, sign out ngay và báo cho nhân viên chờ phê duyệt
        await FirebaseAuth.instance.signOut();
        _user = null;
        _shop = null;
        _userProfile = null;
        _isOfflineMode = false;

        _isLoading = false;
        _errorMessage =
            'Đăng ký thành công, vui lòng đợi Admin phê duyệt tài khoản.';
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Đăng ký thất bại: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _user = null;
      _shop = null;
      _isOfflineMode = false;
      _errorMessage = null;
      // KHÔNG xóa email đã ghi nhớ khi đăng xuất
      // Người dùng có thể vẫn muốn email được điền tự động lần sau
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Đăng xuất thất bại: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Lấy thông báo lỗi từ Firebase Auth error code
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập không được phép.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng sử dụng mật khẩu mạnh hơn.';
      default:
        return 'Đăng nhập thất bại. Vui lòng thử lại.';
    }
  }

  /// Cập nhật thông tin shop (sau khi đăng nhập)
  Future<void> updateShop(ShopModel shop) async {
    _shop = shop;
    
    // Cập nhật lại chế độ offline dựa trên packageType
    if (_shop!.packageType == 'BASIC') {
      _isOfflineMode = true;
    } else if (_shop!.packageType == 'PRO') {
      _isOfflineMode = !_shop!.isLicenseValid;
    }
    
    notifyListeners();
  }
}

