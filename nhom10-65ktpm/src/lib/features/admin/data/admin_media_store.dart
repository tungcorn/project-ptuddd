import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/cloud/firebase_services.dart';
import '../../songs/domain/song.dart';

/// Keeps media picked in the admin editor: copies the picked file into
/// `<documents>/admin_media/<songId>_<name>` (picker caches are temporary)
/// and, in cloud mode, uploads it to Storage `songs/<songId>/<name>` and
/// returns the download URL instead.
class AdminMediaStore {
  AdminMediaStore({this.uploader, Future<Directory> Function()? documentsDir})
    : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final CloudMediaUploader? uploader;
  final Future<Directory> Function() _documentsDir;

  /// Returns the reference to store in the song for [ref]. Assets, URLs and
  /// files already persisted for this song are returned unchanged.
  Future<String> persist(String ref, String songId) async {
    if (mediaKindOf(ref) != MediaKind.file) return ref;
    final name = ref.split(RegExp(r'[\\/]')).last;
    final dir = Directory('${(await _documentsDir()).path}/admin_media');
    final alreadyStored =
        name.startsWith('${songId}_') &&
        File(ref).parent.path.replaceAll('\\', '/').endsWith('/admin_media');
    var local = ref;
    if (!alreadyStored) {
      await dir.create(recursive: true);
      local = (await File(ref).copy('${dir.path}/${songId}_$name')).path;
    }
    final up = uploader;
    if (up == null) return local;
    final remoteName = name.startsWith('${songId}_') ? name.substring(songId.length + 1) : name;
    return up.upload(local, 'songs/$songId/$remoteName');
  }
}
