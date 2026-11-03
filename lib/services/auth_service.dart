import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_config.dart';

/// Thin wrapper around Firebase Authentication.
///
/// Screens never call FirebaseAuth directly; they go through the
/// AuthProvider, which uses this service. That keeps Firebase details
/// out of the UI.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Creates the account and sends the verification email.
  /// The name is kept on the Auth record until the email is verified;
  /// the Firestore profile is created only after verification, because
  /// the security rules reject writes from unverified accounts.
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _ensureAluEmail(email);
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(fullName.trim());
    await user.sendEmailVerification();
    return user;
  }

  Future<User> signIn({required String email, required String password}) async {
    _ensureAluEmail(email);
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user!;
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Fetches the latest emailVerified flag from Firebase.
  /// Also refreshes the ID token so security rules see the new value.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed?.emailVerified ?? false) {
      await refreshed!.getIdToken(true);
      return true;
    }
    return false;
  }

  Future<void> sendPasswordReset(String email) async {
    _ensureAluEmail(email);
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  /// Client-side guard. The same rule is enforced again in the
  /// Firestore security rules, so it can't be bypassed.
  void _ensureAluEmail(String email) {
    if (!AppConfig.isAllowedEmail(email)) {
      throw FirebaseAuthException(
        code: 'non-alu-email',
        message: 'Only ALU email addresses can use this app.',
      );
    }
  }

  /// Turns Firebase error codes into messages a student understands.
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'non-alu-email':
          return 'Only @${AppConfig.studentDomain} and '
              '@${AppConfig.staffDomain} emails can use this app.';
        case 'email-already-in-use':
          return 'An account already exists for this email. Try signing in.';
        case 'invalid-email':
          return 'That email address looks wrong.';
        case 'weak-password':
          return 'Choose a stronger password.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your network.';
        case 'user-disabled':
          return 'This account has been disabled. Contact campus admin.';
      }
      return error.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
