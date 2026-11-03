import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/auth_scaffold.dart';

/// Shown after sign-up (or sign-in) until the ALU email is verified.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;
  Timer? _timer;
  int _cooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<AuthProvider>().resendVerification();
    if (!ok || !mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Verification email sent again.')),
    );
    // Cooldown stops students spamming the button (and Firebase limits).
    setState(() => _cooldown = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      setState(() => _cooldown--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Check your inbox',
      subtitle:
          'We sent a verification link to ${auth.pendingEmail ?? 'your email'}. '
          'Open it, then come back and tap the button below. '
          'Check your spam folder if it isn\'t there.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.error != null) ErrorBanner(message: auth.error!),
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 72,
            color: Colors.grey,
          ),
          const SizedBox(height: 28),
          LoadingButton(
            label: 'I\'ve verified my email',
            busy: auth.busy,
            onPressed: () => auth.checkVerified(),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: auth.busy || _cooldown > 0 ? null : _resend,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              _cooldown > 0
                  ? 'Resend in ${_cooldown}s'
                  : 'Resend verification email',
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: auth.busy ? null : auth.signOut,
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
