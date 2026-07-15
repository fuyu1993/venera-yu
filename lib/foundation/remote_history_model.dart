import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';

/// Minimal history model used to seed a [History] for a remote or imported
/// comic (PDF / ZIP / WebDAV folder) that has no real comic-source model.
class RemoteHistoryModel with HistoryMixin {
  @override
  final String title;

  @override
  final String id;

  @override
  final String cover;

  final ComicType _type;

  @override
  String? get subTitle => null;

  @override
  ComicType get historyType => _type;

  RemoteHistoryModel(this.id, this.title, this.cover,
      [this._type = ComicType.webdav]);
}
