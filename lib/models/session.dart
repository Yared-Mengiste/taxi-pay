/// A work shift: the window between the driver tapping Start and Stop.
///
/// The active session *is* the persisted listening state — a row with
/// `endedAtMs == null` means "a session is running", which is how
/// `isListening` and `sessionStartTime` survive the app being killed.
class Session {
  const Session({required this.id, required this.startedAtMs, this.endedAtMs});

  final int id;
  final int startedAtMs;
  final int? endedAtMs;

  bool get isActive => endedAtMs == null;
}
