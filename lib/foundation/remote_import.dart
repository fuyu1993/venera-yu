import 'package:crypto/crypto.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/pdf/pdf_session.dart';
import 'package:venera/foundation/remote_webdav.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/io.dart';

/// Downloads remote-library items to the local device and turns them into
/// local comics, mirroring the three remote comic formats:
///
/// - [importArchive]  : download a ZIP/CBZ and import it via [CBZ.import].
/// - [importWebDavFolder] : download a remote image folder (with optional
///   sub-folder chapters) and build a local image comic.
/// - [importPdf]      : download a PDF into the local comic library and
///   register it as a [LocalComic] (type [ComicType.pdf]) so it appears in the
///   local library and can be read offline by the streaming reader.
/// Phase of a download-and-import operation, reported via [ImportProgress].
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

  /// Download a ZIP/CBZ and import it as a local image comic. Returns the
  /// imported [LocalComic] (caller assigns the final id via [LocalManager.add]).
  static Future<LocalComic> importArchive(
    wd.File file, {
    ImportProgress? onProgress,
  }) async {
    final bytes = await RemoteWebDav.readFile(
      file.path!,
      onProgress: (c, t) => onProgress?.call(ImportStage.download, c, t),
    );
    final ext = RemoteWebDav.getFileExtension(file.name);
    final tempDir = Directory('${App.cachePath}/remote_zip');
    if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    final tempFile = File('${tempDir.path}/${file.name ?? "archive.$ext"}');
    await tempFile.writeAsBytes(bytes);
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
  /// the number of images downloaded so far and the total.
  static Future<LocalComic> importWebDavFolder(
    String folderPath,
    String name, {
    ImportProgress? onProgress,
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
    if (dest.existsSync()) {
      throw Exception('Comic with name $name already exists');
    }
    dest.createSync();

    final downloaded = <File>[];
    Map<String, String>? cpMap;
    var done = 0;

    if (single) {
      final keys = keysPerDir[dirs[0]]!;
      for (var i = 0; i < keys.length; i++) {
        downloaded.add(await _downloadOne(keys[i], dest, '${i + 1}'));
        done++;
        onProgress?.call(ImportStage.download, done, total);
      }
    } else {
      cpMap = {};
      for (var ci = 0; ci < dirs.length; ci++) {
        final dir = dirs[ci];
        final chapterDest =
            Directory(FilePath.join(dest.path, ci.toString()));
        chapterDest.createSync();
        final keys = keysPerDir[dir]!;
        for (var i = 0; i < keys.length; i++) {
          downloaded.add(await _downloadOne(keys[i], chapterDest, '${i + 1}'));
          done++;
          onProgress?.call(ImportStage.download, done, total);
        }
        cpMap[ci.toString()] = chaptersMap[dir]!;
      }
    }

    if (downloaded.isEmpty) {
      await dest.delete(recursive: true);
      throw Exception('No images found');
    }

    final coverFile = downloaded.first;
    await coverFile.copyMem(
      FilePath.join(dest.path, 'cover.${coverFile.extension}'),
    );
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
      cover: 'cover.${coverFile.extension}',
      createdAt: DateTime.now(),
    );
  }

  /// Download a remote PDF into the local comic library and register it as a
  /// [LocalComic] (type [ComicType.pdf]) so it appears in "本地漫画" and can be
  /// read offline. Returns the imported [LocalComic] together with the absolute
  /// path of the downloaded PDF file.
  static Future<(LocalComic, String)> importPdf(
    wd.File file, {
    ImportProgress? onProgress,
  }) async {
    final bytes = await RemoteWebDav.readFile(
      file.path!,
      onProgress: (c, t) => onProgress?.call(ImportStage.download, c, t),
    );
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
    await File(localPath).writeAsBytes(bytes);

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
      id: LocalManager().findValidId(ComicType.pdf),
      title: file.name ?? 'PDF',
      subtitle: '',
      tags: const [],
      directory: folderName,
      chapters: null,
      cover: cover != null ? 'cover.png' : '',
      comicType: ComicType.pdf,
      downloadedChapters: const [],
      createdAt: DateTime.now(),
    );
    return (comic, localPath);
  }

  static Future<File> _downloadOne(
    String webdavKey,
    Directory dir,
    String index,
  ) async {
    final path = RemoteWebDav.decodeKey(webdavKey);
    final bytes = await RemoteWebDav.readFile(path);
    final ext = RemoteWebDav.getFileExtension(path.split('/').last);
    final f = File(FilePath.join(dir.path, '$index.$ext'));
    await f.writeAsBytes(bytes);
    return f;
  }
}
