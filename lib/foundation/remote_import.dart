import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/pdf/pdf_session.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/io.dart';

/// File type classification for remote files. Shared by the remote library UI
/// and the importer.
enum RemoteFileType { folder, image, pdf, archive, other }

RemoteFileType getFileType(wd.File file) {
  if (file.isDir == true) return RemoteFileType.folder;
  if (RemoteWebDav.isImageName(file.name)) return RemoteFileType.image;
  if (RemoteWebDav.isPdfName(file.name)) return RemoteFileType.pdf;
  if (RemoteWebDav.isArchiveName(file.name)) return RemoteFileType.archive;
  return RemoteFileType.other;
}

/// Downloads remote-library items to the local device and turns them into
/// local comics, mirroring the three remote comic formats:
///
/// - [importArchive]  : download a ZIP/CBZ and import it via [CBZ.import].
/// - [importWebDavFolder] : download a remote image folder (with optional
///   sub-folder chapters) and build a local image comic.
/// - [importPdf]      : download a PDF into the local comic library and
///   register it as a [LocalComic] (type [ComicType.pdf]) so it appears in the
///   local library and can be read offline by the streaming reader.
///
/// Every method splits into two phases — **download** (resumable, cancellable)
/// then **import** (local-only) — and reports which phase it is in via
/// [ImportProgress]. A [CancelToken] can interrupt the download phase; because
/// the download is resumable a later run picks up where it left off.
enum ImportStage {
  /// Downloading bytes / images from the remote server.
  download,

  /// Importing into the local library (extract / copy / register).
  import,
}

/// Progress reporter for [RemoteImporter] operations.
typedef ImportProgress = void Function(ImportStage stage, int current, int total);

class RemoteImporter {
  RemoteImporter._();

