import 'dart:async' show Future;
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
