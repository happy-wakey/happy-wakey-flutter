import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/focus_state.dart';

void main() {
  test('focus machine accepts only declared transitions', () {
    final machine = FocusMachine();
    expect(machine.dispatch(const FocusPaused()), isFalse);
    expect(machine.dispatch(const FocusStarted(Duration(minutes: 25))), isTrue);
    expect(
      machine.dispatch(const FocusStarted(Duration(minutes: 10))),
      isFalse,
    );
    expect(machine.dispatch(const FocusTicked(Duration(minutes: 5))), isTrue);
    expect(machine.snapshot.remaining, const Duration(minutes: 20));
    expect(machine.dispatch(const FocusPaused()), isTrue);
    expect(machine.dispatch(const FocusTicked(Duration(minutes: 5))), isFalse);
    expect(machine.dispatch(const FocusResumed()), isTrue);
    expect(machine.dispatch(const FocusTicked(Duration(minutes: 25))), isTrue);
    expect(machine.snapshot.phase, FocusPhase.completed);
    expect(machine.snapshot.remaining, Duration.zero);
    expect(machine.dispatch(const FocusStarted(Duration(minutes: 10))), isTrue);
    expect(machine.snapshot.phase, FocusPhase.running);
    expect(machine.snapshot.remaining, const Duration(minutes: 10));
    expect(machine.dispatch(const FocusReset()), isTrue);
    expect(machine.snapshot.phase, FocusPhase.idle);
  });

  test('non-positive durations fail closed', () {
    final machine = FocusMachine();
    expect(machine.dispatch(const FocusStarted(Duration.zero)), isFalse);
    expect(
      machine.dispatch(const FocusStarted(Duration(minutes: -1))),
      isFalse,
    );
    expect(machine.snapshot.phase, FocusPhase.idle);
  });
}
