import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/payments_service.dart';
import '../widgets/app_alerts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SectionHeader(title: 'Security'),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometric Login'),
            subtitle: const Text('Enable or disable fingerprint / Face ID login'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BiometricSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            subtitle: const Text('Update your account password'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Preferences'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Manage alerts, reminders, and messages'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Payments'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Payment Credentials'),
            subtitle: const Text('Change payment mode or add payment mode'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentCredentialsScreen()),
              );
            },
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Help & Support'),
            subtitle: const Text('User guides, FAQs, and support contact'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Theme can be changed using the switch at the bottom of the menu.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class PaymentCredentialsScreen extends StatelessWidget {
  const PaymentCredentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final paymentMode = profile?.paymentMode ?? 'Not set';
    final upiId = profile?.upiId;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Credentials')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Current Payment Mode'),
            subtitle: Text(paymentMode),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Current Credential'),
            subtitle: Text(upiId?.isNotEmpty == true ? upiId! : 'No payment credential added'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditPaymentModeScreen(
                    mode: PaymentEditorMode.change,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Change Payment Mode'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditPaymentModeScreen(
                    mode: PaymentEditorMode.add,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Add Payment Mode'),
          ),
        ],
      ),
    );
  }
}

enum PaymentEditorMode { change, add }

class EditPaymentModeScreen extends StatefulWidget {
  final PaymentEditorMode mode;

  const EditPaymentModeScreen({
    super.key,
    required this.mode,
  });

  @override
  State<EditPaymentModeScreen> createState() => _EditPaymentModeScreenState();
}

class _EditPaymentModeScreenState extends State<EditPaymentModeScreen> {
  static const List<String> _paymentModes = [
    'UPI',
    'Google Pay',
    'PhonePe',
    'Paytm',
    'Cash',
  ];

  final PaymentsService _paymentsService = PaymentsService();
  late TextEditingController _credentialCtrl;
  String _selectedMode = 'UPI';
  bool _saving = false;

