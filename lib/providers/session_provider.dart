import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/db/app_database.dart';
import '../data/db/payment_repository.dart';
import '../data/db/session_repository.dart';
import '../models/payment.dart';
import '../models/session.dart';
import '../services/background_task_service.dart';

/// UI-facing state for the session feature: the one object the home screen
/// watches.
///
/// Responsibilities:
///  - own the active session + its live payment list (rebuilt from the DB —
///    the DB is the source of truth, the provider is a cache + notifier);
///  - react to captured payments arriving via [capturedPayments] and to app
///    resume (picks up writes made by the background isolate);
///  - keep a summary of the just-ended session around for the stop screen;
///  - schedule/unschedule periodic reconciliation with the session's life.
class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  SessionProvider({
    required AppDatabase app,
    required Stream<Payment> capturedPayments,
    this.backgroundTasks,
  })  : _sessionsRepo = SessionRepository(app),
        _paymentsRepo = PaymentRepository(app) {
    _subscription = capturedPayments.listen((_) => _reloadActive());
    WidgetsBinding.instance.addObserver(this);
  }

  final SessionRepository _sessionsRepo;
  final PaymentRepository _paymentsRepo;
  final BackgroundTaskService? backgroundTasks;
  late final StreamSubscription<Payment> _subscription;

  Session? _activeSession;
  List<Payment> _payments = [];

  Session? _lastEndedSession;
  List<Payment> _lastEndedPayments = const [];

  bool _disposed = false;

  /// The running session, or null.
  Session? get activeSession => _activeSession;

  bool get isRunning => _activeSession != null;

  /// Payments of the running session, newest first (unmodifiable view).
  List<Payment> get payments => List.unmodifiable(_payments);

  /// Live total and count, computed from the list — the list is the session's
  /// full contents, so this cannot drift from what the UI shows.
  int get totalCents =>
      _payments.fold(0, (sum, p) => sum + p.amountCents);

  int get paymentCount => _payments.length;

  /// The most recently ended session, kept so the stop screen can show a
  /// shift summary until the next session starts.
  Session? get lastEndedSession => _lastEndedSession;

  List<Payment> get lastEndedPayments =>
      List.unmodifiable(_lastEndedPayments);

  int get lastEndedTotalCents =>
      _lastEndedPayments.fold(0, (sum, p) => sum + p.amountCents);

  /// Initial load — also the cold-start recovery path: whatever the DB says
  /// is the truth, including "a session was running when the app died".
  Future<void> load() => _reloadActive();

  Future<void> start() async {
    _activeSession = await _sessionsRepo.startSession();
    await backgroundTasks?.startPeriodicReconciliation();
    await _reloadActive();
  }

  Future<void> stop() async {
    final session = _activeSession;
    if (session == null) return;
    final endedAtMs = await _sessionsRepo.stopSession();
    await backgroundTasks?.stopPeriodicReconciliation();

    _lastEndedSession = Session(
      id: session.id,
      startedAtMs: session.startedAtMs,
      endedAtMs: endedAtMs >= 0 ? endedAtMs : null,
    );
    _lastEndedPayments = _payments;
    _activeSession = null;
    _payments = [];
    _notify();
  }

  Future<void> addCash({required int amountCents}) async {
    final session = _activeSession;
    if (session == null) return;
    await _paymentsRepo.addCashPayment(
      sessionId: session.id,
      amountCents: amountCents,
    );
    await _reloadActive();
  }

  Future<void> _reloadActive() async {
    _activeSession = await _sessionsRepo.activeSession();
    _payments = _activeSession == null
        ? []
        : await _paymentsRepo.paymentsForSession(_activeSession!.id);
    _notify();
  }

  /// [notifyListeners] after [dispose] is a state error — and legit here,
  /// because [load] and stream callbacks are async and can land after the
  /// widget tree that owned this provider is gone (fast teardown in tests,
  /// hot restart in dev).
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Payments captured by the background isolate while we were backgrounded
  /// don't arrive on any stream — reload from the DB on every resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadActive();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
