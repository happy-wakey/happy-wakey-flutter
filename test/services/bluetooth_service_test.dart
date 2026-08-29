import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/services/bluetooth_service.dart';

void main() {
  test('preview command is versioned, bounded, and credential free', () {
    final bytes = encodePreviewAlarmCommand(
      '018f5cc6-6d8b-7b2a-9f38-269e6a7b1f11',
    );
    expect(bytes.length, lessThanOrEqualTo(512));
    final value = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    expect(value['schema'], 'happy-wakey.ble.preview-command.v1');
    expect(value['action'], 'preview_alarm');
    expect(value['duration_ms'], 3000);
    expect(value, isNot(contains('token')));
    expect(value, isNot(contains('subject')));
    expect(value, isNot(contains('owner_id')));
  });

  test('preview command lowercases a valid UUID and rejects empty ids', () {
    final bytes = encodePreviewAlarmCommand(
      '018F5CC6-6D8B-7B2A-9F38-269E6A7B1F11',
    );
    final value = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    expect(value['operation_id'], '018f5cc6-6d8b-7b2a-9f38-269e6a7b1f11');
    expect(() => encodePreviewAlarmCommand(''), throwsFormatException);
    expect(
      () => encodePreviewAlarmCommand('018f5cc6-6d8b-7b2a-9f38-269e6a7b1f1'),
      throwsFormatException,
    );
  });

  test('preview command rejects malformed operation identifiers', () {
    expect(
      () => encodePreviewAlarmCommand('not-an-operation-id'),
      throwsFormatException,
    );
  });
}
