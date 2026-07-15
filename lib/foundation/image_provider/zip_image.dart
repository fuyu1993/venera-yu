import 'dart:async' show Future;
import 'dart:convert' show base64Decode;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/zip/zip_session.dart';
import 'base_image_provider.dart';
import 'zip_image.dart' as image_provider;

/// Image provider that renders one image entry of a remote ZIP (via
/// [ZipSession]) on demand, so ZIP comics can be shown by the built-in comic
/// reader — the same role [PdfImageProvider] plays for PDFs.
class ZipImageProvider
    extends BaseImageProvider<image_provider.ZipImageProvider> {
  const ZipImageProvider(this.sessionKey, this.page, {this.enableResize = false});

  /// The [ZipSession] key (the WebDAV file path, same as reader `cid`).
  final String sessionKey;

  /// 0-based image index inside the archive.
  final int page;

  @override
  final bool enableResize;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    final session = ZipSessionManager().get(sessionKey);
    if (session == null) {
      throw 'Error: ZIP session not found.';
    }
    checkStop();
    final bytes = await session.renderPage(page);
    checkStop();
    return bytes;
  }

  @override
  Future<ZipImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "zippage://$sessionKey/$page@$enableResize";
}

/// Cover/thumbnail image provider for a remote ZIP in the history grid.
///
/// Renders the first image entry on demand via [ZipSessionManager.renderCover].
/// If the archive can't be opened it falls back to a 1x1 white PNG so the tile
/// still paints instead of throwing.
class ZipCoverImageProvider
    extends BaseImageProvider<image_provider.ZipCoverImageProvider> {
  const ZipCoverImageProvider(this.remotePath, this.title);

  /// The WebDAV file path (also the [ZipSession] key / reader `cid`).
  final String remotePath;

  final String title;

  /// A 1x1 white PNG used when the cover can't be rendered.
  static final Uint8List _placeholder = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    final bytes = await ZipSessionManager().renderCover(remotePath);
    checkStop();
    return bytes ?? _placeholder;
  }

  @override
  Future<ZipCoverImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "zipcover://$remotePath";
}