  /// Download a ZIP/CBZ and import it as a local image comic. The archive is
  /// first downloaded to a temp file (resumable), then imported. Returns the
  /// imported [LocalComic] (caller assigns the final id via [LocalManager.add]).
  static Future<LocalComic?> importArchive(
    wd.File file, {
    ImportProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final ext = RemoteWebDav.getFileExtension(file.name);
    final tempDir = Directory('${App.cachePath}/remote_zip');
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    final tempFile = File('${tempDir.path}/${file.name ?? "archive.$ext"}');

    await RemoteWebDav.downloadResumable(
      file.path!,
      tempFile.path,
      onProgress: (c, t) => onProgress?.call(ImportStage.download, c, t),
      cancelToken: cancel,
    );
    if (cancel?.isCancelled == true) return Future.value(null);

    try {
      return await CBZ.import(
        tempFile,
        onProgress: (c, t) => onProgress?.call(ImportStage.import, c, t),
      );
    } finally {
      try {
        if (tempFile.existsSync()) await tempFile.delete();
      } catch (_) {}
    }
  }

  /// Download a remote WebDAV folder (images, optionally organised into
  /// sub-folder chapters) and build a local image comic. [onProgress] reports
  /// the download progress as `(bytesDownloaded, totalBytes)` so the UI can
  /// show a meaningful bytes/sec rate. The download is resumable: a
  /// `.rvdownload` status file tracks which images are already on disk, so an
  /// interrupted import can be resumed image-by-image.
  static Future<LocalComic?> importWebDavFolder(
    String folderPath,
    String name, {
    ImportProgress? onProgress,
    CancelToken? cancel,
  }) async {
    Log.info("RemoteImport", "Starting folder import: $folderPath");

    // --- 第 1 步：获取章节结构 ---
    final chaptersMap = await RemoteWebDav.buildChapters(folderPath);
    if (chaptersMap.isEmpty) {
      throw Exception('No readable images in this folder');
    }
    Log.info("RemoteImport", "Found ${chaptersMap.length} chapter(s)");

    final dirs = chaptersMap.keys.toList();
    final single = dirs.length == 1 && chaptersMap[dirs[0]] == 'All';

    // --- 第 2 步：获取所有图片及其大小 ---
    final entriesPerDir = <String, List<ImageEntry>>{};
    var totalBytes = 0;
    var totalImages = 0;
    for (final dir in dirs) {
      try {
        final entries = await RemoteWebDav.listImageKeysWithSize(dir);
        entriesPerDir[dir] = entries;
        totalImages += entries.length;
        for (final e in entries) {
          totalBytes += e.size;
        }
      } catch (e) {
        // Skip chapters that can't be accessed (404, permission denied, etc.)
        // instead of failing the whole import.
        Log.warning("RemoteImport", "Skipping inaccessible chapter: $dir ($e)");
      }
    }
    if (entriesPerDir.isEmpty) {
      throw Exception('No accessible images in this folder');
    }
    Log.info("RemoteImport", "Found $totalImages image(s) in ${entriesPerDir.length} chapter(s), total size: ${bytesToReadableString(totalBytes)}");

    final dest = Directory(
      FilePath.join(LocalManager().path, sanitizeFileName(name)),
    );
    // --- 第 3 步：断点续传检查 ---
    final statusFile = File('${dest.path}.rvdownload');
    final done = <String>{};
    if (dest.existsSync()) {
      if (statusFile.existsSync()) {
        try {
          for (final line in statusFile.readAsLinesSync()) {
            if (line.isNotEmpty) done.add(line);
          }
        } catch (_) {}
        Log.info("RemoteImport", "Resuming: ${done.length} image(s) already downloaded");
      } else {
        throw Exception('Comic with name $name already exists');
      }
    } else {
      dest.createSync();
    }

    final downloaded = <File>[];
    Map<String, String>? cpMap;

    // Bytes downloaded so far. This is what [onProgress] reports as `current`,
    // so the UI can compute a correct bytes/sec rate.
    var downloadedBytes = 0;

    // Images that failed to download (after retries). Logged at the end so a
    // few bad images don't abort the whole folder import.
    final failedKeys = <String>[];

    // Throttle status-file writes: writing the full `done` set after every
    // image is a huge I/O bottleneck for large folders (the file grows to
    // MBs, each write takes longer). Write every 10 images instead.
    var writesPending = 0;

    void report() =>
        onProgress?.call(ImportStage.download, downloadedBytes, totalBytes);

    void markDone(String key) {
      done.add(key);
      writesPending++;
      if (writesPending >= 10) {
        _writeStatus(statusFile, done);
        writesPending = 0;
      }
    }

    if (single) {
      // Flat comic: images sit directly in [dest], kept under their original
      // remote file names.
      final entries = entriesPerDir[dirs[0]]!;
      for (final entry in entries) {
        if (cancel?.isCancelled == true) return Future.value(null);
        final key = entry.key;
        if (done.contains(key) && _destFile(key, dest).existsSync()) {
          // Already on disk from a previous run: count its bytes and move on.
          downloadedBytes += entry.size;
          report();
          continue;
        }
        final file = await _downloadOne(key, dest, failedKeys, entry.size);
        if (file != null) {
          // Only keep the first image for the cover; discard the rest to
          // avoid holding thousands of File objects in a large folder import.
          if (downloaded.isEmpty) downloaded.add(file);
          markDone(key);
          downloadedBytes += file.lengthSync();
        }
        report();
      }
    } else {
      // Multi-chapter: each sub-folder becomes a chapter directory that keeps
      // its original name (sanitized for the file system); images inside keep
      // their original file names too.
      cpMap = {};
      final usedDirNames = <String>{};
      for (final dir in dirs) {
        final chapterName = chaptersMap[dir]!;
        var chapterDirName = LocalManager.getChapterDirectoryName(chapterName);
        // Avoid two distinct chapters collapsing onto the same directory if
        // their names only differ in characters sanitized away (e.g. "a/b" vs
        // "a:b"). Append a counter until the name is unique.
        if (usedDirNames.contains(chapterDirName)) {
          var n = 2;
          while (usedDirNames.contains('$chapterDirName$n')) {
            n++;
          }
          chapterDirName = '$chapterDirName$n';
        }
        usedDirNames.add(chapterDirName);
        final chapterDest = Directory(
          FilePath.join(dest.path, chapterDirName),
        );
        chapterDest.createSync();
        final entries = entriesPerDir[dir]!;
        for (final entry in entries) {
          if (cancel?.isCancelled == true) return Future.value(null);
          final key = entry.key;
          if (done.contains(key) && _destFile(key, chapterDest).existsSync()) {
            // Already on disk from a previous run: count its bytes and move on.
            downloadedBytes += entry.size;
            report();
            continue;
          }
          final file = await _downloadOne(key, chapterDest, failedKeys, entry.size);
          if (file != null) {
            // Only keep the first image for the cover; discard the rest.
            if (downloaded.isEmpty) downloaded.add(file);
            markDone(key);
            downloadedBytes += file.lengthSync();
          }
          report();
        }
        // Chapter id = the on-disk directory name; the reader resolves it back
        // through [LocalManager.getChapterDirectoryName] (idempotent on an
        // already-sanitized name), which yields [chapterDest].
        cpMap[chapterDirName] = chapterName;
      }
    }

    if (downloaded.isEmpty && done.isEmpty) {
      await dest.delete(recursive: true);
      throw Exception('No images found');
    }

    // Final status write to flush any remaining pending keys.
    if (writesPending > 0) {
      _writeStatus(statusFile, done);
    }

    // Drop the resume status file now that every image is on disk.
    try {
      if (statusFile.existsSync()) await statusFile.delete();
    } catch (_) {}

    // Import phase: copy the first available image to a `cover.<ext>` so the
    // comic shows up in the library grid.
    onProgress?.call(ImportStage.import, 0, 1);
    final coverFile = downloaded.isNotEmpty
        ? downloaded.first
        : _firstImageIn(dest);
    if (coverFile != null) {
      await coverFile.copyMem(
        FilePath.join(dest.path, 'cover.${coverFile.extension}'),
      );
    }
    onProgress?.call(ImportStage.import, 1, 1);

    // Surface any per-image failures as a single warning instead of aborting
    // the whole import — a few bad images in a large folder shouldn't discard
    // the hundreds that succeeded.
    if (failedKeys.isNotEmpty) {
      Log.warning(
        "RemoteImport",
        "Failed to download ${failedKeys.length} image(s) in folder '$name'",
      );
    }

    return LocalComic(
      id: LocalManager().findValidId(ComicType.local),
      title: name,
      subtitle: '',
      tags: const [],
      comicType: ComicType.local,
      directory: dest.name,
      chapters: ComicChapters.fromJsonOrNull(cpMap),
      downloadedChapters: cpMap?.keys.toList() ?? [],
      cover: coverFile != null ? 'cover.${coverFile.extension}' : '',
      createdAt: DateTime.now(),
    );
  }

  /// Download a remote PDF into the local comic library and register it as a
  /// [LocalComic] (type [ComicType.local]) so it appears in "本地漫画", is
  /// labelled "本地导入" in history/favorites, and can be read offline. Returns
  /// the imported [LocalComic] together with the absolute path of the
  /// downloaded PDF file. The PDF is downloaded to a temp file first
  /// (resumable), then moved into its final library folder.
  static Future<(LocalComic, String)?> importPdf(
    wd.File file, {
    ImportProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final tempDir = Directory('${App.cachePath}/remote_pdf');
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    final tempFile = File('${tempDir.path}/${file.name ?? "file.pdf"}');

    await RemoteWebDav.downloadResumable(
      file.path!,
      tempFile.path,
      onProgress: (c, t) => onProgress?.call(ImportStage.download, c, t),
      cancelToken: cancel,
    );
    if (cancel?.isCancelled == true) return Future.value(null);

    final folderName = sanitizeFileName(file.name ?? 'PDF');
    final dest = Directory(FilePath.join(LocalManager().path, folderName));
    if (dest.existsSync()) {
      throw Exception('Comic with name ${file.name ?? 'PDF'} already exists');
    }
    dest.createSync(recursive: true);

    final seed = file.path ?? file.name ?? 'pdf';
    final hash = sha1.convert(seed.codeUnits).toString().substring(0, 16);
    final pdfName = '$hash.pdf';
    final localPath = FilePath.join(dest.path, pdfName);
    await tempFile.rename(localPath);

    // Render a cover from the first PDF page so it shows up in the library
    // grid (falls back to no cover if rendering fails).
    Uint8List? cover;
    try {
      cover = await PdfSessionManager().renderCoverLocal(localPath);
    } catch (_) {
      cover = null;
    }
    if (cover != null) {
      await File(FilePath.join(dest.path, 'cover.png')).writeAsBytes(cover);
    }

    onProgress?.call(ImportStage.import, 1, 1);

    final comic = LocalComic(
      id: LocalManager().findValidId(ComicType.local),
      title: file.name ?? 'PDF',
      subtitle: '',
      tags: const [],
      directory: folderName,
      chapters: null,
      cover: cover != null ? 'cover.png' : '',
      comicType: ComicType.local,
      downloadedChapters: const [],
      createdAt: DateTime.now(),
    );
    return (comic, localPath);
  }

  /// Write the set of completed image keys to the resume status file. Each
  /// key is written on its own line.
  static Future<void> _writeStatus(File file, Set<String> done) async {
    try {
      await file.writeAsString(done.join('\n'));
    } catch (_) {}
  }

  /// Compute the destination file for [webdavKey] inside [dir], preserving the
  /// original remote file name (sanitized for the local file system).
  static File _destFile(String webdavKey, Directory dir) {
    final path = RemoteWebDav.decodeKey(webdavKey);
    final name = sanitizeFileName(path.split('/').last);
    return File(FilePath.join(dir.path, name));
  }

  /// First image file anywhere under [dir] (used as a fallback cover when the
  /// download was fully resumed and [downloaded] is empty).
  static File? _firstImageIn(Directory dir) {
    final collected = <File>[];
    void collect(Directory d) {
      if (!d.existsSync()) return;
      for (final f in d.listSync()) {
        if (f is Directory) {
          collect(f);
        } else if (f is File && RemoteWebDav.isImageName(f.name)) {
          collected.add(f);
        }
      }
    }
    collect(dir);
    if (collected.isEmpty) return null;
    collected.sort((a, b) => naturalCompare(a.path, b.path));
    return collected.first;
  }

  /// Download a single remote image to [dir]. Uses a streaming download
  /// ([RemoteWebDav.downloadToFile]) instead of [RemoteWebDav.readFile] so the
  /// whole file is never held in memory at once — important for large folders
  /// where many multi-MB images would otherwise OOM the app.
  ///
  /// Retries up to 3 times on transient failures. Returns the downloaded [File]
  /// on success, or `null` if all attempts fail — the key is appended to
  /// [failedKeys] so the caller can log a summary instead of aborting the
  /// whole import.
  static Future<File?> _downloadOne(
    String webdavKey,
    Directory dir,
    List<String> failedKeys,
    int expectedSize,
  ) async {
    final path = RemoteWebDav.decodeKey(webdavKey);
    final f = _destFile(webdavKey, dir);
    Log.info("RemoteImport", "Downloading: key=$webdavKey, decoded=$path, dest=${f.path}");
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await RemoteWebDav.downloadToFile(path, f.path);
        return f;
      } catch (e) {
        Log.warning(
          "RemoteImport",
          "Failed to download image (attempt $attempt/$maxAttempts): $path ($e)",
        );
        // Clean up the partial file before retrying.
        try {
          if (f.existsSync()) await f.delete();
        } catch (_) {}
        if (attempt == maxAttempts) {
          failedKeys.add(webdavKey);
          return null;
        }
        // Exponential backoff before retrying — also helps if the server is
        // throttling us (HTTP 429): wait longer on each attempt rather than
        // immediately re-firing into the rate limit.
        final backoffMs = 500 * (1 << (attempt - 1)); // 500, 1000, 2000 ms
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
    return null; // Unreachable, but keeps the analyzer happy.
  }
}
