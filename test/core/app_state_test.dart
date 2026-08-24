import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/app_state.dart';

void main() {
  group('shared Happy Wakey app-state contract', () {
    test('startup, login, and calendar trace reaches a safe ready state', () {
      final machine = _started();
      final login = machine.dispatch(const LoginRequested(AuthProvider.google));
      expect(login.committed, isTrue);
      expect(machine.dispatch(LoginSucceeded(login.token!)).committed, isTrue);
      final calendar = machine.dispatch(
        const LaneRequested(OperationLane.calendar),
      );
      expect(calendar.committed, isTrue);
      expect(
        machine
            .dispatch(LaneSucceeded(OperationLane.calendar, calendar.token!))
            .committed,
        isTrue,
      );
      expect(machine.authPhase, AuthPhase.signedIn);
      expect(machine.lane(OperationLane.calendar).phase, LanePhase.ready);
      expect(machine.invariantError, isNull);
    });

    test('a late login completion cannot resurrect a logged-out session', () {
      final machine = _started();
      final token = machine
          .dispatch(const LoginRequested(AuthProvider.google))
          .token!;
      expect(machine.dispatch(const LogoutRequested()).committed, isTrue);
      final before = machine.toJson();
      final outcome = machine.dispatch(LoginSucceeded(token));
      expect(outcome.disposition, TransitionDisposition.stale);
      expect(machine.toJson(), before);
      expect(machine.authPhase, AuthPhase.signedOut);
    });

    test('logout cancels authenticated lanes and fences their callbacks', () {
      final machine = _signedIn();
      final token = machine
          .dispatch(const LaneRequested(OperationLane.calendar))
          .token!;
      expect(machine.dispatch(const LogoutRequested()).committed, isTrue);
      final outcome = machine.dispatch(
        LaneSucceeded(OperationLane.calendar, token),
      );
      expect(outcome.disposition, TransitionDisposition.stale);
      expect(machine.lane(OperationLane.calendar).phase, LanePhase.idle);
      expect(machine.invariantError, isNull);
    });

    test('public lanes remain independent', () {
      final machine = _started();
      final weather = machine
          .dispatch(const LaneRequested(OperationLane.weather))
          .token!;
      final news = machine
          .dispatch(const LaneRequested(OperationLane.news))
          .token!;
      expect(
        machine.dispatch(LaneFailed(OperationLane.weather, weather)).committed,
        isTrue,
      );
      expect(machine.lane(OperationLane.weather).phase, LanePhase.failed);
      expect(machine.lane(OperationLane.news).phase, LanePhase.running);
      expect(machine.lane(OperationLane.news).activeToken, news.value);
    });

    test(
      'onboarding follows declared edges and completion is irreversible',
      () {
        final machine = _started();
        expect(machine.dispatch(const OnboardingFinish()).committed, isFalse);
        for (var index = 0; index < 4; index += 1) {
          expect(machine.dispatch(const OnboardingNext()).committed, isTrue);
        }
        expect(machine.onboarding, OnboardingStep.ready);
        expect(machine.dispatch(const OnboardingFinish()).committed, isTrue);
        final before = machine.toJson();
        expect(
          machine
              .dispatch(const OnboardingReconciled(OnboardingStep.account))
              .disposition,
          TransitionDisposition.stale,
        );
        expect(machine.toJson(), before);
        expect(machine.invariantError, isNull);
      },
    );

    test(
      'requests before startup fail closed and do not consume generations',
      () {
        final machine = AppMachine(
          signedIn: false,
          onboarding: OnboardingStep.welcome,
        );
        for (final event in <AppEvent>[
          const LoginRequested(AuthProvider.google),
          const LaneRequested(OperationLane.weather),
          const OnboardingNext(),
        ]) {
          expect(machine.dispatch(event).reason, RejectReason.appNotReady);
        }
        expect(machine.appPhase, AppPhase.booting);
        expect(machine.generation, 0);
        expect(machine.onboarding, OnboardingStep.welcome);
      },
    );

    test('a stale same-lane result cannot overwrite a newer request', () {
      final machine = _started();
      final first = machine
          .dispatch(const LaneRequested(OperationLane.weather))
          .token!;
      expect(
        machine.dispatch(LaneSucceeded(OperationLane.weather, first)).committed,
        isTrue,
      );
      final second = machine
          .dispatch(const LaneRequested(OperationLane.weather))
          .token!;
      final before = machine.toJson();
      expect(
        machine.dispatch(LaneFailed(OperationLane.weather, first)).disposition,
        TransitionDisposition.stale,
      );
      expect(machine.toJson(), before);
      expect(machine.lane(OperationLane.weather).activeToken, second.value);
    });

    test(
      'every bounded event is total, deterministic, and invariant preserving',
      () {
        final queue = <({AppMachine machine, int depth})>[];
        final seen = <String>{};
        for (final signedIn in [false, true]) {
          for (final onboarding in OnboardingStep.values) {
            final machine = AppMachine(
              signedIn: signedIn,
              onboarding: onboarding,
            );
            queue.add((machine: machine, depth: 0));
          }
        }

        var transitions = 0;
        while (queue.isNotEmpty) {
          final node = queue.removeLast();
          final key = node.machine.toJson();
          if (!seen.add(key)) continue;
          expect(node.machine.invariantError, isNull, reason: key);
          if (node.depth >= 4) continue;

          for (final event in _events) {
            final left = node.machine.copy();
            final right = node.machine.copy();
            final leftOutcome = left.dispatch(event);
            final rightOutcome = right.dispatch(event);
            transitions += 1;
            expect(leftOutcome.disposition, rightOutcome.disposition);
            expect(leftOutcome.token, rightOutcome.token);
            expect(leftOutcome.reason, rightOutcome.reason);
            expect(left.toJson(), right.toJson());
            expect(left.invariantError, isNull, reason: left.toJson());
            if (!leftOutcome.committed) {
              expect(left.toJson(), node.machine.toJson());
            }
            queue.add((machine: left, depth: node.depth + 1));
          }
        }

        expect(seen.length, greaterThan(800));
        expect(transitions, greaterThan(10000));
      },
    );

    test(
      'serialized snapshots contain no secret-bearing configuration fields',
      () {
        final machine = _signedIn();
        final snapshot = jsonDecode(machine.toJson()) as Map<String, Object?>;
        expect(
          snapshot.keys,
          containsAll(['app_phase', 'auth', 'onboarding', 'lanes']),
        );
        final encoded = machine.toJson().toLowerCase();
        expect(encoded, isNot(contains('access_token')));
        expect(encoded, isNot(contains('provider_token')));
        expect(encoded, isNot(contains('api_key')));
      },
    );
  });
}

