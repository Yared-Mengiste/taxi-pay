import 'package:another_telephony/telephony.dart';

import '../data/db/app_database.dart';
import '../data/sms/sms_capture.dart';
import '../data/db/session_repository.dart';
import '../models/payment.dart';

/// A raw inbox message — the minimal shape reconciliation needs.
class InboxSmsItem {
  const InboxSmsItem({this.address, this.body, this.dateMs});

  final String? address;
  final String? body;
  final int? dateMs;
}

/// Fetches inbox messages with `date >= sinceMs` from the SMS content
/// provider. Injected so tests can supply a fake.
typedef SmsFetcher = Future<List<InboxSmsItem>> Function(int sinceMs);

/// Queries the device's SMS inbox for teleBirr messages since the active
/// session started and inserts anything the live capture path missed.
///
/// This is the app's **correctness guarantee**, not an optimization:
/// broadcasts get dropped (Doze, OEM "battery savers", process death),
/// but the inbox keeps every message the carrier delivered. Re-running this
/// at any time converges local storage to the truth — inserts are idempotent
/// via the UNIQUE(transaction_id) constraint, so "already known" is a no-op.
class ReconciliationService {
  ReconciliationService(this._app, {SmsFetcher? fetchSms})
      : _fetchSms = fetchSms ?? _fetchFromContentProvider;

  final AppDatabase _app;
  final SmsFetcher _fetchSms;

  static Future<List<InboxSmsItem>> _fetchFromContentProvider(
      int sinceMs) async {
    final messages = await Telephony.instance.getInboxSms(
      columns: [
        SmsColumn.ID,
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ],
      filter: SmsFilter.where(SmsColumn.ADDRESS)
          .equals('127')
          .and(SmsColumn.DATE)
          .greaterThanOrEqualTo(sinceMs.toString()),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
    );
    return [
      for (final m in messages)
        InboxSmsItem(address: m.address, body: m.body, dateMs: m.date),
    ];
  }

  /// Returns the payments that were missing from storage and got inserted.
  /// Outside an active session this is an immediate empty list (nothing is
  /// tracked off-session, so there is nothing to reconcile).
  Future<List<Payment>> reconcile() async {
    final session = await SessionRepository(_app).activeSession();
    if (session == null) return const [];

    final items = await _fetchSms(session.startedAtMs);
    final inserted = <Payment>[];
    for (final item in items) {
      final payment = await captureSmsMessage(
        _app,
        address: item.address,
        body: item.body,
        timestampMs:
            item.dateMs ?? DateTime.now().millisecondsSinceEpoch,
      );
      if (payment != null) inserted.add(payment);
    }
    return inserted;
  }
}
