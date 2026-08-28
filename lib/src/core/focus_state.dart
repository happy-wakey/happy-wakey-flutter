enum FocusPhase { idle, running, paused, completed }

sealed class FocusEvent {
  const FocusEvent();
}

final class FocusStarted extends FocusEvent {
  const FocusStarted(this.duration);
  final Duration duration;
}

final class FocusTicked extends FocusEvent {
  const FocusTicked(this.elapsed);
  final Duration elapsed;
}

final class FocusPaused extends FocusEvent {
  const FocusPaused();
}

final class FocusResumed extends FocusEvent {
  const FocusResumed();
}

final class FocusReset extends FocusEvent {
  const FocusReset();
}

final class FocusSnapshot {
  const FocusSnapshot({
    required this.phase,
    required this.total,
    required this.remaining,
  });

  const FocusSnapshot.idle()
    : phase = FocusPhase.idle,
      total = Duration.zero,
      remaining = Duration.zero;

  final FocusPhase phase;
  final Duration total;
  final Duration remaining;

  double get progress => total == Duration.zero
      ? 0
      : (1 - remaining.inMilliseconds / total.inMilliseconds).clamp(0, 1);
}

/// A small total state machine for the augmented focus-session feature.
final class FocusMachine {
  FocusSnapshot _snapshot = const FocusSnapshot.idle();

  FocusSnapshot get snapshot => _snapshot;

  /// Pure transition: [current] and [event] in, next snapshot or null out.
  static FocusSnapshot? apply(FocusSnapshot current, FocusEvent event) =>
      switch ((current.phase, event)) {
        (
          FocusPhase.idle || FocusPhase.completed,
          FocusStarted(:final duration),
        )
            when duration > Duration.zero =>
          FocusSnapshot(
            phase: FocusPhase.running,
            total: duration,
            remaining: duration,
          ),
        (FocusPhase.running, FocusTicked(:final elapsed)) => _tick(
          current,
          elapsed,
        ),
        (FocusPhase.running, FocusPaused()) => FocusSnapshot(
          phase: FocusPhase.paused,
          total: current.total,
          remaining: current.remaining,
        ),
        (FocusPhase.paused, FocusResumed()) => FocusSnapshot(
          phase: FocusPhase.running,
          total: current.total,
          remaining: current.remaining,
        ),
        (_, FocusReset()) => const FocusSnapshot.idle(),
        _ => null,
      };

  bool dispatch(FocusEvent event) {
    final next = apply(_snapshot, event);
    if (next == null || !_valid(next)) return false;
    _snapshot = next;
    return true;
  }

  static FocusSnapshot _tick(FocusSnapshot current, Duration elapsed) {
    if (elapsed <= Duration.zero) return current;
    final remaining = current.remaining - elapsed;
    if (remaining <= Duration.zero) {
      return FocusSnapshot(
        phase: FocusPhase.completed,
        total: current.total,
        remaining: Duration.zero,
      );
    }
    return FocusSnapshot(
      phase: FocusPhase.running,
      total: current.total,
      remaining: remaining,
    );
  }

  bool _valid(FocusSnapshot value) =>
      value.total >= Duration.zero &&
      value.remaining >= Duration.zero &&
      value.remaining <= value.total &&
      (value.phase == FocusPhase.idle
          ? value.total == Duration.zero && value.remaining == Duration.zero
          : value.total > Duration.zero);
}
