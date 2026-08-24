import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'API client rejects insecure non-loopback endpoints before I/O',
    () async {
      var called = false;
      final client = ApiClient(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.getJson(Uri.parse('http://example.com/data')),
        throwsA(isA<ApiException>()),
      );
      expect(called, isFalse);
    },
  );

  test('API client accepts bounded HTTPS JSON and applies headers', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['X-Test'], 'safe');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    expect(
      await client.getJson(
        Uri.parse('https://example.com/data'),
        headers: const {'X-Test': 'safe'},
      ),
      {'ok': true},
    );
  });

  test('API errors are bounded and control characters are removed', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': '${'x' * 400}\u0000'}), 429),
      ),
    );
    await expectLater(
      client.getJson(Uri.parse('https://example.com/data'), service: 'Example'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message.length,
          'bounded message length',
          lessThan(380),
        ),
      ),
    );
  });
}
