import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
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
  /// the number of images downloaded so far and the total. The download is
  /// resumable: a `.rvdownload` status file tracks which images are already on
  /// disk, so an interrupted import can be resumed image-by-image.
  static Future<LocalComic?> importWebDavFolder(
    String folderPath,
    String name, {
    ImportProgress? onProgress,
    CancelToken? cancel,
  }) async {
    final chaptersMap = await RemoteWebDav.buildChapters(folderPath);
    if (chaptersMap.isEmpty) {
      throw Exception('No readable images in this folder');
    }
    final dirs = chaptersMap.keys.toList();
    final single = dirs.length == 1 && chaptersMap[dirs[0]] == 'All';

    // Pre-fetch image keys and the total count for progress reporting.
    final keysPerDir = <String, List<String>>{};
    var total = 0;
    for (final dir in dirs) {
      final keys = await RemoteWebDav.getImagesForChapter(dir);
      keysPerDir[dir] = keys;
      total += keys.length;
    }

    final dest = Directory(
      FilePath.join(LocalManager().path, sanitizeFileName(name)),
    );
    // Resume bookkeeping: a status file lists the image keys already flushed
    // to [dest]. If the comic already exists without a status file, the user
    // is re-importing something that completed — refuse to clobber it.
    final statusFile = File('${dest.path}.rvdownload');
    final done = <String>{};
    if (dest.existsSync()) {
      if (statusFile.existsSync()) {
        try {
          for (final line in statusFile.readAsLinesSync()) {
            if (line.isNotEmpty) done.add(line);
          }
        } catch (_) {}
      } else {
        throw Exception('Comic with name $name already exists');
      }
    } else {
      dest.createSync();
    }

    final downloaded = <File>[];
    Map<String, String>? cpMap;
    var completed = done.length;

    void report() => onProgress?.call(ImportStage.download, completed, total);

    if (single) {
      // Flat comic: images sit directly in [dest], kept under their original
      // remote file names.
      final keys = keysPerDir[dirs[0]]!;
      for (final key in keys) {
        if (cancel?.isCancelled == true) return Future.value(null);
        if (done.contains(key) && _destFile(key, dest).existsSync()) {
          report();
          continue;
        }
        downloaded.add(await _downloadOne(key, dest));
        done.add(key);
        await _writeStatus(statusFile, done);
        completed++;
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
        final keys = keysPerDir[dir]!;
        for (final key in keys) {
          if (cancel?.isCancelled == true) return Future.value(null);
          if (done.contains(key) && _destFile(key, chapterDest).existsSync()) {
            report();
            continue;
          }
          downloaded.add(await _downloadOne(key, chapterDest));
          done.add(key);
          await _writeStatus(statusFile, done);
          completed++;
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

  static Future<File> _downloadOne(
    String webdavKey,
    Directory dir,
  ) async {
    final path = RemoteWebDav.decodeKey(webdavKey);
    final bytes = await RemoteWebDav.readFile(path);
    final f = _destFile(webdavKey, dir);
    await f.writeAsBytes(bytes);
    return f;
  }
}
