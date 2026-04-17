import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_alerts.dart';

class LocalUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LocalUnlockScreen({required this.onUnlocked, super.key});

  @override
  State<LocalUnlockScreen> createState() => _LocalUnlockScreenState();
}

class _LocalUnlockScreenState extends State<LocalUnlockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _loading = false;

  Future<void> _unlock() async {
    setState(() {
      _loading = true;
    });
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      if (!canCheckBiometrics && !isDeviceSupported) {
        showErrorAlert(context, 'Device authentication is not available.');
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock GrabTools',
        biometricOnly: false,
      );
      if (!mounted) return;
      if (authenticated) {
        widget.onUnlocked();
      } else {
        showErrorAlert(context, 'Authentication cancelled.');
      }
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      final code = e.code.name;
      if (code == 'noCredentialsSet' || code == 'passcodeNotSet') {
        showErrorAlert(context, 'Set device lock to continue.');
      } else {
        showErrorAlert(context, 'Authentication failed.');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Authentication failed.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 64),
                const SizedBox(height: 14),
                const Text(
                  'Unlock GrabTools',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use biometrics or your device lock to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loading ? null : () => context.read<AuthProvider>().logout(),
                  child: const Text('Use different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