  bool get _requiresUpiId => _selectedMode != 'Cash';

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _selectedMode = profile?.paymentMode != null &&
            _paymentModes.contains(profile!.paymentMode)
        ? profile.paymentMode!
        : 'UPI';
    _credentialCtrl = TextEditingController(text: profile?.upiId ?? '');
  }

  @override
  void dispose() {
    _credentialCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final credential = _credentialCtrl.text.trim();

    if (_requiresUpiId && !_paymentsService.isValidUpiId(credential)) {
      showErrorAlert(context, 'Enter a valid UPI ID, for example name@bank');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await auth.updateProfile(
        paymentMode: _selectedMode,
        upiId: _requiresUpiId ? credential : '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.mode == PaymentEditorMode.change
                ? 'Payment mode updated'
                : 'Payment mode added',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to save payment mode. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == PaymentEditorMode.change
        ? 'Change Payment Mode'
        : 'Add Payment Mode';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedMode,
            decoration: const InputDecoration(labelText: 'Payment Mode'),
            items: _paymentModes
                .map((mode) => DropdownMenuItem<String>(
                      value: mode,
                      child: Text(mode),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedMode = value;
                if (!_requiresUpiId) {
                  _credentialCtrl.clear();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _credentialCtrl,
            enabled: _requiresUpiId,
            decoration: InputDecoration(
              labelText: _requiresUpiId ? 'UPI ID' : 'No credential required',
              hintText: _requiresUpiId ? 'example@okaxis' : 'Cash does not need a stored credential',
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(title),
          ),
        ],
      ),
    );
  }
}

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  static const _prefKey = 'biometric_login_enabled';
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool(_prefKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric Login')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(_enabled ? Icons.fingerprint : Icons.fingerprint_outlined),
              title: const Text('Enable Biometric Login'),
              subtitle: const Text('Use fingerprint or Face ID in login screen'),
              trailing: Switch(
                value: _enabled,
                onChanged: _setValue,
              ),
            ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldCtrl.text;
    final newPassword = _newCtrl.text;
    final confirmPassword = _confirmCtrl.text;
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      showErrorAlert(context, 'All fields are required');
      return;
    }
    if (newPassword != confirmPassword) {
      showErrorAlert(context, 'New password and confirm password must match');
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      showErrorAlert(context, 'You must be logged in to change password');
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await auth.changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to change password. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _oldCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm New Password'),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update Password'),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _pushKey = 'notif_push_enabled';
  static const _reminderKey = 'notif_tool_reminders_enabled';
  static const _messageKey = 'notif_messages_enabled';
  static const _bookingUpdatesKey = 'notif_booking_updates_enabled';
  static const _paymentAlertsKey = 'notif_payment_alerts_enabled';
  static const _overdueAlertsKey = 'notif_overdue_alerts_enabled';
  static const _extensionRequestsKey = 'notif_extension_requests_enabled';
  bool _push = true;
  bool _reminders = true;
  bool _messages = true;
  bool _bookingUpdates = true;
  bool _paymentAlerts = true;
  bool _overdueAlerts = true;
  bool _extensionRequests = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isLender = (context.read<AuthProvider>().profile?.role ?? '') == 'lender';
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _push = prefs.getBool(_pushKey) ?? true;
      _reminders = prefs.getBool(_reminderKey) ?? true;
      _messages = prefs.getBool(_messageKey) ?? true;
      _bookingUpdates = prefs.getBool(_bookingUpdatesKey) ?? true;
      _paymentAlerts = prefs.getBool(_paymentAlertsKey) ?? true;
      _overdueAlerts = prefs.getBool(_overdueAlertsKey) ?? true;
      _extensionRequests = isLender ? true : (prefs.getBool(_extensionRequestsKey) ?? true);
      _loading = false;
    });
    if (isLender) {
      await _save(_extensionRequestsKey, true);
    }
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isLender = (context.watch<AuthProvider>().profile?.role ?? '') == 'lender';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Push Alerts'),
                  subtitle: const Text('General app alerts and updates'),
                  value: _push,
                  onChanged: (v) async {
                    setState(() => _push = v);
                    await _save(_pushKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Booking Updates'),
                  subtitle: const Text('Approval, cancellation, completion, and return updates'),
                  value: _bookingUpdates,
                  onChanged: (v) async {
                    setState(() => _bookingUpdates = v);
                    await _save(_bookingUpdatesKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Tool Reminders'),
                  subtitle: const Text('Booking, return, and due reminders'),
                  value: _reminders,
                  onChanged: (v) async {
                    setState(() => _reminders = v);
                    await _save(_reminderKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Messages'),
                  subtitle: const Text('Chat and owner contact notifications'),
                  value: _messages,
                  onChanged: (v) async {
                    setState(() => _messages = v);
                    await _save(_messageKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Payment Alerts'),
                  subtitle: const Text('Payment requests, confirmations, and pending receipts'),
                  value: _paymentAlerts,
                  onChanged: (v) async {
                    setState(() => _paymentAlerts = v);
                    await _save(_paymentAlertsKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Overdue Alerts'),
                  subtitle: const Text('Delayed return alerts and overdue charge reminders'),
                  value: _overdueAlerts,
                  onChanged: (v) async {
                    setState(() => _overdueAlerts = v);
                    await _save(_overdueAlertsKey, v);
                  },
                ),
                Opacity(
                  opacity: isLender ? 0.55 : 1,
                  child: SwitchListTile(
                    title: const Text('Borrowed Tool Duration Extension'),
                    subtitle: Text(
                      isLender
                          ? 'Always enabled for lenders so extension requests are never missed'
                          : 'Notifications for duration extension activity',
                    ),
                    value: _extensionRequests,
                    onChanged: isLender
                        ? null
                        : (v) async {
                            setState(() => _extensionRequests = v);
                            await _save(_extensionRequestsKey, v);
                          },
                  ),
                ),
              ],
            ),
    );
  }
}

// Removed LanguageSettingsScreen as per user request

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final isLender = profile?.role == 'lender';

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (isLender) ...[
            const _SectionHeader(title: 'Lender FAQs'),
            const _FaqTile(
              question: 'How do I list my tool?',
              answer: 'Open Manage Tools > Add Tool, fill in details, set location/image, and submit.',
            ),
            const _FaqTile(
              question: 'How do I track my earnings?',
              answer: 'Your day-to-day earnings are visible directly on your Home screen under the Earnings Today card.',
            ),
            const _FaqTile(
              question: 'How do I receive payments?',
              answer: 'Add your UPI ID or preferred method in Settings > Payment Credentials. Renters will pay you directly.',
            ),
            const _FaqTile(
              question: 'Can I decline a booking request?',
              answer: 'Yes, any incoming tool requests will appear in your Bookings screen where you can approve or reject them.',
            ),
          ] else ...[
            const _SectionHeader(title: 'Seeker FAQs'),
            const _FaqTile(
              question: 'How do I book a tool?',
              answer: 'Find a tool you need, open its details, agree to the Terms, and press Book Now.',
            ),
            const _FaqTile(
              question: 'How do I return a tool?',
              answer: 'Go to My Bookings, find your Active booking, and tap Request Return to trigger the verification flow.',
            ),
            const _FaqTile(
              question: 'Can I extend my rental duration?',
              answer: 'Yes, inside My Bookings, click on an active booking and tap the Request Extension button.',
            ),
            const _FaqTile(
              question: 'How do I contact a tool owner?',
              answer: 'You can tap the Contact Owner button inside a tool\'s details screen or from the bookings list to call or text the owner.',
            ),
          ],
          
          const Divider(height: 24),
          const _FaqTile(
            question: 'How do I change the app theme?',
            answer: 'Use the Change Theme switch located at the very bottom of the main side navigation drawer.',
          ),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('Email Support'),
            subtitle: Text('support@grabtools.app'),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text(answer),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
