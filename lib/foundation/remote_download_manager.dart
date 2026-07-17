import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/remote_download_task.dart';

/// Global, app-lifetime owner of every in-progress remote download task.
///
/// Unlike storing tasks in a page's State (which dies when the page is
/// popped), this singleton lives for the whole app session, so:
///
/// - Tasks keep **running in the background** after the downloads page closes.
/// - Re-opening the page shows the same tasks with their live progress, ready
///   to be paused / canceled.
///
/// The downloads page subscribes via [addListener]; it never creates or
/// disposes tasks itself — it asks the manager through [startDownload].
class RemoteDownloadManager extends ChangeNotifier {
  RemoteDownloadManager._();

  static final RemoteDownloadManager instance = RemoteDownloadManager._();

  final List<RemoteDownloadTask> _tasks = [];

  /// All live tasks (idle / running / paused / error), newest last.
  List<RemoteDownloadTask> get tasks => List.unmodifiable(_tasks);

  /// Active tasks only (not yet finished or canceled) — shown at the top of the
  /// downloads page.
  List<RemoteDownloadTask> get activeTasks =>
      _tasks.where((t) => !t.isTerminal).toList();

  RemoteDownloadTask? taskFor(String? remotePath) {
    if (remotePath == null) return null;
    for (final t in _tasks) {
      if (t.file.path == remotePath) return t;
    }
    return null;
  }

  /// Whether a task already exists for [remotePath].
  bool hasTask(String? remotePath) => taskFor(remotePath) != null;

  /// Begin (or return the existing) download task for [file] and start it.
  /// Returns the task so callers can react if needed.
  RemoteDownloadTask startDownload(wd.File file) {
    final existing = taskFor(file.path);
    if (existing != null) return existing;
    final task = RemoteDownloadTask(file: file);
    task.addListener(_onTaskChanged);
    _tasks.add(task);
    notifyListeners();
    task.start();
    return task;
  }

  /// Remove a task from management (e.g. the user dismissed a finished one).
  /// Disposes it and stops listening.
  void removeTask(RemoteDownloadTask task) {
    if (!_tasks.remove(task)) return;
    task.removeListener(_onTaskChanged);
    task.dispose();
    notifyListeners();
  }

  void _onTaskChanged() {
    // Drop terminal tasks from the live list — they are now represented in the
    // completed-download section via the [RemoteDownloads] registry.
    final finished = _tasks.where((t) => t.isTerminal).toList();
    if (finished.isNotEmpty) {
      // IMPORTANT: this callback is invoked *from inside* the task's own
      // notifyListeners(). Disposing / removing the very ChangeNotifier that is
      // currently notifying trips Flutter's reentrancy assertion
      // (`_notificationCallStackDepth == 0`). Defer the mutation to a microtask
      // so it runs only after the task's notification stack has unwound.
      Future.microtask(() {
        for (final t in finished) {
          if (!_tasks.remove(t)) continue;
          t.removeListener(_onTaskChanged);
          t.dispose();
        }
        notifyListeners();
      });
    }
    // Notify listeners now so progress / state changes reach the UI
    // immediately. Cleanup happens in the deferred block above.
    notifyListeners();
  }
}
