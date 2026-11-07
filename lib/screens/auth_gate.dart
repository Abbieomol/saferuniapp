import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/verify_email_screen.dart';
import 'home_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (status) {
        AuthStatus.loading => const Scaffold(
          key: ValueKey('loading'),
          body: Center(child: CircularProgressIndicator()),
        ),
        AuthStatus.signedOut => const LoginScreen(key: ValueKey('login')),
        AuthStatus.unverified => const VerifyEmailScreen(
          key: ValueKey('verify'),
        ),
        AuthStatus.signedIn => const HomeShell(key: ValueKey('home')),
      },
    );
  }
}
