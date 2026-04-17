import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static const String _bucket = 'gs://grabtools-07.firebasestorage.app';
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: _bucket);

  /// Uploads a file at [path] to storage at [destPath] and returns a map
  /// with `url` (download URL) and `path` (storage path used).
  Future<Map<String, String>> uploadFile(String path, String destPath) async {
    final ref = _storage.ref().child(destPath);
    final file = File(path);
    try {
      final upload = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await upload.ref.getDownloadURL();
      return {'url': url, 'path': destPath};
    } on FirebaseException catch (e) {
      throw Exception(e.code == 'canceled'
          ? 'Upload was cancelled. Please try again.'
          : 'Image upload failed. Please try again.');
    }
  }

  Future<void> deleteFile(String storagePath) async {
    await _storage.ref().child(storagePath).delete();
  }
}
