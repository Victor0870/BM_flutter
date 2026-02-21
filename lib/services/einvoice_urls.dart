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

  // Môi trường Production
  static const String prodBase = 'https://api.einvoice.fpt.com.vn';
  static const String prodCreate = '$prodBase/create-icr';
  static const String prodSignin = '$prodBase/c_signin';
  static const String prodSearch = '$prodBase/search-icr';
  static const String prodReplace = '$prodBase/replace-icr';
  static const String prodDelete = '$prodBase/delete-icr';

  final bool isTest;

  EinvoiceUrls({required this.isTest});

  String get createUrl => isTest ? testCreate : prodCreate;
  String get signinUrl => isTest ? testSignin : prodSignin;
  String get searchUrl => isTest ? testSearch : prodSearch;
  String get replaceUrl => isTest ? testReplace : prodReplace;
  String get deleteUrl => isTest ? testDelete : prodDelete;
}
