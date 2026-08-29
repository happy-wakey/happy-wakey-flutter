import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/environment.dart';

void main() {
  test('platform URL has no baked-in public IP default', () {
    expect(Environment.platformUrl, isEmpty);
    expect(Environment.platformUrl, isNot(contains('98.90.186.114')));
    expect(Environment.sharedAuthUrl, isEmpty);
    expect(Environment.gatewayUrl, isEmpty);
  });
}
