import 'dart:convert';
import 'package:http/http.dart' as http;

/// 가맹점 FastAPI(python/store_api) 호출 클라이언트.
/// 주소/매장은 실행할 때 --dart-define 으로 바꾼다.
///   flutter run --dart-define=STORE_API_BASE=http://192.168.0.10:8100 --dart-define=STORE_DEALER_SEQ=1
class StoreApi {
  StoreApi._();
  static final instance = StoreApi._();

  static const _base = String.fromEnvironment(
    'STORE_API_BASE',
    defaultValue: 'http://localhost:8100',
  );
  static const dealerSeq = int.fromEnvironment(
    'STORE_DEALER_SEQ',
    defaultValue: 1,
  );
  static const _apiKey = String.fromEnvironment('STORE_API_KEY');

  /// 수령/반품 처리자(Firebase employeeId). 비어 있으면 처리할 때 한 번 물어본다.
  String staffId = const String.fromEnvironment('STORE_STAFF_ID');

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse(
      '$_base/api/store/$dealerSeq$path',
    ).replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
  };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const StoreApiException('서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해 주세요.');
    }
    final body = utf8.decode(res.bodyBytes);
    final data = body.isEmpty ? null : jsonDecode(body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    var message = '요청에 실패했습니다. (${res.statusCode})';
    if (data is Map && data['detail'] is String) {
      message = data['detail'] as String;
    } else if (res.statusCode == 422) {
      message = '입력값을 확인해 주세요.';
    }
    throw StoreApiException(message, res.statusCode);
  }

  Future<dynamic> get(String path, [Map<String, String?>? query]) =>
      _send(() => http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
    () => http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(
    () => http.put(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  // ---- 화면별 호출 ----
  Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from(await get('/dashboard'));

  Future<Map<String, dynamic>> verifyPickup({String? qr, String? code}) async =>
      Map<String, dynamic>.from(
        await post('/pickups/verify', {
          if (qr != null) 'qr': qr,
          if (code != null) 'code': code,
        }),
      );

  Future<Map<String, dynamic>> confirmPickup({
    String? qr,
    String? code,
    required String staffId,
  }) async => Map<String, dynamic>.from(
    await post('/pickups/confirm', {
      if (qr != null) 'qr': qr,
      if (code != null) 'code': code,
      'staff_id': staffId,
    }),
  );

  Future<List<Map<String, dynamic>>> list(
    String path, [
    Map<String, String?>? query,
  ]) async => _asList(await get(path, query));

  Future<Map<String, dynamic>> map(
    String path, [
    Map<String, String?>? query,
  ]) async => Map<String, dynamic>.from(await get(path, query));

  static List<Map<String, dynamic>> _asList(dynamic v) =>
      (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class StoreApiException implements Exception {
  const StoreApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
