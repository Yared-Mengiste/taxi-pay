import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/db/app_database.dart';
import '../data/db/expense_repository.dart';
import '../data/db/payment_repository.dart';
import '../data/db/session_repository.dart';
import '../models/expense.dart';
import '../models/payment.dart';
import '../models/session.dart';
import '../services/background_task_service.dart';
import '../services/reconciliation_service.dart';

/// UI-facing state for the session feature: the one object the home screen
/// watches.
///
/// Responsibilities:
///  - own the active session + its live payment *and expense* lists
///    (rebuilt from the DB — the DB is the source of truth, the provider
///    is a cache + notifier);
///  - react to captured payments arriving via [capturedPayments] and to app
///    resume (picks up writes made by the background isolate);
///  - run reconciliation on demand (manual sync button) and on resume;
///  - keep a summary of the just-ended session around for the stop screen;
///  - schedule/unschedule periodic reconciliation with the session's life.
class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  SessionProvider({
    required AppDatabase app,
    required Stream<Payment> capturedPayments,
    this.backgroundTasks,
    this.reconciliation,
    this.onReconciledPayment,
  })  : _app = app,
        _sessionsRepo = SessionRepository(app),
        _paymentsRepo = PaymentRepository(app),
        _expensesRepo = ExpenseRepository(app) {
    _subscription = capturedPayments.listen((_) => _reloadActive());
    WidgetsBinding.instance.addObserver(this);
  }

  final AppDatabase _app;
  final SessionRepository _sessionsRepo;
  final PaymentRepository _paymentsRepo;
  final ExpenseRepository _expensesRepo;
  final BackgroundTaskService? backgroundTasks;

  /// Inbox-diff engine; defaults to one over [_app]. Injected in tests.
  final ReconciliationService? reconciliation;

  /// Fires for every payment reconciliation inserts (manual sync or
  /// resume) — wired in `app.dart` to re-emit on the capture stream so
  /// listeners (beep, live reload) behave as if the SMS had arrived live.
  final void Function(Payment payment)? onReconciledPayment;

  late final StreamSubscription<Payment> _subscription;

  Session? _activeSession;
  List<Payment> _payments = [];
  List<Expense> _expenses = [];
  int? _walletBalanceCents;

  Session? _lastEndedSession;
  List<Payment> _lastEndedPayments = const [];
  List<Expense> _lastEndedExpenses = const [];

  bool _disposed = false;
  bool _reconciling = false;

  /// The running session, or null.
  Session? get activeSession => _activeSession;

  bool get isRunning => _activeSession != null;

  /// Latest teleBirr wallet balance seen in a captured SMS, or null before
  /// the first teleBirr payment. Refreshed with every reload because any
  /// captured payment may carry a newer balance.
  int? get walletBalanceCents => _walletBalanceCents;

  /// Payments of the running session, newest first (unmodifiable view).
  List<Payment> get payments => List.unmodifiable(_payments);

  /// Expenses of the running session, newest first (unmodifiable view).
  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Live gross total and count, computed from the list — the list is the
  /// session's full contents, so this cannot drift from what the UI shows.
  int get totalCents =>
      _payments.fold(0, (sum, p) => sum + p.amountCents);

  int get paymentCount => _payments.length;

  /// How the running total splits by arrival method — the live card's
  /// teleBirr/cash chips.
  int get telebirrTotalCents => _payments
      .where((p) => p.method == PaymentMethod.telebirr)
      .fold(0, (sum, p) => sum + p.amountCents);

  int get cashTotalCents => _payments
      .where((p) => p.method == PaymentMethod.cash)
      .fold(0, (sum, p) => sum + p.amountCents);

  /// True while an inbox diff is running — the sync button's spinner.
  bool get isReconciling => _reconciling;

  /// What the session cost to run (fuel etc.).
  int get expenseTotalCents =>
      _expenses.fold(0, (sum, e) => sum + e.amountCents);

  /// The number the driver actually cares about at the end of the shift.
  int get netCents => totalCents - expenseTotalCents;

  /// The most recently ended session, kept so the stop screen can show a
  /// shift summary until the next session starts.
  Session? get lastEndedSession => _lastEndedSession;

  List<Payment> get lastEndedPayments =>
      List.unmodifiable(_lastEndedPayments);

  List<Expense> get lastEndedExpenses =>
      List.unmodifiable(_lastEndedExpenses);

  int get lastEndedTotalCents =>
      _lastEndedPayments.fold(0, (sum, p) => sum + p.amountCents);

  int get lastEndedExpenseTotalCents =>
      _lastEndedExpenses.fold(0, (sum, e) => sum + e.amountCents);

  int get lastEndedNetCents =>
      lastEndedTotalCents - lastEndedExpenseTotalCents;

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
    _lastEndedExpenses = _expenses;
    _activeSession = null;
    _payments = [];
    _expenses = [];
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

  Future<void> addExpense({
    required int amountCents,
    required ExpenseCategory category,
    String? note,
  }) async {
    final session = _activeSession;
    if (session == null) return;
    await _expensesRepo.addExpense(
      sessionId: session.id,
      amountCents: amountCents,
      category: category,
      note: note,
    );
    await _reloadActive();
  }

  /// Corrects a mistyped cash fare. TeleBirr payments are receipts and
  /// are never editable — the repository rejects them at the query level.
  Future<void> updateCash({
    required Payment payment,
    required int amountCents,
  }) async {
    if (payment.method != PaymentMethod.cash || payment.id == null) return;
    await _paymentsRepo.updateCashAmount(
      paymentId: payment.id!,
      amountCents: amountCents,
    );
    await _reloadActive();
  }

  /// Removes a mistyped cash fare entirely (see [updateCash]).
  Future<void> deleteCash({required Payment payment}) async {
    if (payment.method != PaymentMethod.cash || payment.id == null) return;
    await _paymentsRepo.deleteCashPayment(paymentId: payment.id!);
    await _reloadActive();
  }

  /// Runs one inbox reconciliation pass and returns how many payments it
  /// inserted. Re-throws inbox-read failures so the manual sync button can
  /// surface "check the SMS permission"; the resume path calls
  /// [_reconcileQuietly], which swallows them instead.
  Future<int> reconcile() async {
    if (_reconciling || _activeSession == null) return 0;
    _reconciling = true;
    _notify();
    try {
      final service = reconciliation ?? ReconciliationService(_app);
      final inserted = await service.reconcile();
      for (final payment in inserted) {
        onReconciledPayment?.call(payment);
      }
      await _reloadActive();
      return inserted.length;
    } finally {
      _reconciling = false;
      _notify();
    }
  }

  Future<void> _reconcileQuietly() async {
    try {
      await reconcile();
    } catch (_) {
      // Inbox reads throw without READ_SMS. Nothing to act on mid-shift;
      // the settings screen shows the permission state.
    }
  }

  Future<void> _reloadActive() async {
    _activeSession = await _sessionsRepo.activeSession();
    if (_activeSession == null) {
      _payments = [];
      _expenses = [];
    } else {
      _payments =
          await _paymentsRepo.paymentsForSession(_activeSession!.id);
      _expenses =
          await _expensesRepo.expensesForSession(_activeSession!.id);
    }
    _walletBalanceCents = await _paymentsRepo.latestTelebirrBalanceCents();
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
  /// don't arrive on any stream — reload from the DB on every resume, and
  /// diff the inbox while we're at it (the correctness guarantee used to
  /// live in `app.dart`; the provider owns it now that the sync button
  /// shares the same code path).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadActive();
      _reconcileQuietly();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
