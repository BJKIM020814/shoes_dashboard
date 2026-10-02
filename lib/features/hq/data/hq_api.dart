import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HqApiException implements Exception {
  const HqApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class HqApi {
  HqApi._();
  static final HqApi instance = HqApi._();

  // Override with --dart-define=HQ_API_BASE_URL=http://host:8000
  static const _configuredBaseUrl = String.fromEnvironment('HQ_API_BASE_URL');
  String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (kIsWeb ? 'http://192.168.20.68:8000' : 'http://192.168.20.68:8000');

  String? _token;
  String? get token => _token;
  bool get hasToken => _token?.isNotEmpty ?? false;
  void setToken(String value) =>
      _token = value.trim().isEmpty ? null : value.trim();
  void clearToken() => _token = null;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
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
          : jsonDecode(response.body);
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
