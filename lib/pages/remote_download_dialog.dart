import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/remote_downloads.dart';
import 'package:venera/foundation/remote_download_task.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/utils/translations.dart';

/// Shows a modal dialog that drives a [RemoteDownloadTask] with Start / Pause
/// / Cancel controls, a live progress bar and status line. On completion it
/// closes itself and opens the imported comic's page.
Future<void> showRemoteDownloadDialog(
  BuildContext context, {
  required wd.File file,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RemoteDownloadDialog(file: file),
  );
}

class RemoteDownloadDialog extends StatefulWidget {
  const RemoteDownloadDialog({super.key, required this.file});

  final wd.File file;

  @override
  State<RemoteDownloadDialog> createState() => _RemoteDownloadDialogState();
}

class _RemoteDownloadDialogState extends State<RemoteDownloadDialog> {
  late final RemoteDownloadTask task;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    task = RemoteDownloadTask(file: widget.file);
    task.addListener(_onTaskChanged);
  }

  @override
  void dispose() {
    task.removeListener(_onTaskChanged);
    task.dispose();
    super.dispose();
  }

  void _onTaskChanged() {
    if (!mounted) return;
    if (task.state == RemoteDownloadState.completed) {
      _navigateToComic();
    }
    setState(() {});
  }

  void _navigateToComic() {
    if (_navigated) return;
    _navigated = true;
    final record = RemoteDownloads.get(widget.file.path!);
    Navigator.of(context).pop();
    if (record != null && record.comicId != null) {
      context.to(() => ComicPage(
            id: record.comicId!,
            sourceKey: 'local',
            cover: '',
            title: record.name,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.file.name ?? 'Download'.tl,
      content: _buildContent(context),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final s = task.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_statusText(s)),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: s == RemoteDownloadState.completed ? 1.0 : task.progress,
          backgroundColor: context.colorScheme.surfaceContainer,
        ),
        if (s == RemoteDownloadState.error && task.error != null) ...[
          const SizedBox(height: 8),
          Text(
            task.error!,
            style: TextStyle(color: context.colorScheme.error, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ).paddingHorizontal(4);
  }

  String _statusText(RemoteDownloadState s) {
    switch (s) {
      case RemoteDownloadState.idle:
        return 'Ready to download'.tl;
      case RemoteDownloadState.running:
        return task.message;
      case RemoteDownloadState.paused:
        return 'Paused'.tl;
      case RemoteDownloadState.completed:
        return 'Completed'.tl;
      case RemoteDownloadState.error:
        return 'Error'.tl;
      case RemoteDownloadState.canceled:
        return 'Canceled'.tl;
    }
  }

  List<Widget> _buildActions(BuildContext context) {
    final s = task.state;
    final buttons = <Widget>[];

    // Primary control: Start (idle/error) / Resume (paused) / Pause (running).
    if (s == RemoteDownloadState.running) {
      buttons.add(FilledButton(
        onPressed: task.pause,
        child: Text('Pause'.tl),
      ));
    } else if (s != RemoteDownloadState.completed &&
        s != RemoteDownloadState.canceled) {
      buttons.add(FilledButton(
        onPressed: task.start,
        child: Text(s == RemoteDownloadState.paused ? 'Resume'.tl : 'Start'.tl),
      ));
    }

    // Cancel is available unless we already finished or were canceled.
    if (s != RemoteDownloadState.completed &&
        s != RemoteDownloadState.canceled) {
      buttons.add(OutlinedButton(
        onPressed: () {
          task.cancel();
          Navigator.of(context).pop();
        },
        child: Text('Cancel'.tl),
      ));
    } else {
      // Terminal state: a single Close button.
      buttons.add(FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Close'.tl),
      ));
    }

    return buttons;
  }
}
