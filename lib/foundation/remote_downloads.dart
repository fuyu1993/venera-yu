import 'package:venera/foundation/appdata.dart';

/// A record of a remote-library item that has been downloaded/imported to the
/// local device so it can be re-opened offline.
///
/// - `pdf`:   downloaded to a local file and read by the streaming reader.
/// - `zip`:   downloaded and imported as a local image comic ([comicId]).
/// - `folder`: images downloaded and imported as a local image comic ([comicId]).
class RemoteDownloadEntry {
  RemoteDownloadEntry({
    required this.remotePath,
    required this.type,
    required this.name,
    this.comicId,
    this.localPath,
  });

  final String remotePath;

  /// `'pdf'`, `'zip'` or `'folder'`.
  final String type;

  final String name;

  /// Local comic id, for `zip` / `folder` imports.
  final String? comicId;

  /// Local PDF file path, for `pdf` downloads.
  final String? localPath;

  Map<String, dynamic> toJson() => {
        'remotePath': remotePath,
        'type': type,
        'name': name,
        if (comicId != null) 'comicId': comicId,
        if (localPath != null) 'localPath': localPath,
      };

  factory RemoteDownloadEntry.fromJson(Map<String, dynamic> json) =>
      RemoteDownloadEntry(
        remotePath: json['remotePath'],
        type: json['type'],
        name: json['name'],
        comicId: json['comicId'],
        localPath: json['localPath'],
      );
}

/// Persistent registry (under [appdata] settings) of remote items that have
/// been imported/downloaded, keyed by their remote path. Let the remote
/// library show an "imported/downloaded" badge and re-open the local copy.
class RemoteDownloads {
  static const String _key = 'remoteDownloads';

  static List<Map<String, dynamic>> _read() {
    final v = appdata.settings[_key];
    if (v is List) return List<Map<String, dynamic>>.from(v, growable: true);
    return <Map<String, dynamic>>[];
  }

  static void _write(List<Map<String, dynamic>> list) {
    appdata.settings[_key] = list;
    appdata.saveData();
  }

  /// Look up the import/download record for [remotePath], or `null`.
  static RemoteDownloadEntry? get(String remotePath) {
    for (final m in _read()) {
      if (m['remotePath'] == remotePath) {
        return RemoteDownloadEntry.fromJson(m);
      }
    }
    return null;
  }

  static bool has(String remotePath) => get(remotePath) != null;

  /// Insert or replace the record for an item.
  static void record(RemoteDownloadEntry entry) {
    final list = _read();
    list.removeWhere((m) => m['remotePath'] == entry.remotePath);
    list.add(entry.toJson());
    _write(list);
  }

  /// Remove a record (e.g. when deleting a downloaded PDF).
  static void remove(String remotePath) {
    final list = _read();
    list.removeWhere((m) => m['remotePath'] == remotePath);
    _write(list);
  }
}
