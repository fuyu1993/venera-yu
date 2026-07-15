import 'package:venera/foundation/comic_source/comic_source.dart';

class ComicType {
  final int value;

  const ComicType(this.value);

  @override
  bool operator ==(Object other) => other is ComicType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  String get sourceKey {
    if(this == local) {
      return "local";
    } else if(this == webdav) {
      return "webdav";
    } else if(this == pdf) {
      return "pdf";
    } else if(this == zip) {
      return "zip";
    } else {
      return comicSource!.key;
    }
  }

  ComicSource? get comicSource {
    if(this == local || this == webdav || this == pdf || this == zip) {
      return null;
    } else {
      return ComicSource.fromIntKey(value);
    }
  }

  static const local = ComicType(0);

  /// Remote WebDAV library comic type.
  static const webdav = ComicType(1001);

  /// Remote PDF read as a comic: each page is rendered to an image on demand
  /// and served to the built-in comic reader.
  static const pdf = ComicType(2001);

  /// Remote ZIP/CBZ comic read as a comic: each image entry is fetched on
  /// demand (WebDAV Range) and inflated, then served to the built-in reader —
  /// exactly like [pdf], but for archive comics instead of PDF pages.
  static const zip = ComicType(3001);

  factory ComicType.fromKey(String key) {
    if(key == "local") {
      return local;
    } else if(key == "webdav") {
      return webdav;
    } else if(key == "pdf") {
      return pdf;
    } else if(key == "zip") {
      return zip;
    } else {
      return ComicType(key.hashCode);
    }
  }

  /// Unified, human-readable source label for badges across History /
  /// Favorites / Reader. Three top-level categories:
  ///   - 本地导入
  ///       [local] (imported local comics)
  ///   - 远程书库/PDF | 远程书库/ZIP | 远程书库/FolderComic
  ///       [pdf] / [zip] / [webdav]
  ///   - 漫画源/`<key>`
  ///       installed comic-source plugins (e-hentai, jm, ...), where `<key>`
  ///       is the source's machine key passed via [sourceKey].
  ///
  /// [sourceKey] must be the comic's machine source key (e.g. from
  /// [Comic.sourceKey]); it is only consulted for plugin sources.
  static String sourceLabel(ComicType type, String sourceKey) {
    if (type == local) return '本地导入';
    if (type == webdav) return '远程书库/FolderComic';
    if (type == pdf) return '远程书库/PDF';
    if (type == zip) return '远程书库/ZIP';
    if (sourceKey.startsWith('Unknown')) return 'Unknown';
    return '漫画源/$sourceKey';
  }
}