AppMachine _started() {
  final machine = AppMachine(
    signedIn: false,
    onboarding: OnboardingStep.welcome,
  );
  expect(machine.dispatch(const StartupCompleted()).committed, isTrue);
  return machine;
}

AppMachine _signedIn() {
  final machine = _started();
  final login = machine.dispatch(const LoginRequested(AuthProvider.google));
  expect(machine.dispatch(LoginSucceeded(login.token!)).committed, isTrue);
  return machine;
}

final List<AppEvent> _events = [
  const StartupCompleted(),
  for (final provider in AuthProvider.values) LoginRequested(provider),
  for (final token in [0, 1, 2, 3, 4, 99]) ...[
    LoginSucceeded(OperationToken(token)),
    LoginFailed(OperationToken(token)),
  ],
  const LogoutRequested(),
  for (final lane in OperationLane.values) ...[
    LaneRequested(lane),
    for (final token in [0, 1, 2, 3, 4, 99]) ...[
      LaneSucceeded(lane, OperationToken(token)),
      LaneFailed(lane, OperationToken(token)),
    ],
  ],
  const OnboardingNext(),
  const OnboardingPrevious(),
  const OnboardingSkipToReady(),
  const OnboardingFinish(),
  for (final step in OnboardingStep.values) OnboardingReconciled(step),
];
