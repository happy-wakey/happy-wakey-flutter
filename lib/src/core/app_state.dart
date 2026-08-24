import 'dart:convert';

enum AppPhase { booting, ready }

enum AuthPhase { signedOut, authenticating, signedIn, failed }

enum AuthProvider { google, apple, azure }

enum OnboardingStep { welcome, account, backup, essentials, ready, complete }

extension OnboardingStepX on OnboardingStep {
  static OnboardingStep fromPersisted(String value, {required bool completed}) {
    if (completed) return OnboardingStep.complete;
    return switch (value.trim()) {
      'account' => OnboardingStep.account,
      'backup' => OnboardingStep.backup,
      'essentials' => OnboardingStep.essentials,
      'ready' => OnboardingStep.ready,
      _ => OnboardingStep.welcome,
    };
  }

  String get persistedName => name;

  int get pageIndex => switch (this) {
    OnboardingStep.welcome => 0,
    OnboardingStep.account => 1,
    OnboardingStep.backup => 2,
    OnboardingStep.essentials => 3,
    OnboardingStep.ready || OnboardingStep.complete => 4,
  };

  OnboardingStep? get next => switch (this) {
    OnboardingStep.welcome => OnboardingStep.account,
    OnboardingStep.account => OnboardingStep.backup,
    OnboardingStep.backup => OnboardingStep.essentials,
    OnboardingStep.essentials => OnboardingStep.ready,
    OnboardingStep.ready || OnboardingStep.complete => null,
  };

  OnboardingStep? get previous => switch (this) {
    OnboardingStep.account => OnboardingStep.welcome,
    OnboardingStep.backup => OnboardingStep.account,
    OnboardingStep.essentials => OnboardingStep.backup,
    OnboardingStep.ready => OnboardingStep.essentials,
    OnboardingStep.welcome || OnboardingStep.complete => null,
  };
}

enum OperationLane {
  calendar,
  weather,
  stocks,
  news,
  onboardingHydration,
  desktopNotification,
  cloudNotification,
  cloudReminderSync,
}

extension OperationLaneX on OperationLane {
  bool get requiresAuthentication => switch (this) {
    OperationLane.calendar ||
    OperationLane.onboardingHydration ||
    OperationLane.cloudNotification ||
    OperationLane.cloudReminderSync => true,
    _ => false,
  };
}

enum LanePhase { idle, running, ready, failed }

final class OperationToken {
  const OperationToken(this.value);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is OperationToken && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class LaneSnapshot {
  const LaneSnapshot({
    required this.phase,
    required this.generation,
    required this.activeToken,
  });

  const LaneSnapshot.idle()
    : phase = LanePhase.idle,
      generation = 0,
      activeToken = 0;

  final LanePhase phase;
  final int generation;
  final int activeToken;

  bool get isRunning => phase == LanePhase.running;

  LaneSnapshot copyWith({
    LanePhase? phase,
    int? generation,
    int? activeToken,
  }) => LaneSnapshot(
    phase: phase ?? this.phase,
    generation: generation ?? this.generation,
    activeToken: activeToken ?? this.activeToken,
  );

  Map<String, Object> toJson() => {
    'phase': phase.name,
    'generation': generation,
    'active_token': activeToken,
  };
}

sealed class AppEvent {
  const AppEvent();
}

final class StartupCompleted extends AppEvent {
  const StartupCompleted();
}

final class LoginRequested extends AppEvent {
  const LoginRequested(this.provider);
  final AuthProvider provider;
}

final class LoginSucceeded extends AppEvent {
  const LoginSucceeded(this.token);
  final OperationToken token;
}

final class LoginFailed extends AppEvent {
  const LoginFailed(this.token);
  final OperationToken token;
}

final class LogoutRequested extends AppEvent {
  const LogoutRequested();
}

final class LaneRequested extends AppEvent {
  const LaneRequested(this.lane);
  final OperationLane lane;
}

final class LaneSucceeded extends AppEvent {
  const LaneSucceeded(this.lane, this.token);
  final OperationLane lane;
  final OperationToken token;
}

final class LaneFailed extends AppEvent {
  const LaneFailed(this.lane, this.token);
  final OperationLane lane;
  final OperationToken token;
}

final class OnboardingNext extends AppEvent {
  const OnboardingNext();
}

final class OnboardingPrevious extends AppEvent {
  const OnboardingPrevious();
}

final class OnboardingSkipToReady extends AppEvent {
  const OnboardingSkipToReady();
}

final class OnboardingFinish extends AppEvent {
  const OnboardingFinish();
}

final class OnboardingReconciled extends AppEvent {
  const OnboardingReconciled(this.step);
  final OnboardingStep step;
}

enum RejectReason {
  appNotReady('The application is not ready'),
  alreadyReady('The application has already started'),
  authenticationRequired('Sign in before starting this operation'),
  authenticationInProgress('A sign-in operation is already in progress'),
  alreadySignedIn('Sign out before starting another sign-in'),
  operationInProgress('This operation is already in progress'),
  invalidOnboardingTransition('That onboarding transition is not allowed'),
  generationExhausted('The operation generation counter is exhausted'),
  invariantViolation(
    'The requested transition would violate application invariants',
  );

