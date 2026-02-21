import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../controllers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../utils/platform_utils.dart';

// Tài khoản thử nghiệm Google AdMob (test ad unit IDs).
// Khi phát hành production: thay bằng Ad Unit ID thật từ AdMob console.
// Android test: ca-app-pub-3940256099942544/6300978111
// iOS test: ca-app-pub-3940256099942544/2934735716
const String _kAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
const String _kAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';

/// Widget hiển thị banner quảng cáo AdMob (chỉ Mobile: Android/iOS).
/// - Trên Desktop/Web: trả về [SizedBox.shrink()] (dùng [isMobilePlatform]).
/// - Logic hiển thị (system_settings/isTest):
///   + isTest == true  → hiển thị quảng cáo với TẤT CẢ tài khoản (phục vụ kiểm thử).
///   + isTest == false → chỉ hiển thị quảng cáo ở tài khoản FREE (!isPro); tài khoản PRO không thấy quảng cáo.
/// - Chỉ render banner khi quảng cáo đã load xong (onAdLoaded) để giao diện mượt.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final FirebaseService _firebaseService = FirebaseService();
  AuthProvider? _authProvider; // Lưu để removeListener trong dispose

  bool _configLoaded = false;
  bool _isTestMode = false; // Lưu từ system_settings/isTest
  bool _shouldShowAd = false;
  bool _adLoaded = false;
  BannerAd? _bannerAd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isMobilePlatform) return;
    if (!_configLoaded) {
      _configLoaded = true;
      _loadConfigAndAd();
    } else {
      // Khi auth thay đổi (vd. nâng cấp PRO): cập nhật lại có hiển thị quảng cáo hay không
      _updateShouldShowFromAuth();
    }
  }

  /// Cập nhật _shouldShowAd theo isTest và isPro (gọi khi AuthProvider thay đổi).
  void _updateShouldShowFromAuth() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final isPro = authProvider.isPro;
    final shouldShow = _isTestMode || !isPro;
    if (_shouldShowAd != shouldShow && mounted) {
      setState(() {
        _shouldShowAd = shouldShow;
        if (!shouldShow) {
          _adLoaded = false;
          _bannerAd?.dispose();
          _bannerAd = null;
        }
      });
      if (shouldShow) _loadBannerAd();
    }
  }

  Future<void> _loadConfigAndAd() async {
    if (!mounted || !isMobilePlatform) return;

    final isTest = await _firebaseService.getIsTestMode();
    if (!mounted) return;

    _isTestMode = isTest;
    final authProvider = context.read<AuthProvider>();
    final isPro = authProvider.isPro;

    // isTest == true: hiển thị quảng cáo với tất cả tài khoản (kiểm thử)
    // isTest == false: chỉ hiển thị ở tài khoản free (!isPro)
    final shouldShow = isTest || !isPro;

    if (!mounted) return;
    setState(() => _shouldShowAd = shouldShow);

    if (!shouldShow) return;
    _authProvider = authProvider;
    authProvider.addListener(_updateShouldShowFromAuth);
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (!mounted || !isMobilePlatform || !_shouldShowAd) return;

    final adUnitId = Platform.isAndroid ? _kAdUnitIdAndroid : _kAdUnitIdIOS;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (kDebugMode) debugPrint('AdBannerWidget: onAdLoaded');
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (kDebugMode) {
            debugPrint('AdBannerWidget: onAdFailedToLoad ${error.message}');
          }
          ad.dispose();
          if (mounted) {
            setState(() {
              _adLoaded = false;
              if (_bannerAd == ad) {
                _bannerAd = null;
              }
            });
          }
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_updateShouldShowFromAuth);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ hiển thị trên Mobile (Android/iOS); Desktop/Web ẩn hoàn toàn
    if (!isMobilePlatform) {
      return const SizedBox.shrink();
    }

    // Chưa load xong config hoặc không được phép hiển thị
    if (!_shouldShowAd) {
      return const SizedBox.shrink();
    }

    // Chỉ hiển thị khi quảng cáo đã load xong để giao diện mượt
    if (!_adLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // AdSize.banner = 320x50; không thêm padding/margin
    final w = _bannerAd!.size.width.toDouble();
    final h = _bannerAd!.size.height.toDouble();
    return SizedBox(
      width: w,
      height: h,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
