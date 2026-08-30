import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';

import 'app_state.dart';

const _laneSetEquality = SetEquality<OperationLane>();

/// Immutable UI projection of the formally controlled [AppMachine].
///
/// This is deliberately a projection, never a second state authority. Events
/// still pass through `AppMachine.dispatch`; RxDart only distributes committed
/// snapshots and derives narrowly typed streams for consumers.
final class ReactiveAppSnapshot {
  ReactiveAppSnapshot({
    required this.appPhase,
    required this.authPhase,
    required this.onboarding,
    required this.generation,
    required this.status,
    required Set<OperationLane> runningLanes,
  }) : runningLanes = Set.unmodifiable(runningLanes);

  final AppPhase appPhase;
  final AuthPhase authPhase;
  final OnboardingStep onboarding;
  final int generation;
  final String status;
  final Set<OperationLane> runningLanes;

  bool get signedIn => authPhase == AuthPhase.signedIn;
  bool get busy => runningLanes.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReactiveAppSnapshot &&
      other.appPhase == appPhase &&
      other.authPhase == authPhase &&
      other.onboarding == onboarding &&
      other.generation == generation &&
      other.status == status &&
      _laneSetEquality.equals(other.runningLanes, runningLanes);

  @override
  int get hashCode => Object.hash(
    appPhase,
    authPhase,
    onboarding,
    generation,
    status,
    _laneSetEquality.hash(runningLanes),
  );
}

/// Pure projection from the machine plus explicit presentation status.
ReactiveAppSnapshot projectReactiveSnapshot({
  required AppMachine machine,
  required String status,
}) => ReactiveAppSnapshot(
  appPhase: machine.appPhase,
  authPhase: machine.authPhase,
  onboarding: machine.onboarding,
  generation: machine.generation,
  status: status,
  runningLanes: {
    for (final lane in OperationLane.values)
      if (machine.lane(lane).isRunning) lane,
  },
);

/// Replay-one RxDart boundary for committed application snapshots.
///
/// Derived streams use `distinct` so widgets, integrations, and tests do not
/// repeat effects for semantically identical state. No subscriber can mutate
/// the snapshot or send an event around the formal machine.
final class ReactiveAppState {
  ReactiveAppState(ReactiveAppSnapshot initial)
    : _snapshots = BehaviorSubject.seeded(initial, sync: true);

  final BehaviorSubject<ReactiveAppSnapshot> _snapshots;

  ValueStream<ReactiveAppSnapshot> get snapshots => _snapshots.stream;
  Stream<bool> get signedIn =>
      snapshots.map((value) => value.signedIn).distinct();
  Stream<bool> get busy => snapshots.map((value) => value.busy).distinct();
  Stream<String> get status =>
      snapshots.map((value) => value.status).distinct();
  Stream<Set<OperationLane>> get runningLanes => snapshots
      .map((value) => value.runningLanes)
      .distinct(_laneSetEquality.equals);

  void publish(ReactiveAppSnapshot next) {
    if (_snapshots.isClosed || _snapshots.value == next) return;
    _snapshots.add(next);
  }

  Future<void> close() => _snapshots.close();
}
