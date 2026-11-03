import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, staff }

/// Profile stored at `users/{uid}` in Firestore.
class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  bool get isStaff => role == UserRole.staff;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      role: data['role'] == 'staff' ? UserRole.staff : UserRole.student,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Used only when the profile is first created. New accounts are always
  /// students; promotion to staff happens in the Firebase console.
  Map<String, dynamic> toNewProfileMap() => {
    'email': email,
    'fullName': fullName,
    'role': UserRole.student.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
