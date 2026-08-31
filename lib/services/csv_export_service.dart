import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db/payment_repository.dart';
import '../util/csv.dart';

/// One CSV export attempt — either a shareable file or the reason there
/// isn't one.
class CsvExportResult {
  const CsvExportResult({this.file, this.paymentCount})
      : assert(file != null || paymentCount == null);

  /// The CSV written to cache, ready to hand to the share sheet.
  final File? file;

  /// Rows in the export; null means "nothing to export" (empty window).
  final int? paymentCount;

  bool get isEmpty => file == null;
}

/// Exports a date window's payments as CSV via the Android share sheet.
///
/// Both the share action and the cache directory are injectable so tests
/// can verify the file contents without platform channels. File naming is
/// `taxi-pay_<from>_<to>.csv` with compact ISO dates.
class CsvExportService {
  CsvExportService(
    this._repo, {
    void Function(File file)? onShareFile,
    Future<Directory> Function()? cacheDir,
  })  : _onShare = onShareFile,
        _cacheDir = cacheDir ?? getTemporaryDirectory;

  final PaymentRepository _repo;
  final void Function(File file)? _onShare;
  final Future<Directory> Function() _cacheDir;

  Future<CsvExportResult> exportRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final payments = await _repo.paymentsBetween(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    if (payments.isEmpty) return const CsvExportResult();

    final csv = buildPaymentsCsv(payments);
    final dir = await _cacheDir();
    final name = 'taxi-pay_${_compact(from)}_${_compact(to)}.csv';
    final file = File(p.join(dir.path, name));

    // The BOM is the difference between Excel showing Amharic names and
    // showing garbage — Excel assumes legacy encodings without it.
    await file.writeAsString('\uFEFF$csv', flush: true);

    if (_onShare != null) {
      _onShare(file);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Taxi Pay export',
          files: [file.xFile],
        ),
      );
    }
    return CsvExportResult(file: file, paymentCount: payments.length);
  }

  static String _compact(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

extension on File {
  /// XFile is what share_plus transports; constructing it from a File
  /// preserves the path and lets Android resolve the content URI.
  XFile get xFile => XFile(path, mimeType: 'text/csv');
}
