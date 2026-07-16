import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/remote_downloads.dart';
import 'package:venera/foundation/remote_import.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';

/// Lifecycle state of a [RemoteDownloadTask].
enum RemoteDownloadState {
  /// Created but [start] not yet called.
  idle,

  /// Downloading or importing.
  running,

  /// Paused by the user mid-download; can be [start]ed to resume.
  paused,

  /// Finished successfully.
  completed,

  /// Failed with an error message.
  error,

  /// Cancelled by the user; partial files were removed.
  canceled,
}

/// A cancellable, resumable download-and-import operation for a single remote
/// library item.
///
/// The operation runs in two phases — **download** (HTTP Range, resumable) then
/// **import** (local-only) — and reports progress via [onProgress]. Because the
/// download is resumable, pausing or losing partway through and calling [start]
/// again picks up where it left off instead of re-downloading from scratch.
///
/// The task is a [ChangeNotifier]: the dialog listens to it and rebuilds on
/// state/progress changes.
class RemoteDownloadTask extends ChangeNotifier {
  RemoteDownloadTask({
    required this.file,
    this.onProgress,
  }) : type = getFileType(file);

  /// Remote file to download.
  final wd.File file;

  /// Its classified type.
  final RemoteFileType type;

  /// Optional progress callback `(stage, current, total)`.
  final ImportProgress? onProgress;

  RemoteDownloadState _state = RemoteDownloadState.idle;
  RemoteDownloadState get state => _state;

  /// 0..1 progress across both phases (download = 0..0.5, import = 0.5..1).
  double _progress = 0;
  double get progress => _progress;

  /// Human-readable status line for the current phase (e.g. "Downloading 40%").
  String _message = '';
  String get message => _message;

  /// Error description when [state] is [RemoteDownloadState.error].
  String? error;

  CancelToken? _cancel;

  String get _name => file.name ?? 'Comic'.tl;

  String get _remotePath => file.path!;

  bool get isTerminal =>
      _state == RemoteDownloadState.completed ||
      _state == RemoteDownloadState.error ||
      _state == RemoteDownloadState.canceled;

  /// Begin or resume the download + import. No-op if already running or
  /// terminal.
  Future<void> start() async {
    if (_state == RemoteDownloadState.running) return;
    if (_state == RemoteDownloadState.completed) return;
    _cancel = CancelToken();
    _setState(RemoteDownloadState.running);
    _run();
  }

  /// Pause a running task. The in-flight chunk is aborted; the bytes already
  /// flushed are kept so [start] can resume. State flips to paused
  /// synchronously so the UI updates immediately.
  void pause() {
    if (_state != RemoteDownloadState.running) return;
    _cancel?.cancel();
    _setState(RemoteDownloadState.paused);
  }

  /// Cancel and clean up any partial download. The task becomes
  /// [RemoteDownloadState.canceled] and cannot be restarted.
  void cancel() {
    if (isTerminal) return;
    _cancel?.cancel();
    _cleanupPartial();
    _setState(RemoteDownloadState.canceled);
  }

  Future<void> _run() async {
    final cancel = _cancel!;
    _progress = 0;
    error = null;

    try {
      switch (type) {
        case RemoteFileType.folder:
          await _importFolder(cancel);
          break;
        case RemoteFileType.archive:
          await _importArchive(cancel);
          break;
        case RemoteFileType.pdf:
          await _importPdf(cancel);
          break;
        case RemoteFileType.image:
        case RemoteFileType.other:
          error = 'Unsupported file type'.tl;
          _setState(RemoteDownloadState.error);
          return;
      }
    } catch (e) {
      // A thrown cancel (e.g. DioException mid-chunk) is expected when the
      // user paused/canceled — the state was already flipped synchronously, so
      // just keep the partial bytes (or drop them if canceled).
      if (cancel.isCancelled) {
        if (_state == RemoteDownloadState.canceled) {
          _cleanupPartial();
        }
        return;
      }
      error = e.toString();
      _setState(RemoteDownloadState.error);
    }
  }

  // --- per-type flows ---

  Future<void> _importFolder(CancelToken cancel) async {
    final comic = await RemoteImporter.importWebDavFolder(
      _remotePath,
      _name,
      onProgress: _wrapProgress(),
      cancel: cancel,
    );
    if (comic == null) {
      // Paused mid-download: importer returned null after a cancel. State is
      // already paused; nothing to register.
      return;
    }
    await _register(comic, null, 'folder');
  }

  Future<void> _importArchive(CancelToken cancel) async {
    final comic = await RemoteImporter.importArchive(
      file,
      onProgress: _wrapProgress(),
      cancel: cancel,
    );
    if (comic == null) return;
    await _register(comic, null, 'zip');
  }

  Future<void> _importPdf(CancelToken cancel) async {
    final result = await RemoteImporter.importPdf(
      file,
      onProgress: _wrapProgress(),
      cancel: cancel,
    );
    if (result == null) return;
    await _register(result.$1, result.$2, 'pdf');
  }

  /// Register the imported comic locally, record it, and clean up history.
  Future<void> _register(LocalComic comic, String? localPath, String type) async {
    final id = LocalManager().findValidId(ComicType.local);
    await LocalManager().add(comic, id);
    RemoteDownloads.record(RemoteDownloadEntry(
      remotePath: _remotePath,
      type: type,
      name: _name,
      comicId: id,
      localPath: localPath,
    ));
    for (final t in const [ComicType.webdav, ComicType.pdf, ComicType.zip]) {
      HistoryManager().remove(_remotePath, t);
    }
    _setProgress(1.0);
    _setState(RemoteDownloadState.completed);
  }

  /// Wraps the user [onProgress] to also drive the task's progress/message.
  ImportProgress _wrapProgress() {
    return (stage, current, total) {
      final fraction = total > 0 ? current / total : 1.0;
      final value = stage == ImportStage.download
          ? 0.5 * fraction
          : 0.5 + 0.5 * fraction;
      _setProgress(value);
      final pct = total > 0 ? (current * 100 ~/ total) : 100;
      final phase = stage == ImportStage.download
          ? 'Downloading'.tl
          : 'Importing'.tl;
      _setMessage('$phase $pct%');
      onProgress?.call(stage, current, total);
    };
  }

  /// Remove any partial files left over from an interrupted folder download so
  /// a cancel fully reverts the operation.
  void _cleanupPartial() {
    try {
      if (type == RemoteFileType.folder) {
        final dest = Directory(
          FilePath.join(LocalManager().path, sanitizeFileName(_name)),
        );
        if (dest.existsSync()) dest.deleteSync(recursive: true);
        final status = File('${dest.path}.rvdownload');
        if (status.existsSync()) status.deleteSync();
      }
    } catch (_) {}
  }

  // --- state helpers ---

  void _setState(RemoteDownloadState s) {
    _state = s;
    notifyListeners();
  }

  void _setProgress(double v) {
    _progress = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _setMessage(String m) {
    _message = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}
