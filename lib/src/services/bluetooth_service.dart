import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:universal_ble/universal_ble.dart';

const happyWakeyBleServiceUuid = '8e0e0001-7d5a-4c3f-9c31-94e9d447fc01';
const happyWakeyBleCommandUuid = '8e0e0002-7d5a-4c3f-9c31-94e9d447fc01';
const _maximumCommandBytes = 512;

final class HappyWakeyBleDevice {
  const HappyWakeyBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int? rssi;
}

abstract interface class HappyWakeyBluetoothService {
  String? get connectedDeviceId;

  Future<bool> isSupported();
  Future<List<HappyWakeyBleDevice>> scan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> sendPreviewAlarm();
  Future<void> close();
}

final class UniversalHappyWakeyBluetoothService
    implements HappyWakeyBluetoothService {
  final Map<String, BleDevice> _devices = {};
  BleDevice? _connected;
  BleCharacteristic? _command;

  @override
  String? get connectedDeviceId => _connected?.deviceId;

  @override
  Future<bool> isSupported() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state != AvailabilityState.unsupported;
  }

  @override
  Future<List<HappyWakeyBleDevice>> scan() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.unsupported) {
      throw StateError('Bluetooth Low Energy is unsupported on this device');
    }
    if (state == AvailabilityState.unauthorized) {
      throw StateError('Bluetooth access is not authorized');
    }
    if (state != AvailabilityState.poweredOn) {
      throw StateError('Turn Bluetooth on before scanning');
    }

    await UniversalBle.requestPermissions(withAndroidFineLocation: false);
    final results = <String, HappyWakeyBleDevice>{};
    final subscription = UniversalBle.scanStream.listen((device) {
      if (!_advertisesHappyWakey(device)) return;
      _devices[device.deviceId] = device;
      final name = device.name?.trim();
      results[device.deviceId] = HappyWakeyBleDevice(
        id: device.deviceId,
        name: name == null || name.isEmpty ? 'Happy Wakey device' : name,
        rssi: device.rssi,
      );
    });
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [happyWakeyBleServiceUuid]),
      );
      await Future<void>.delayed(const Duration(seconds: 4));
    } finally {
      try {
        await UniversalBle.stopScan();
      } finally {
        await subscription.cancel();
      }
    }
    final devices = results.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return devices;
  }

  @override
  Future<void> connect(String deviceId) async {
    _validateDeviceId(deviceId);
    final device = _devices[deviceId];
    if (device == null) {
      throw StateError(
        'Bluetooth device is no longer discoverable; scan again',
      );
    }
    if (_connected?.deviceId == deviceId && _command != null) return;
    await disconnect();
    await device.connect(timeout: const Duration(seconds: 8));
    try {
      final services = await device.discoverServices(
        timeout: const Duration(seconds: 8),
      );
      final service = services.firstWhere(
        (candidate) => BleUuidParser.compareStrings(
          candidate.uuid,
          happyWakeyBleServiceUuid,
        ),
        orElse: () => throw StateError(
          'Connected peripheral does not implement the Happy Wakey BLE service',
        ),
      );
      final command = service.getCharacteristic(happyWakeyBleCommandUuid);
      if (!command.properties.contains(CharacteristicProperty.write)) {
        throw StateError(
          'Happy Wakey command characteristic is unavailable or not writable',
        );
      }
      _connected = device;
      _command = command;
    } catch (_) {
      await device.disconnect(timeout: const Duration(seconds: 5));
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final device = _connected;
    _connected = null;
    _command = null;
    if (device != null) {
      await device.disconnect(timeout: const Duration(seconds: 5));
    }
  }

  @override
  Future<void> sendPreviewAlarm() async {
    final command = _command;
    if (_connected == null || command == null) {
      throw StateError('Connect a Happy Wakey device first');
    }
    await command.write(
      encodePreviewAlarmCommand(_newOperationId()),
      withResponse: true,
      timeout: const Duration(seconds: 8),
    );
  }

  @override
  Future<void> close() async {
    try {
      await disconnect();
    } catch (_) {
      // App teardown is best effort; no new state can be committed afterward.
    }
  }
}

final class UnavailableHappyWakeyBluetoothService
    implements HappyWakeyBluetoothService {
  const UnavailableHappyWakeyBluetoothService();

  @override
  String? get connectedDeviceId => null;

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<List<HappyWakeyBleDevice>> scan() async => const [];

  @override
  Future<void> connect(String deviceId) async {
    throw UnsupportedError('Bluetooth Low Energy is unavailable');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendPreviewAlarm() async {
    throw UnsupportedError('Bluetooth Low Energy is unavailable');
  }

  @override
  Future<void> close() async {}
}

List<int> encodePreviewAlarmCommand(String operationId) {
  if (!_uuidPattern.hasMatch(operationId)) {
    throw FormatException('Bluetooth operation identifier must be a UUID');
  }
  final payload = utf8.encode(
    jsonEncode({
      'schema': 'happy-wakey.ble.preview-command.v1',
      'operation_id': operationId.toLowerCase(),
      'action': 'preview_alarm',
      'duration_ms': 3000,
    }),
  );
  if (payload.length > _maximumCommandBytes) {
    throw StateError('Bluetooth command exceeded its byte limit');
  }
  return payload;
}

bool _advertisesHappyWakey(BleDevice device) => device.services.any(
  (service) => BleUuidParser.compareStrings(service, happyWakeyBleServiceUuid),
);

void _validateDeviceId(String deviceId) {
  if (deviceId.isEmpty ||
      deviceId.length > 256 ||
      deviceId.trim() != deviceId ||
      deviceId.runes.any((value) => value < 0x20 || value == 0x7f)) {
    throw FormatException('Bluetooth device identifier is malformed');
  }
}

String _newOperationId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  final hex = value.join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
