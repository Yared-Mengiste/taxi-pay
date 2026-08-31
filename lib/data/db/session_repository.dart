import 'package:sqflite/sqflite.dart';

import '../../models/session.dart';
import 'app_database.dart';

class SessionRepository {
  SessionRepository(this._app);

  final AppDatabase _app;
  Database get _db => _app.db;

  /// Starts a new session, unless one is already running — starting is
  /// idempotent so a stray double-tap can never fork two "active" sessions.
  Future<Session> startSession({int? nowMs}) async {
    final active = await activeSession();
    if (active != null) return active;

    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insert('sessions', {'started_at_ms': ts});
    return Session(id: id, startedAtMs: ts);
  }

  /// Closes the running session, if any. Returns the ended-at timestamp
  /// (useful for building a summary of the just-finished session), or -1 if
  /// there was nothing to stop.
  Future<int> stopSession({int? nowMs}) async {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final updated = await _db.update(
      'sessions',
      {'ended_at_ms': ts},
      where: 'ended_at_ms IS NULL',
    );
    return updated > 0 ? ts : -1;
  }

  /// The running session, or null. This single query is the app's persisted
  /// "is a session active and since when" state — it works identically after
  /// a cold start because it reads the database, not memory.
  Future<Session?> activeSession() async {
    final rows = await _db.query(
      'sessions',
      where: 'ended_at_ms IS NULL',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session(
      id: rows.first['id'] as int,
      startedAtMs: rows.first['started_at_ms'] as int,
      endedAtMs: rows.first['ended_at_ms'] as int?,
    );
  }

  /// Most recent finished sessions with their earnings, newest first.
  Future<List<SessionSummary>> recentSessions({int limit = 30}) async {
    final rows = await _db.rawQuery(
      'SELECT s.id, s.started_at_ms, s.ended_at_ms, '
      'COALESCE(SUM(p.amount_cents), 0) AS total, COUNT(p.id) AS n '
      'FROM sessions s LEFT JOIN payments p ON p.session_id = s.id '
      'WHERE s.ended_at_ms IS NOT NULL '
      'GROUP BY s.id ORDER BY s.started_at_ms DESC LIMIT ?',
      [limit],
    );
    return rows
        .map(
          (r) => SessionSummary(
            session: Session(
              id: r['id'] as int,
              startedAtMs: r['started_at_ms'] as int,
              endedAtMs: r['ended_at_ms'] as int?,
            ),
            totalCents: r['total'] as int,
            paymentCount: r['n'] as int,
          ),
        )
        .toList();
  }
}

class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.totalCents,
    required this.paymentCount,
  });

  final Session session;
  final int totalCents;
  final int paymentCount;
}
