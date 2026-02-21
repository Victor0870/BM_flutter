import 'package:flutter/material.dart';
import '../services/tutorial_manager.dart';

/// GlobalKeys dùng cho Tutorial — chỉ giữ key dùng ở một nơi (scaffold/settings).
/// Key cho quick actions dashboard được tạo theo từng HomeScreen để tránh lỗi "Multiple widgets used the same GlobalKey".
class TutorialKeys {
  TutorialKeys._();
  static final TutorialKeys instance = TutorialKeys._();

  /// Bottom nav / drawer "Cài đặt" (MainScaffoldMobile).
  final GlobalKey keyQuickActionSettings = GlobalKey();

  /// Desktop: nút "BÁN HÀNG NGAY" trên header
  final GlobalKey keyDesktopSalesButton = GlobalKey();

  /// ShopSettingsScreen: mục "Hướng dẫn sử dụng"
  final GlobalKey keySettingsGuideTile = GlobalKey();
}

/// Provider quản lý trạng thái tutorial (popup chào mừng, tour, chế độ sandbox).
class TutorialProvider with ChangeNotifier {
  TutorialProvider() {
    _loadFlags();
  }

  final TutorialManager _manager = TutorialManager();

  bool _hasSeenWelcomePopup = false;
  bool _hasCompletedOverviewTour = false;
  bool _isTutorialMode = false;
  bool _shouldRunPhase1Tour = false;
  bool _shouldHighlightGuideInSettings = false;
  bool _flagsLoaded = false;

  bool get hasSeenWelcomePopup => _hasSeenWelcomePopup;
  bool get hasCompletedOverviewTour => _hasCompletedOverviewTour;
  bool get isTutorialMode => _isTutorialMode;
  bool get shouldRunPhase1Tour => _shouldRunPhase1Tour;
  bool get shouldHighlightGuideInSettings => _shouldHighlightGuideInSettings;
  bool get flagsLoaded => _flagsLoaded;

  Future<void> _loadFlags() async {
    _hasSeenWelcomePopup = await _manager.getHasSeenWelcomePopup();
    _hasCompletedOverviewTour = await _manager.getHasCompletedOverviewTour();
    _flagsLoaded = true;
    notifyListeners();
  }

  Future<void> setHasSeenWelcomePopup(bool value) async {
    await _manager.setHasSeenWelcomePopup(value);
    _hasSeenWelcomePopup = value;
    notifyListeners();
  }

  Future<void> setHasCompletedOverviewTour(bool value) async {
    await _manager.setHasCompletedOverviewTour(value);
    _hasCompletedOverviewTour = value;
    notifyListeners();
  }

  void setTutorialMode(bool value) {
    _isTutorialMode = value;
    notifyListeners();
  }

  void requestPhase1Tour() {
    _shouldRunPhase1Tour = true;
    notifyListeners();
  }

  void clearPhase1TourRequest() {
    _shouldRunPhase1Tour = false;
    notifyListeners();
  }

  void requestHighlightGuideInSettings() {
    _shouldHighlightGuideInSettings = true;
    notifyListeners();
  }

  void clearHighlightGuideInSettings() {
    _shouldHighlightGuideInSettings = false;
    notifyListeners();
  }

  /// Gọi khi user bấm target "Cài đặt" ở Phase 1 — MainScaffold gán callback để chuyển tab/màn hình sang Cài đặt.
  void Function()? navigateToShopSettingsCallback;
}