  const RejectReason(this.message);
  final String message;
}

enum TransitionDisposition { applied, stale, rejected }

final class TransitionOutcome {
  const TransitionOutcome._(this.disposition, {this.token, this.reason});

  const TransitionOutcome.applied([OperationToken? token])
    : this._(TransitionDisposition.applied, token: token);

  const TransitionOutcome.stale() : this._(TransitionDisposition.stale);

  const TransitionOutcome.rejected(RejectReason reason)
    : this._(TransitionDisposition.rejected, reason: reason);

  final TransitionDisposition disposition;
  final OperationToken? token;
  final RejectReason? reason;

  bool get committed => disposition == TransitionDisposition.applied;
}

/// The sole owner of application control state.
///
/// [dispatch] evaluates an event against a private candidate, validates every
/// invariant, and commits atomically. Invalid requests fail closed. Late async
/// completions are classified as stale and deliberately stutter.
final class AppMachine {
  AppMachine({required bool signedIn, required OnboardingStep onboarding})
    : _appPhase = AppPhase.booting,
      _authPhase = signedIn ? AuthPhase.signedIn : AuthPhase.signedOut,
      _authProvider = null,
      _authGeneration = 0,
      _authToken = 0,
      _onboarding = onboarding,
      _onboardingCompletedOnce = onboarding == OnboardingStep.complete,
      _generation = 0,
      _lanes = {
        for (final lane in OperationLane.values)
          lane: const LaneSnapshot.idle(),
      };

  AppMachine._copy(AppMachine source)
    : _appPhase = source._appPhase,
      _authPhase = source._authPhase,
      _authProvider = source._authProvider,
      _authGeneration = source._authGeneration,
      _authToken = source._authToken,
      _onboarding = source._onboarding,
      _onboardingCompletedOnce = source._onboardingCompletedOnce,
      _generation = source._generation,
      _lanes = Map<OperationLane, LaneSnapshot>.of(source._lanes);

  // Largest integer that is exact on Dart VM, JavaScript, and WebAssembly.
  static const int maxGeneration = 0x1fffffffffffff;

  AppPhase _appPhase;
  AuthPhase _authPhase;
  AuthProvider? _authProvider;
  int _authGeneration;
  int _authToken;
  OnboardingStep _onboarding;
  bool _onboardingCompletedOnce;
  int _generation;
  Map<OperationLane, LaneSnapshot> _lanes;

  AppMachine copy() => AppMachine._copy(this);

  AppPhase get appPhase => _appPhase;
  AuthPhase get authPhase => _authPhase;
  OnboardingStep get onboarding => _onboarding;
  int get generation => _generation;
  bool get isSignedIn => _authPhase == AuthPhase.signedIn;
  bool get authenticationInProgress => _authPhase == AuthPhase.authenticating;
  LaneSnapshot lane(OperationLane lane) => _lanes[lane]!;

  bool acceptsAuthToken(OperationToken token) =>
      _authPhase == AuthPhase.authenticating && _authToken == token.value;

