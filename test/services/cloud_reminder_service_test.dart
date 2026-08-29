import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/models/models.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:happy_wakey/src/services/cloud_reminder_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('cloud reminders fail closed when the platform URL is unset', () async {
    var called = false;
    final service = CloudReminderService(
      ApiClient(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      ),
    );
    await expectLater(
      service.sync(
        supabaseAccessToken: 'supabase-access-token',
        events: const [],
        settings: const ReminderSettings(cloudEmailEnabled: true),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(called, isFalse);
  });
}
