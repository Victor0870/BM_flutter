import 'package:dio/dio.dart';

/// Base URL KiotViet Public API (tài liệu 2.4).
const String kKiotVietProductsUrl = 'https://public.kiotapi.com/products';

/// Client gọi KiotViet Public API (2.4 Hàng hóa).
/// Header: Retailer (tên gian hàng), Authorization: Bearer {Access Token}.
abstract class KiotVietApiClient {
  /// Lấy danh sách hàng hóa. Nếu [lastModifiedFrom] khác null thì chỉ lấy bản ghi cập nhật sau thời điểm đó (tối ưu sync).
  /// Trả về data[] từ response (`List<Map<String, dynamic>>`).
  Future<List<Map<String, dynamic>>> fetchProducts({
    DateTime? lastModifiedFrom,
    int pageSize = 100,
    int currentItem = 0,
    bool includeInventory = true,
  });
}

/// Implementation dùng Dio. Cần [retailer] (tên gian hàng) và [accessToken] (Bearer token).
class KiotVietApiClientImpl implements KiotVietApiClient {
  final Dio dio;
  final String retailer;
  final String accessToken;

  KiotVietApiClientImpl({
    required this.retailer,
    required this.accessToken,
    Dio? dio,
  }) : dio = dio ?? Dio();

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    DateTime? lastModifiedFrom,
    int pageSize = 100,
    int currentItem = 0,
    bool includeInventory = true,
  }) async {
    final query = <String, dynamic>{
      'pageSize': pageSize,
      'currentItem': currentItem,
      'includeInventory': includeInventory,
    };
    if (lastModifiedFrom != null) {
      query['lastModifiedFrom'] = lastModifiedFrom.toUtc().toIso8601String();
    }

    final response = await dio.get<Map<String, dynamic>>(
      kKiotVietProductsUrl,
      queryParameters: query,
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
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
