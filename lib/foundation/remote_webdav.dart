import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/network/app_dio.dart';

/// Remote library WebDAV manager.
///
/// Provides configuration access, a shared webdav client and the helpers used
/// by the remote library page and the reader to browse / read files stored on
/// a remote WebDAV drive.
class RemoteWebDav {
  static const String configKey = 'remoteWebDav';

  static const String rootKey = 'remoteLibraryRoot';

  static const String enableKey = 'enableRemoteLibrary';

  /// Whether the remote library feature is enabled (lab toggle).
  static bool get enabled => appdata.settings[enableKey] == true;

  /// Whether a valid [url, user, pass] triple is configured.
  static bool get isConfigured {
    var c = appdata.settings[configKey];
    return c is List && c.whereType<String>().length == 3;
  }

  /// Configured root path on the remote drive (always starts with '/').
  static String get root {
    var r = appdata.settings[rootKey];
    if (r is! String || r.isEmpty) return '/';
    return r.startsWith('/') ? r : '/$r';
  }

  /// Build a webdav client using the dedicated remote-library credentials.
  static Client? getClient() {
    if (!isConfigured) return null;
    var c = appdata.settings[configKey] as List;
    return newClient(
      c[0],
      user: c[1],
      password: c[2],
      adapter: RHttpAdapter(),
    );
  }

  /// Encode a remote file path into an image key understood by
  /// [WebDavImageProvider].
  static String encodeKey(String path) => 'webdav://${Uri.encodeComponent(path)}';

