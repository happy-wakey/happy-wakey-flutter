import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/platform/parity_contract_v1.dart';

class _FakeAdapter extends AppPlatformAdapter {
  const _FakeAdapter(this.available);

  final Set<AppCapability> available;

  @override
  AppSurface get surface => AppSurface.mobile;

  @override
  bool supports(AppCapability capability) => available.contains(capability);
}

void main() {
  test('all required capabilities admit an adapter', () {
    final adapter = _FakeAdapter(requiredParityCapabilities);
    expect(missingRequiredParityCapabilities(adapter), isEmpty);
    expect(() => verifyRequiredParityCapabilities(adapter), returnsNormally);
  });

  test('missing capabilities are precise and immutable', () {
    final adapter = _FakeAdapter({
      ...requiredParityCapabilities,
    }..remove(AppCapability.reminders));
    final missing = missingRequiredParityCapabilities(adapter);
    expect(missing, {AppCapability.reminders});
    expect(() => missing.clear(), throwsUnsupportedError);
    expect(
      () => verifyRequiredParityCapabilities(adapter),
      throwsA(isA<StateError>()),
    );
  });
}
