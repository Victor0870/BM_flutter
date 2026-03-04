import 'package:dio/dio.dart';

/// Endpoint lấy Access Token (OAuth2 client_credentials).
const String kKiotVietTokenUrl = 'https://id.kiotviet.vn/connect/token';
/// Endpoint danh sách chi nhánh.
const String kKiotVietBranchesUrl = 'https://public.kiotapi.com/branches';

/// Kết quả đăng nhập KiotViet: token + danh sách chi nhánh.
class KiotVietAuthResult {
  final String accessToken;
  final List<KiotVietBranch> branches;

  KiotVietAuthResult({required this.accessToken, required this.branches});
}

/// Một chi nhánh KiotViet (id, tên, mã).
class KiotVietBranch {
  final int id;
  final String name;
  final String code;

  KiotVietBranch({
    required this.id,
    required this.name,
    required this.code,
  });

  factory KiotVietBranch.fromMap(Map<String, dynamic> map) {
    final id = map['id'] is int ? map['id'] as int : (map['id'] as num?)?.toInt() ?? 0;
    return KiotVietBranch(
      id: id,
      name: map['branchName']?.toString() ?? map['name']?.toString() ?? '',
      code: map['branchCode']?.toString() ?? map['code']?.toString() ?? '',
    );
  }
}

/// Service đăng nhập KiotViet (lấy token) và lấy danh sách chi nhánh.
/// Dùng Client ID + Client Secret đã lưu trong Cài đặt (liên kết KiotViet).
class KiotVietAuthService {
  final Dio _dio = Dio();

  /// Chuẩn hóa tên gian hàng dùng làm header Retailer (ví dụ: "Cửa hàng ABC" -> "cua-hang-abc").
  /// KiotViet thường dùng dạng không dấu, lowercase; nếu API trả lỗi Retailer thì cần nhập đúng tên gian hàng trong Cài đặt.
  static String normalizeRetailer(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Lấy Access Token từ Client ID + Client Secret.
  Future<String> getAccessToken({
    required String clientId,
    required String clientSecret,
  }) async {
    final body = 'scopes=PublicApi.Access&grant_type=client_credentials'
        '&client_id=${Uri.encodeComponent(clientId)}'
        '&client_secret=${Uri.encodeComponent(clientSecret)}';
    final response = await _dio.post<Map<String, dynamic>>(
      kKiotVietTokenUrl,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
      data: body,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Token response invalid');
    }
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception(data['error']?.toString() ?? 'Không lấy được Access Token');
    }
    return token;
  }

  /// Lấy danh sách chi nhánh (cần token + retailer).
  Future<List<KiotVietBranch>> getBranches({
    required String retailer,
    required String accessToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      kKiotVietBranchesUrl,
      queryParameters: {'pageSize': 100, 'currentItem': 0},
      options: Options(
        headers: {
          'Retailer': retailer,
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    final body = response.data;
    if (body == null || body['data'] == null) return [];
    final data = body['data'];
    if (data is! List) return [];
    return data
        .map((e) => KiotVietBranch.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((b) => b.name.isNotEmpty)
        .toList();
  }

  /// Đăng nhập KiotViet và lấy token + danh sách chi nhánh.
  /// [retailer] thường lấy từ tên cửa hàng đã chuẩn hóa (normalizeRetailer(shop.name)).
  Future<KiotVietAuthResult> login({
    required String clientId,
    required String clientSecret,
    required String retailer,
  }) async {
    final token = await getAccessToken(clientId: clientId, clientSecret: clientSecret);
    final branches = await getBranches(retailer: retailer, accessToken: token);
    return KiotVietAuthResult(accessToken: token, branches: branches);
  }
}
