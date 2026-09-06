import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/models/models.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:happy_wakey/src/services/direct_message_service.dart';
import 'package:happy_wakey/src/services/inbox_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Gmail inbox is bounded, ranked, and linked to the message', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer gmail-token');
        if (request.url.path.endsWith('/messages')) {
          expect(request.url.queryParameters['maxResults'], '20');
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 'm1'},
                {'id': 'm2'},
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/m1')) {
          return http.Response(
            jsonEncode({
              'internalDate': '1778061600000',
              'labelIds': ['INBOX', 'UNREAD', 'IMPORTANT'],
              'snippet': 'Please review this before stand-up',
              'payload': {
                'headers': [
                  {'name': 'From', 'value': 'Ada <ada@example.com>'},
                  {'name': 'Subject', 'value': 'Important morning brief'},
                  {'name': 'Date', 'value': 'Mon, 5 May 2026 08:00:00 GMT'},
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'internalDate': '1777975200000',
            'labelIds': ['INBOX', 'UNREAD'],
            'snippet': 'A less urgent note',
            'payload': {
              'headers': [
                {'name': 'From', 'value': 'Grace <grace@example.com>'},
                {'name': 'Subject', 'value': 'Note'},
                {'name': 'Date', 'value': 'Sun, 4 May 2026 08:00:00 GMT'},
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await InboxService(
      api,
    ).fetch(provider: 'google', providerToken: 'gmail-token');
    expect(result, hasLength(2));
    expect(result.first.id, 'm1');
    expect(result.first.important, isTrue);
    expect(result.first.url?.fragment, 'inbox/m1');
    expect(result.first.senderAddress, 'ada@example.com');
  });

  test(
    'Microsoft inbox normalizes importance and rejects unsafe links',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.host, 'graph.microsoft.com');
          expect(request.url.queryParameters[r'$top'], '20');
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'outlook-1',
                  'subject': 'Action required',
                  'from': {
                    'emailAddress': {
                      'name': 'Taylor',
                      'address': 't@example.com',
                    },
                  },
                  'receivedDateTime': '2026-05-05T08:00:00Z',
                  'bodyPreview': 'Bounded preview',
                  'isRead': false,
                  'importance': 'high',
                  'webLink': 'javascript:alert(1)',
                },
              ],
            }),
            200,
          );
        }),
      );
      final result = await InboxService(
        api,
      ).fetch(provider: 'azure', providerToken: 'graph-token');
      expect(result.single.important, isTrue);
      expect(result.single.url, isNull);
      expect(result.single.senderName, 'Taylor');
    },
  );

  test(
    'direct-message gateway deduplicates, bounds, and guards URLs',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/briefing/direct-messages');
          expect(request.headers['Authorization'], 'Bearer supabase-token');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'dm-1',
                  'source': 'slack',
                  'conversation': 'Morning room',
                  'senderName': 'Morgan',
                  'preview': 'x' * 500,
                  'receivedAt': '2026-05-05T09:00:00Z',
                  'unread': true,
                  'url': 'https://slack.com/archives/C1/p1',
                },
                {
                  'id': 'dm-1',
                  'source': 'slack',
                  'receivedAt': '2026-05-05T08:00:00Z',
                },
                {
                  'id': 'dm-2',
                  'source': 'discord',
                  'receivedAt': '2026-05-05T07:00:00Z',
                  'url': 'file:///private/message',
                },
              ],
            }),
            200,
          );
        }),
      );
      final result = await DirectMessageService(
        api,
        baseUrl: 'https://gateway.example.com',
      ).fetch(accessToken: 'supabase-token');
      expect(result, hasLength(2));
      expect(result.first.id, 'dm-1');
      expect(result.first.preview.length, lessThanOrEqualTo(321));
      expect(result.first.url, isNotNull);
      expect(result.last.url, isNull);
    },
  );

  test(
    'direct-message gateway fails closed before I/O for unsafe bases',
    () async {
      var called = false;
      final service = DirectMessageService(
        ApiClient(
          client: MockClient((_) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
        baseUrl: 'http://public.example.com',
      );
      await expectLater(
        service.fetch(accessToken: 'supabase-token'),
        throwsA(isA<ApiException>()),
      );
      expect(called, isFalse);
    },
  );

  test('sleep summary and morning briefing expose bounded counts', () {
    final sleep = SleepSummary(
      date: DateTime(2026, 5, 5),
      durationMinutes: 7 * 60 + 30,
      deepMinutes: 90,
      remMinutes: 110,
      awakeMinutes: 25,
      source: 'health_connect',
    );
    final briefing = MorningBriefing(
      generatedAt: DateTime(2026, 5, 5),
      inbox: [
        InboxItem(
          id: 'mail',
          source: 'gmail',
          senderName: 'A',
          senderAddress: 'a@example.com',
          subject: 'Subject',
          preview: 'Preview',
          receivedAt: DateTime(2026, 5, 5),
          unread: true,
          important: true,
        ),
      ],
      directMessages: [
        DirectMessage(
          id: 'dm',
          source: 'slack',
          conversation: 'Room',
          senderName: 'B',
          preview: 'Hello',
          receivedAt: DateTime(2026, 5, 5),
          unread: false,
        ),
      ],
      health: HealthSnapshot(
        supported: true,
        authorized: true,
        message: 'ok',
        metrics: const [],
        source: 'health_connect',
        sleep: sleep,
      ),
    );
    expect(sleep.durationLabel, '7h 30m');
    expect(briefing.unreadInboxCount, 1);
    expect(briefing.unreadMessageCount, 0);
  });
}
