/// URL FPT eInvoice theo môi trường (NĐ70/2025)
/// - Test (UAT): api-uat.einvoice.fpt.com.vn
/// - Production: api.einvoice.fpt.com.vn
class EinvoiceUrls {
  // Môi trường Test (UAT)
  static const String testBase = 'https://api-uat.einvoice.fpt.com.vn';
  static const String testCreate = '$testBase/create-icr';
  static const String testSignin = '$testBase/c_signin';
  static const String testSearch = '$testBase/search-icr';
  static const String testReplace = '$testBase/replace-icr';
  static const String testDelete = '$testBase/delete-icr';

  // Môi trường Production (chính thức)
  static const String prodBase = 'https://api.einvoice.fpt.com.vn';
  static const String prodCreate = '$prodBase/create-icr';
  static const String prodSignin = '$prodBase/c_signin';
  static const String prodSearch = '$prodBase/search-icr';
  static const String prodReplace = '$prodBase/replace-icr';
  static const String prodDelete = '$prodBase/delete-icr';

  final bool isTest;
  final String? _base; // Khi set thì dùng base này thay vì test/prod cố định

  EinvoiceUrls({required this.isTest, String? base}) : _base = base;

  String get _baseUrl => _base ?? (isTest ? testBase : prodBase);

  String get createUrl => _base != null ? '$_baseUrl/create-icr' : (isTest ? testCreate : prodCreate);
  String get signinUrl => _base != null ? '$_baseUrl/c_signin' : (isTest ? testSignin : prodSignin);
  String get searchUrl => _base != null ? '$_baseUrl/search-icr' : (isTest ? testSearch : prodSearch);
  String get replaceUrl => _base != null ? '$_baseUrl/replace-icr' : (isTest ? testReplace : prodReplace);
  String get deleteUrl => _base != null ? '$_baseUrl/delete-icr' : (isTest ? testDelete : prodDelete);

  /// Tạo URL từ base đã cấu hình trong Cài đặt shop (ưu tiên link chính thức/user cấu hình).
  /// [baseUrl] có thể là "https://api.einvoice.fpt.com.vn/create-icr" hoặc "https://api.einvoice.fpt.com.vn".
  static EinvoiceUrls fromBaseUrl(String baseUrl) {
    String base = baseUrl.trim();
    if (base.isEmpty) return EinvoiceUrls(isTest: false);
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.endsWith('/create-icr')) base = base.substring(0, base.length - '/create-icr'.length);
    return EinvoiceUrls(isTest: false, base: base);
  }
}
