import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../widgets/dashboard_widgets.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final busy = controller.loading(OperationLane.bluetooth);
    final connected = controller.connectedBluetoothDeviceId;
    return FeaturePage(
      title: 'Bluetooth devices',
      subtitle: 'Discover only Happy Wakey BLE peripherals and send bounded, credential-free alarm commands.',
      actions: [
        FilledButton.icon(
          onPressed: !controller.bluetoothSupported || busy
              ? null
              : controller.scanBluetooth,
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bluetooth_searching),
          label: const Text('Scan nearby'),
        ),
      ],
      children: [
        if (!controller.bluetoothSupported)
          const EmptyPanel(
            icon: Icons.bluetooth_disabled,
            title: 'Bluetooth Low Energy is unavailable',
            message: 'Use a device with a supported Bluetooth adapter and grant access in system settings.',
          )
        else if (controller.bluetoothDevices.isEmpty)
          EmptyPanel(
            icon: Icons.alarm,
            title: 'No Happy Wakey devices discovered',
            message: 'Power on a compatible alarm device, keep it nearby, and scan again.',
            action: OutlinedButton.icon(
              onPressed: busy ? null : controller.scanBluetooth,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan'),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final device in controller.bluetoothDevices)
                SizedBox(
                  width: 380,
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          connected == device.id
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                        ),
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        device.rssi == null
                            ? 'Signal strength unavailable'
                            : 'Signal ${device.rssi} dBm',
                      ),
                      trailing: connected == device.id
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton.tonal(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        controller.connectBluetooth(device.id),
                              child: const Text('Connect'),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        if (connected != null) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.alarm_on),
                  const Text('Connected and ready for a safe preview'),
                  FilledButton.icon(
                    onPressed: busy ? null : controller.previewBluetoothAlarm,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview 3 seconds'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : controller.disconnectBluetooth,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('Local radio boundary'),
            subtitle: Text(
              'Bluetooth commands contain an operation UUID, action, and duration only—never Shared Auth tokens, account IDs, or API credentials.',
            ),
          ),
        ),
      ],
    );
  }
}
