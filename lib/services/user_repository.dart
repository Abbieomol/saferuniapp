import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Reads and writes user profiles in the `users` collection.
class UserRepository {
  UserRepository({FirebaseFirestore? db})
    : _users = (db ?? FirebaseFirestore.instance).collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  /// Live profile; updates instantly if staff role is granted in the console.
  Stream<AppUser?> watchUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  /// Creates the profile once, after the user verifies their email.
  /// Security rules only allow role == 'student' on creation.
  Future<void> createProfileIfMissing(AppUser user) async {
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(user.toNewProfileMap());
    }
  }
}
