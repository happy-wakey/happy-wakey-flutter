import 'dart:convert';

import 'package:http/http.dart' as http;

final class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);
  static const _maxResponseBytes = 2 * 1024 * 1024;

  final http.Client _client;

  Future<Object?> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
    String service = 'Service',
  }) => _sendJson('GET', uri, headers: headers, service: service);

  Future<Object?> postJson(
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    String service = 'Service',
  }) => _sendJson('POST', uri, headers: headers, body: body, service: service);

  Future<Object?> putJson(
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    String service = 'Service',
  }) => _sendJson('PUT', uri, headers: headers, body: body, service: service);

  Future<Object?> _sendJson(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Object? body,
    required String service,
  }) async {
    if (!_safeEndpoint(uri)) {
      throw ApiException('$service endpoint must use HTTPS');
    }
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'happy-wakey-flutter/1.0',
        ...headers,
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client.send(request).timeout(_timeout);
      final bytes = await response.stream
          .fold<List<int>>(<int>[], (buffer, chunk) {
            if (buffer.length + chunk.length > _maxResponseBytes) {
              throw const ApiException(
                'Response exceeded the 2 MiB safety limit',
              );
            }
            return buffer..addAll(chunk);
          })
          .timeout(_timeout);
      final text = utf8.decode(bytes, allowMalformed: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          '$service returned HTTP ${response.statusCode}: ${_errorText(text)}',
        );
      }
      if (text.trim().isEmpty) return null;
      return jsonDecode(text);
    } on ApiException {
      rethrow;
    } on FormatException {
      throw ApiException('$service returned invalid JSON');
    } catch (error) {
      throw ApiException('$service request failed: $error');
    }
  }

  bool _safeEndpoint(Uri uri) =>
      uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          const {
            'localhost',
            '127.0.0.1',
            '::1',
          }.contains(uri.host.toLowerCase()));

  String _errorText(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    if (cleaned.isEmpty) return 'empty response';
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        for (final key in const [
          'message',
          'error_description',
          'error',
          'detail',
        ]) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return _bounded(value.trim());
          }
        }
      }
    } on FormatException {
      // Use bounded plain text below.
    }
    return _bounded(cleaned);
  }

  String _bounded(String value) =>
      value.length <= 320 ? value : '${value.substring(0, 320)}…';
}
