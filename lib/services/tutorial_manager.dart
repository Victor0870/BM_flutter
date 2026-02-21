import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_db_service.dart';

/// Keys lưu trữ trạng thái tutorial (dùng cả LocalDbService và SharedPreferences fallback).
const String kKeyHasSeenWelcomePopup = 'has_seen_welcome_popup';
const String kKeyHasCompletedOverviewTour = 'has_completed_overview_tour';

/// Service quản lý trạng thái tutorial: đọc/ghi flags, tách biệt logic khỏi UI.
/// Ưu tiên LocalDbService (SQLite); trên web dùng SharedPreferences.
class TutorialManager {
  static final TutorialManager _instance = TutorialManager._internal();
  factory TutorialManager() => _instance;
  TutorialManager._internal();

  final LocalDbService _localDb = LocalDbService();
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Đã xem popup chào mừng chưa.
  Future<bool> getHasSeenWelcomePopup() async {
    if (!kIsWeb) {
      try {
        final v = await _localDb.getAppPref(kKeyHasSeenWelcomePopup);
        return v == '1';
      } catch (e) {
        if (kDebugMode) debugPrint('TutorialManager: LocalDb get failed, using SharedPreferences: $e');
      }
    }
    final prefs = await _getPrefs();
    return prefs.getBool(kKeyHasSeenWelcomePopup) ?? false;
  }

  /// Đánh dấu đã xem popup chào mừng.
  Future<void> setHasSeenWelcomePopup(bool value) async {
    if (!kIsWeb) {
      try {
        await _localDb.setAppPref(kKeyHasSeenWelcomePopup, value ? '1' : '0');
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('TutorialManager: LocalDb set failed: $e');
      }
    }
    final prefs = await _getPrefs();
    await prefs.setBool(kKeyHasSeenWelcomePopup, value);
  }

  /// Đã hoàn thành tour tổng quan (Giai đoạn 1) chưa.
  Future<bool> getHasCompletedOverviewTour() async {
    if (!kIsWeb) {
      try {
        final v = await _localDb.getAppPref(kKeyHasCompletedOverviewTour);
        return v == '1';
      } catch (e) {
        if (kDebugMode) debugPrint('TutorialManager: LocalDb get failed: $e');
      }
    }
    final prefs = await _getPrefs();
    return prefs.getBool(kKeyHasCompletedOverviewTour) ?? false;
  }

  /// Đánh dấu đã hoàn thành tour tổng quan.
  Future<void> setHasCompletedOverviewTour(bool value) async {
    if (!kIsWeb) {
      try {
        await _localDb.setAppPref(kKeyHasCompletedOverviewTour, value ? '1' : '0');
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('TutorialManager: LocalDb set failed: $e');
      }
    }
    final prefs = await _getPrefs();
    await prefs.setBool(kKeyHasCompletedOverviewTour, value);
  }
}
