import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class HqApiException implements Exception {
  const HqApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class HqApi {
  HqApi({http.Client? client}) : _client = client ?? http.Client();
  static final HqApi instance = HqApi();
  final http.Client _client;

  // Override with --dart-define=HQ_API_BASE_URL=http://host:8000
  static const _configuredBaseUrl = String.fromEnvironment('HQ_API_BASE_URL');
  String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'http://192.168.20.68:8000';

  String? _token;
  String? get token => _token;
  bool get hasToken => _token?.isNotEmpty ?? false;
  void setToken(String value) =>
      _token = value.trim().isEmpty ? null : value.trim();
  void clearToken() => _token = null;

  Future<void> login(String email, String password) async {
    clearToken();
    final session = await post(
      '/api/login',
      body: {'email': email.trim(), 'password': password},
    );
    final token = session['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const HqApiException('로그인 서버의 세션 형식이 올바르지 않습니다.');
    }
    setToken(token);
    try {
      // The server resolves employee permissions from the authenticated account.
      await get('/api/v1/headquarters/orders', query: {'limit': '1'});
    } catch (_) {
      clearToken();
      rethrow;
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw HqApiException('서버 응답 시간이 초과되었습니다. 연결 주소: $baseUrl');
    } on http.ClientException catch (error) {
      throw HqApiException(
        '서버에 연결할 수 없습니다. 같은 네트워크와 연결 주소를 확인하세요: $baseUrl (${error.message})',
      );
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _send(() => _client.get(uri, headers: _headers()));
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      () => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Map<String, String> _headers() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (hasToken) 'Authorization': 'Bearer $_token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    dynamic payload;
    try {
      payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      payload = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload is Map ? payload['detail'] : null;
      final message = detail is String
          ? detail
          : detail is Map
          ? detail['message']?.toString()
          : null;
      throw HqApiException(
        message ?? '서버 요청에 실패했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (payload is! Map<String, dynamic>) {
      throw const HqApiException('서버 응답 형식이 올바르지 않습니다.');
    }
    return payload;
  }
}