  bool acceptsLaneToken(OperationLane lane, OperationToken token) {
    final state = this.lane(lane);
    return state.phase == LanePhase.running && state.activeToken == token.value;
  }

  TransitionOutcome dispatch(AppEvent event) {
    if (invariantError != null) {
      return const TransitionOutcome.rejected(RejectReason.invariantViolation);
    }
    final candidate = copy();
    final outcome = candidate._apply(event);
    if (!outcome.committed) return outcome;
    if (candidate.invariantError != null) {
      return const TransitionOutcome.rejected(RejectReason.invariantViolation);
    }
    _replaceWith(candidate);
    return outcome;
  }

  String? get invariantError {
    final authActive = _authToken != 0;
    if (authActive != (_authPhase == AuthPhase.authenticating)) {
      return 'authentication phase/token mismatch';
    }
    if (authActive &&
        (_authToken != _authGeneration || _authToken > _generation)) {
      return 'authentication token is not the current generation';
    }
    if ((_authProvider != null) != authActive) {
      return 'authentication provider exists outside an active login';
    }
    if (_onboardingCompletedOnce != (_onboarding == OnboardingStep.complete)) {
      return 'completed onboarding regressed or lost its witness';
    }
    for (final lane in OperationLane.values) {
      final state = this.lane(lane);
      final active = state.activeToken != 0;
      if (active != (state.phase == LanePhase.running)) {
        return 'lane phase/token mismatch';
      }
      if (active &&
          (state.activeToken != state.generation ||
              state.activeToken > _generation)) {
        return 'lane token is not the current generation';
      }
      if (lane.requiresAuthentication && active && !isSignedIn) {
        return 'authenticated lane is active while signed out';
      }
    }
    if (_appPhase == AppPhase.booting &&
        _lanes.values.any((lane) => lane.isRunning)) {
      return 'operation started before application readiness';
    }
    return null;
  }

  String toJson() => jsonEncode({
    'app_phase': _appPhase.name,
    'auth': {
      'phase': _authPhase.name,
      'provider': _authProvider?.name,
      'generation': _authGeneration,
      'active_token': _authToken,
    },
    'onboarding': _onboarding.name,
    'onboarding_completed_once': _onboardingCompletedOnce,
    'generation': _generation,
    'lanes': {
      for (final entry in _lanes.entries) entry.key.name: entry.value.toJson(),
    },
  });

  TransitionOutcome _apply(AppEvent event) {
    if (event is! StartupCompleted && _appPhase != AppPhase.ready) {
      return const TransitionOutcome.rejected(RejectReason.appNotReady);
    }
    return switch (event) {
      StartupCompleted() => _startup(),
      LoginRequested(:final provider) => _beginLogin(provider),
      LoginSucceeded(:final token) => _completeLogin(token, succeeded: true),
      LoginFailed(:final token) => _completeLogin(token, succeeded: false),
      LogoutRequested() => _logout(),
      LaneRequested(:final lane) => _beginLane(lane),
      LaneSucceeded(:final lane, :final token) => _completeLane(
        lane,
        token,
        succeeded: true,
      ),
      LaneFailed(:final lane, :final token) => _completeLane(
        lane,
        token,
        succeeded: false,
      ),
      OnboardingNext() => _onboardingNext(),
      OnboardingPrevious() => _onboardingPrevious(),
      OnboardingSkipToReady() => _onboardingSkip(),
      OnboardingFinish() => _onboardingFinish(),
      OnboardingReconciled(:final step) => _onboardingReconcile(step),
    };
  }