  /// Decode an image key back into a remote file path.
  static String decodeKey(String key) {
    if (key.startsWith('webdav://')) {
      return Uri.decodeComponent(key.substring('webdav://'.length));
    }
    return key;
  }

  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'jpe',
    'png',
    'webp',
    'gif',
    'bmp',
    'avif',
    'heic',
    'heif',
    'tif',
    'tiff',
    'jfif',
    'jxl',
  ];

  /// Whether a file name looks like an image.
  static bool isImageName(String? name) {
    if (name == null) return false;
    var i = name.lastIndexOf('.');
    if (i < 0) return false;
    return _imageExtensions.contains(name.substring(i + 1).toLowerCase());
  }

  /// Whether a file name looks like a PDF.
  static bool isPdfName(String? name) {
    if (name == null) return false;
    var i = name.lastIndexOf('.');
    if (i < 0) return false;
    return name.substring(i + 1).toLowerCase() == 'pdf';
  }

  /// Whether a file name looks like a comic archive.
  static bool isArchiveName(String? name) {
    if (name == null) return false;
    var i = name.lastIndexOf('.');
    if (i < 0) return false;
    var ext = name.substring(i + 1).toLowerCase();
    return ['cbz', 'zip', 'cbr', 'rar', '7z'].contains(ext);
  }

  /// Get the file extension (lowercase, without dot), or empty string.
  static String getFileExtension(String? name) {
    if (name == null) return '';
    var i = name.lastIndexOf('.');
    if (i < 0) return '';
    return name.substring(i + 1).toLowerCase();
  }

  /// List the entries of a remote directory.
  static Future<List<File>> readDir(String path) async {
    var client = getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    var files = await client.readDir(path);
    files.removeWhere((e) => e.name == null);
    return files;
  }

  /// Read the raw bytes of a remote file.
  static Future<Uint8List> readFile(String path) async {
    var client = getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    return Uint8List.fromList(await client.read(path));
  }

  /// Stream a remote file directly to a local path with download progress.
  ///
  /// Unlike [readFile], this does not load the whole file into memory, which
  /// matters for multi-GB PDFs.
  static Future<void> downloadToFile(
    String path,
    String savePath, {
    void Function(int count, int total)? onProgress,
  }) async {
    var client = getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    await client.read2File(path, savePath, onProgress: onProgress);
  }

  /// Get the byte size of a remote file via PROPFIND.
  static Future<int> fileSize(String path) async {
    var client = getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    var file = await client.readProps(path);
    return file.size ?? 0;
  }

  /// Perform a HTTP Range GET and write the received bytes into [raf] at
  /// [start].
  ///
  /// This is the core of progressive (streaming) PDF reading: the reader can
  /// fetch the tail (where the xref lives) and then arbitrary byte ranges as
  /// the user scrolls, without downloading the whole multi-GB file up front.
  ///
  /// Returns the HTTP status code:
  /// - `206` partial content: the requested range was written to [raf].
  /// - `200` full content: the server ignored the Range header (range is not
  ///   supported), the response stream was consumed but **not** written — the
  ///   caller should fall back to a full sequential download.
  static Future<int> downloadRange(
    String path,
    int start,
    int end,
    RandomAccessFile raf, {
    Client? client,
    CancelToken? cancelToken,
    void Function(int count, int total)? onProgress,
  }) async {
    client ??= getClient();
    if (client == null) throw 'Remote WebDAV not configured';
    if (start < 0 || end < start) return 0;

    late Response<ResponseBody> resp;
    try {
      resp = await client.c.req<ResponseBody>(
        client,
        'GET',
        path,
        optionsHandler: (options) {
          options.responseType = ResponseType.stream;
          options.headers ??= {};
          options.headers?['Range'] = 'bytes=$start-$end';
        },
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != null) return e.response!.statusCode!;
      rethrow;
    }

    final status = resp.statusCode ?? 0;
    final stream = resp.data?.stream;
    if (stream == null) {
      throw Exception('Empty response (HTTP $status)');
    }

    if (status == 206) {
      // Partial content: write exactly this range at the requested offset.
      await raf.setPosition(start);
      var received = 0;
      final total = end - start + 1;
      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      return 206;
    } else {
      // 200 (or anything else): Range unsupported. Read the full stream but
      // keep only the requested [start, end] range by draining the prefix,
      // writing the middle, then draining the rest. This lets on-demand reads
      // work even when the server ignores Range.
      var pos = 0;
      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        var cStart = 0;
        var cEnd = chunk.length;
        if (pos < start) {
          if (pos + cEnd <= start) {
            pos += cEnd;
            continue;
          }
          cStart = start - pos;
        }
        if (pos + cEnd > end + 1) {
          cEnd = end + 1 - pos;
        }
        if (cEnd > cStart) {
          await raf.setPosition(pos + cStart);
          await raf.writeFrom(chunk.sublist(cStart, cEnd));
        }
        pos += chunk.length;
        if (pos > end) break;
      }
      return status;
    }
  }

  /// List image keys (webdav:// encoded) inside a directory, sorted by name.
  static Future<List<String>> listImageKeys(String dirPath) async {
    var files = await readDir(dirPath);
    var imgs = files
        .where((e) => e.isDir != true && isImageName(e.name))
        .toList();
    imgs.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return imgs.map((e) => encodeKey(e.path!)).toList();
  }

  /// Inspect a folder and build a chapter map for the reader.
  ///
  /// Returns a map where the **key** is the directory path (passed back to
  /// [getImagesForChapter]) and the **value** is the display title.
  /// - If the folder only contains images -> one chapter "All".
  /// - If the folder contains sub folders -> one chapter per sub folder.
  /// - Top level images mixed with sub folders are added as an "Others" chapter.
  static Future<Map<String, String>> buildChapters(String folderPath) async {
    var files = await readDir(folderPath);
    var subDirs = files
        .where((e) => e.isDir == true && e.name != null)
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    var imgs = files.where((e) => e.isDir != true && isImageName(e.name)).toList();
    var map = <String, String>{};
    if (subDirs.isNotEmpty) {
      for (var d in subDirs) {
        map[d.path!] = d.name!;
      }
      if (imgs.isNotEmpty) {
        map[folderPath] = 'Others';
      }
    } else if (imgs.isNotEmpty) {
      map[folderPath] = 'All';
    }
    return map;
  }

  /// Return the image keys for a given chapter (directory path).
  static Future<List<String>> getImagesForChapter(String chapterPath) async {
    return await listImageKeys(chapterPath);
  }
}
