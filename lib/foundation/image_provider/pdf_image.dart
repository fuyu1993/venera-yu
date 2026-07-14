import 'dart:async' show Future;
import 'dart:convert' show base64Decode;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/pdf/pdf_session.dart';
import 'base_image_provider.dart';
import 'pdf_image.dart' as image_provider;

/// Image provider that renders one page of a remote PDF (via [PdfSession]) to
/// PNG on demand, so PDF pages can be shown by the built-in comic reader.
class PdfImageProvider
    extends BaseImageProvider<image_provider.PdfImageProvider> {
  const PdfImageProvider(this.sessionKey, this.page,
      {this.enableResize = false});

  /// The [PdfSession] key (the WebDAV file path, same as reader `cid`).
  final String sessionKey;

  /// 0-based page index.
  final int page;

  @override
  final bool enableResize;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    final session = PdfSessionManager().get(sessionKey);
    if (session == null) {
      throw 'Error: PDF session not found.';
    }
    checkStop();
    final bytes = await session.renderPage(page);
    checkStop();
    return bytes;
  }

  @override
  Future<PdfImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "pdfpage://$sessionKey/$page@$enableResize";
}

/// Cover/thumbnail image provider for a remote PDF in the history grid.
///
/// Renders the first page on demand via [PdfSessionManager.renderCover]. If the
/// PDF can't be opened (offline, deleted, etc.) it falls back to a 1x1 white
/// PNG so the tile still paints instead of throwing.
class PdfCoverImageProvider
    extends BaseImageProvider<image_provider.PdfCoverImageProvider> {
  const PdfCoverImageProvider(this.remotePath, this.title);

  /// The WebDAV file path (also the [PdfSession] key / reader `cid`).
  final String remotePath;

  final String title;

  /// A 1x1 white PNG used when the cover can't be rendered.
  static final Uint8List _placeholder = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    final bytes = await PdfSessionManager().renderCover(remotePath);
    checkStop();
    return bytes ?? _placeholder;
  }

  @override
  Future<PdfCoverImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "pdfcover://$remotePath";
}
