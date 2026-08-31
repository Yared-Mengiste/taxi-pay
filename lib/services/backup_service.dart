import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db/app_database.dart';

/// Shares a snapshot of the SQLite database file.
///
/// The `.db` file is this app's single source of truth — months of earnings
/// live in exactly one file on one phone, and a lost phone loses them.
/// "Export backup" checkpoints the database, copies the file into the cache
/// directory under a timestamped name and hands it to the Android share
/// sheet, so the driver can park a copy on WhatsApp/Drive/USB wherever they
/// already trust. Restore is the reverse: copy the file back over the
/// database path while the app isn't running.
class BackupService {
  BackupService(
    this._app, {
    Future<Directory> Function()? cacheDir,
    void Function(File file)? onShareFile,
  })  : _cacheDir = cacheDir ?? getTemporaryDirectory,
        _onShare = onShareFile;

  final AppDatabase _app;

  /// Where the copy is staged before sharing — injectable like the CSV
  /// service's cache dir, because `getTemporaryDirectory()` is a platform
  /// channel that explodes in unit tests.
  final Future<Directory> Function() _cacheDir;
  final void Function(File file)? _onShare;

  /// Copies the database and opens the share sheet. Returns the staged
  /// backup file (caller may report its name/size), or null when the
  /// database file unexpectedly doesn't exist.
  Future<File?> exportBackup() async {
    // Fold any write-ahead log into the main file first — a copy taken
    // mid-WAL can be missing the newest rows. rawQuery, not execute,
    // because the pragma returns a result row (same reason as
    // AppDatabase's busy_timeout).
    await _app.db.rawQuery('PRAGMA wal_checkpoint(FULL)');

    final source = File(_app.db.path);
    if (!await source.exists()) return null;

    final dir = await _cacheDir();
    final stamp = _stamp(DateTime.now());
    final dest = File(p.join(dir.path, 'taxi-pay-backup_$stamp.db'));
    await dest.writeAsBytes(await source.readAsBytes(), flush: true);

    if (_onShare != null) {
      _onShare(dest);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Taxi Pay backup',
          files: [XFile(dest.path, mimeType: 'application/octet-stream')],
        ),
      );
    }
    return dest;
  }

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
