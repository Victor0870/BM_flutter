import 'package:flutter/foundation.dart';
import '../models/transfer_model.dart';
import '../models/product_model.dart';
import '../services/transfer_service.dart';
import '../services/product_service.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

/// Provider quản lý giỏ chuyển kho và lưu phiếu chuyển kho
class TransferProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final BranchProvider branchProvider;

  final List<TransferItem> _items = [];
  String? _toBranchId;
  String _notes = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<TransferItem> get items => List.unmodifiable(_items);
  String? get toBranchId => _toBranchId;
  String get notes => _notes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _items.isEmpty;
  int get totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity.toInt());
  double get totalValue => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  TransferProvider(this.authProvider, this.branchProvider);

  void setToBranchId(String? id) {
    _toBranchId = id;
    notifyListeners();
  }

  void setNotes(String value) {
    _notes = value;
    notifyListeners();
  }

  void addItem(ProductModel product, {double quantity = 1, double? costPrice}) {
    final price = costPrice ?? product.importPrice;
    final existing = _items.indexWhere((e) => e.productId == product.id);
    if (existing >= 0) {
      final old = _items[existing];
      _items[existing] = old.copyWith(quantity: old.quantity + quantity, costPrice: price);
    } else {
      _items.add(TransferItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        costPrice: price,
      ));
    }
    _errorMessage = null;
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((e) => e.productId == productId);
    notifyListeners();
  }

  void updateItem(String productId, {double? quantity, double? costPrice}) {
    final i = _items.indexWhere((e) => e.productId == productId);
    if (i < 0) return;
    final old = _items[i];
    if (quantity != null && quantity <= 0) {
      _items.removeAt(i);
    } else {
      _items[i] = old.copyWith(
        quantity: quantity ?? old.quantity,
        costPrice: costPrice ?? old.costPrice,
      );
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _toBranchId = null;
    _notes = '';
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> saveTransfer({required bool complete}) async {
    final user = authProvider.user;
    if (user == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }
    final fromId = authProvider.selectedBranchId ?? branchProvider.currentBranchId;
    if (fromId == null || fromId.isEmpty) {
      _errorMessage = 'Chưa chọn chi nhánh gửi';
      notifyListeners();
      return false;
    }
    if (_toBranchId == null || _toBranchId!.isEmpty) {
      _errorMessage = 'Vui lòng chọn chi nhánh nhận';
      notifyListeners();
      return false;
    }
    if (_toBranchId == fromId) {
      _errorMessage = 'Chi nhánh nhận phải khác chi nhánh gửi';
      notifyListeners();
      return false;
    }
    if (_items.isEmpty) {
      _errorMessage = 'Chưa có mặt hàng nào';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final productService = ProductService(isPro: authProvider.isPro, userId: user.uid);
      final transferService = TransferService(
        isPro: authProvider.isPro,
        userId: user.uid,
        productService: productService,
      );
      final transfer = TransferModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromBranchId: fromId,
        toBranchId: _toBranchId!,
        items: _items,
        timestamp: DateTime.now(),
        status: complete ? 'COMPLETED' : 'DRAFT',
        userId: user.uid,
        notes: _notes.isEmpty ? null : _notes,
      );
      await transferService.saveTransfer(transfer);
      _isLoading = false;
      clear();
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
