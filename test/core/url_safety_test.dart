import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/url_safety.dart';

void main() {
  test('accepts https names and loopback http', () {
    expect(
      UrlSafety.isSafeHttpUri(Uri.parse('https://example.com/path')),
      isTrue,
    );
    expect(
      UrlSafety.isSafeHttpUri(Uri.parse('http://127.0.0.1:8128/')),
      isTrue,
    );
    expect(UrlSafety.isSafeHttpUri(Uri.parse('http://localhost/')), isTrue);
  });

  test('rejects cleartext internet, credentials, and public IP literals', () {
    expect(UrlSafety.isSafeHttpUri(Uri.parse('http://example.com')), isFalse);
    expect(
      UrlSafety.isSafeHttpUri(Uri.parse('https://user:pass@example.com')),
      isFalse,
    );
    expect(
      UrlSafety.isSafeHttpUri(Uri.parse('https://98.90.186.114')),
      isFalse,
    );
    expect(UrlSafety.isSafeHttpUri(Uri.parse('javascript:alert(1)')), isFalse);
    expect(UrlSafety.isSafeHttpUri(Uri.parse('file:///etc/passwd')), isFalse);
  });
}
