import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_scaffold.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    // On success AuthGate swaps the screen; nothing to navigate here.
    await context.read<AuthProvider>().signIn(_email.text, _password.text);
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final emailError = Validators.aluEmail(_email.text);
    if (emailError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Enter your ALU email above first. $emailError'),
        ),
      );
      return;
    }
    if (await auth.sendPasswordReset(_email.text)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent. Check your inbox.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local UI state (password visibility) uses setState; shared app
    // state (busy, error) comes from AuthProvider.
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in with your ALU email to report and track '
          'campus issues.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.error != null) ErrorBanner(message: auth.error!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'ALU email',
                hintText: 'name@${AppConfig.studentDomain}',
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              validator: Validators.aluEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => Validators.required(v, field: 'Password'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: auth.busy ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            LoadingButton(
              label: 'Sign in',
              busy: auth.busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New here?'),
                TextButton(
                  onPressed: auth.busy
                      ? null
                      : () {
                          auth.clearError();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
