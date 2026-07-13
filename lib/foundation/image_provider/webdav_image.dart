import 'dart:async' show Future, StreamController;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/image_provider/base_image_provider.dart';
import 'package:venera/foundation/remote_webdav.dart';

/// Image provider that loads image bytes directly from a remote WebDAV drive.
///
/// The [imageKey] is a `webdav://`-prefixed, URL-encoded remote file path
/// produced by [RemoteWebDav.encodeKey].
class WebDavImageProvider
    extends BaseImageProvider<WebDavImageProvider> {
  const WebDavImageProvider(
    this.imageKey,
    this.sourceKey,
    this.cid,
    this.eid,
    this.page, {
    this.enableResize = false,
  });

  final String imageKey;

  final String? sourceKey;

  final String cid;

  final String eid;

  final int page;

  @override
  final bool enableResize;

  @override
  Future<Uint8List> load(
    StreamController<ImageChunkEvent> chunkEvents,
    void Function() checkStop,
  ) async {
    var path = RemoteWebDav.decodeKey(imageKey);
    Uint8List bytes;
    try {
      bytes = await RemoteWebDav.readFile(path);
    } catch (e) {
      throw 'Failed to load remote image: $e';
    }
    if (bytes.isEmpty) {
      throw 'Error: Empty image data.';
    }
    return bytes;
  }

  @override
  Future<WebDavImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => '$imageKey@$sourceKey@$cid@$eid@$enableResize';
}
