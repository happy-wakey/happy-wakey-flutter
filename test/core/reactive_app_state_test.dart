import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/app_state.dart';
import 'package:happy_wakey/src/core/reactive_app_state.dart';

void main() {
  test('projection is immutable and reflects only committed machine state', () {
    final machine = AppMachine(
      signedIn: false,
      onboarding: OnboardingStep.welcome,
    );
    expect(machine.dispatch(const StartupCompleted()).committed, isTrue);
    final lane = machine.dispatch(const LaneRequested(OperationLane.weather));
    expect(lane.committed, isTrue);

    final snapshot = projectReactiveSnapshot(
      machine: machine,
      status: 'Refreshing weather…',
    );

    expect(snapshot.appPhase, AppPhase.ready);
    expect(snapshot.runningLanes, {OperationLane.weather});
    expect(snapshot.busy, isTrue);
    expect(
      () => snapshot.runningLanes.add(OperationLane.news),
      throwsUnsupportedError,
    );
  });

  test(
    'replay-one streams suppress semantically duplicate projections',
    () async {
      final machine = AppMachine(
        signedIn: false,
        onboarding: OnboardingStep.welcome,
      );
      machine.dispatch(const StartupCompleted());
      final reactive = ReactiveAppState(
        projectReactiveSnapshot(machine: machine, status: 'Ready'),
      );
      final values = <bool>[];
      final subscription = reactive.signedIn.listen(values.add);

      reactive.publish(
        projectReactiveSnapshot(machine: machine, status: 'Ready'),
      );
      final login = machine.dispatch(const LoginRequested(AuthProvider.google));
      machine.dispatch(LoginSucceeded(login.token!));
      reactive.publish(
        projectReactiveSnapshot(machine: machine, status: 'Ready'),
      );
      reactive.publish(
        projectReactiveSnapshot(machine: machine, status: 'Ready'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(values, [false, true]);
      await subscription.cancel();
      await reactive.close();
    },
  );
}