  TransitionOutcome _startup() {
    if (_appPhase == AppPhase.ready) {
      return const TransitionOutcome.rejected(RejectReason.alreadyReady);
    }
    _appPhase = AppPhase.ready;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _beginLogin(AuthProvider provider) {
    if (_authPhase == AuthPhase.authenticating) {
      return const TransitionOutcome.rejected(
        RejectReason.authenticationInProgress,
      );
    }
    if (_authPhase == AuthPhase.signedIn) {
      return const TransitionOutcome.rejected(RejectReason.alreadySignedIn);
    }
    final token = _nextToken();
    if (token == null) {
      return const TransitionOutcome.rejected(RejectReason.generationExhausted);
    }
    _authPhase = AuthPhase.authenticating;
    _authProvider = provider;
    _authGeneration = token.value;
    _authToken = token.value;
    return TransitionOutcome.applied(token);
  }

  TransitionOutcome _completeLogin(
    OperationToken token, {
    required bool succeeded,
  }) {
    if (!acceptsAuthToken(token)) return const TransitionOutcome.stale();
    _authPhase = succeeded ? AuthPhase.signedIn : AuthPhase.failed;
    _authProvider = null;
    _authToken = 0;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _logout() {
    _authPhase = AuthPhase.signedOut;
    _authProvider = null;
    _authToken = 0;
    for (final lane in OperationLane.values.where(
      (lane) => lane.requiresAuthentication,
    )) {
      _lanes[lane] = laneSnapshot(
        lane,
      ).copyWith(phase: LanePhase.idle, activeToken: 0);
    }
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _beginLane(OperationLane lane) {
    if (lane.requiresAuthentication && !isSignedIn) {
      return const TransitionOutcome.rejected(
        RejectReason.authenticationRequired,
      );
    }
    if (this.lane(lane).isRunning) {
      return const TransitionOutcome.rejected(RejectReason.operationInProgress);
    }
    final token = _nextToken();
    if (token == null) {
      return const TransitionOutcome.rejected(RejectReason.generationExhausted);
    }
    _lanes[lane] = LaneSnapshot(
      phase: LanePhase.running,
      generation: token.value,
      activeToken: token.value,
    );
    return TransitionOutcome.applied(token);
  }

  TransitionOutcome _completeLane(
    OperationLane lane,
    OperationToken token, {
    required bool succeeded,
  }) {
    if (!acceptsLaneToken(lane, token)) return const TransitionOutcome.stale();
    _lanes[lane] = this
        .lane(lane)
        .copyWith(
          phase: succeeded ? LanePhase.ready : LanePhase.failed,
          activeToken: 0,
        );
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _onboardingNext() {
    final next = _onboarding.next;
    if (next == null) {
      return const TransitionOutcome.rejected(
        RejectReason.invalidOnboardingTransition,
      );
    }
    _onboarding = next;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _onboardingPrevious() {
    final previous = _onboarding.previous;
    if (previous == null) {
      return const TransitionOutcome.rejected(
        RejectReason.invalidOnboardingTransition,
      );
    }
    _onboarding = previous;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _onboardingSkip() {
    if (_onboarding == OnboardingStep.complete) {
      return const TransitionOutcome.rejected(
        RejectReason.invalidOnboardingTransition,
      );
    }
    _onboarding = OnboardingStep.ready;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _onboardingFinish() {
    if (_onboarding != OnboardingStep.ready) {
      return const TransitionOutcome.rejected(
        RejectReason.invalidOnboardingTransition,
      );
    }
    _onboarding = OnboardingStep.complete;
    _onboardingCompletedOnce = true;
    return const TransitionOutcome.applied();
  }

  TransitionOutcome _onboardingReconcile(OnboardingStep step) {
    if (_onboarding == OnboardingStep.complete &&
        step != OnboardingStep.complete) {
      return const TransitionOutcome.stale();
    }
    _onboarding = step;
    if (step == OnboardingStep.complete) _onboardingCompletedOnce = true;
    return const TransitionOutcome.applied();
  }

  OperationToken? _nextToken() {
    if (_generation >= maxGeneration) return null;
    _generation += 1;
    return OperationToken(_generation);
  }

  LaneSnapshot laneSnapshot(OperationLane lane) => _lanes[lane]!;

  void _replaceWith(AppMachine candidate) {
    _appPhase = candidate._appPhase;
    _authPhase = candidate._authPhase;
    _authProvider = candidate._authProvider;
    _authGeneration = candidate._authGeneration;
    _authToken = candidate._authToken;
    _onboarding = candidate._onboarding;
    _onboardingCompletedOnce = candidate._onboardingCompletedOnce;
    _generation = candidate._generation;
    _lanes = Map<OperationLane, LaneSnapshot>.of(candidate._lanes);
  }
}
