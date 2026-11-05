import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads and deletes incident photos in Firebase Storage.
///
/// Photos live at `incident_photos/{uid}/{fileName}` so the storage
/// rules can check that a user only writes into their own folder.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance {
    // Default is 10 minutes of retrying, which feels like a frozen app.
    // Fail after 20 s instead so the student gets a clear message.
    _storage.setMaxUploadRetryTime(const Duration(seconds: 20));
  }

  final FirebaseStorage _storage;

  /// Returns the storage path and the public download URL.
  Future<({String path, String url})> uploadIncidentPhoto({
    required String uid,
    required File file,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'incident_photos/$uid/$name';
    final ref = _storage.ref(path);
    await ref.putFile(
      file,
      SettableMetadata(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
    );
    return (path: path, url: await ref.getDownloadURL());
  }

  Future<void> deletePhoto(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      // Already gone is fine; anything else should surface.
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
