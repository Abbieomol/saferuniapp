import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';

/// Where the user is in the sign-in journey. AuthGate picks a screen
/// from this value, so navigation follows the auth state automatically.
enum AuthStatus { loading, signedOut, unverified, signedIn }

/// App-wide authentication state, shared through Provider.
///
/// Listens to Firebase's authStateChanges and the user's Firestore
/// profile, and exposes a single, simple state to the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserRepository? userRepository})
    : _authService = authService ?? AuthService(),
      _users = userRepository ?? UserRepository() {
    _authSub = _authService.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService _authService;
  final UserRepository _users;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _profile;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  AppUser? get user => _profile;
  bool get isStaff => _profile?.isStaff ?? false;
  bool get busy => _busy;
  String? get error => _error;
  String? get pendingEmail => _authService.currentUser?.email;

  // Reacting to Firebase

  Future<void> _onAuthChanged(User? firebaseUser) async {
    await _profileSub?.cancel();
    _profileSub = null;
    _profile = null;

    if (firebaseUser == null) {
      _setStatus(AuthStatus.signedOut);
    } else if (!firebaseUser.emailVerified) {
      _setStatus(AuthStatus.unverified);
    } else {
      await _startProfile(firebaseUser);
    }
  }

  Future<void> _startProfile(User firebaseUser) async {
    _setStatus(AuthStatus.loading);
    try {
      await _users.createProfileIfMissing(
        AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          fullName: firebaseUser.displayName ?? '',
          role: UserRole.student,
        ),
      );
    } catch (e) {
      _error = 'Could not load your profile. Check your connection.';
    }
    _profileSub = _users
        .watchUser(firebaseUser.uid)
        .listen(
          (profile) {
            _profile = profile;
            _setStatus(
              profile == null ? AuthStatus.loading : AuthStatus.signedIn,
            );
          },
          onError: (Object _) {
            // Usually a security-rules rejection: send the user back to login.
            _error = 'Could not load your profile. Please sign in again.';
            _authService.signOut();
          },
        );
  }

  // Actions called by screens

  Future<bool> register(String fullName, String email, String password) => _run(
    () => _authService.register(
      fullName: fullName,
      email: email,
      password: password,
    ),
  );

  Future<bool> signIn(String email, String password) =>
      _run(() => _authService.signIn(email: email, password: password));

  Future<bool> resendVerification() => _run(_authService.sendVerificationEmail);

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _authService.sendPasswordReset(email));

  /// Called from the "I've verified" button on the verify screen.
  Future<bool> checkVerified() async {
    var verified = false;
    final ok = await _run(() async {
      verified = await _authService.reloadAndCheckVerified();
      if (!verified) {
        throw FirebaseAuthException(
          code: 'not-verified',
          message:
              'Your email isn\'t verified yet. Open the link we sent, '
              'then try again.',
        );
      }
    });
    final current = _authService.currentUser;
    if (ok && verified && current != null) await _startProfile(current);
    return ok;
  }

  Future<void> signOut() => _authService.signOut();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Runs an action with a loading flag and friendly error handling.
  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      _error = AuthService.friendlyError(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
