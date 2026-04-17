import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_alerts.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    try {
      final verified = await context.read<AuthProvider>().refreshEmailVerification();
      if (!mounted) return;
      if (!verified) {
        showErrorAlert(context, 'Please verify your email');
      }
    } catch (_) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to refresh verification status.');
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _resending = true);
    try {
      await context.read<AuthProvider>().resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to resend verification email.');
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? auth.profile?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to $email. Verify your email before continuing.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checking ? null : _checkVerification,
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I Verified My Email'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _resending ? null : _resendVerification,
                  child: Text(_resending ? 'Sending...' : 'Resend Verification Email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
