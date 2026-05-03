import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/tools_service.dart';
import '../services/bookings_service.dart';
import '../services/payments_service.dart';
import '../widgets/app_alerts.dart';
import 'bookings_screen.dart';
import 'earnings_screen.dart';
import 'my_ratings_screen.dart';
import 'tool_management_screen.dart';
import 'tool_map_search_screen.dart';
import 'tool_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const Color _primary = Color(0xFFFF9800);
  static const Color _secondary = Color(0xFF1300FF);
  static const Color _cream = Color(0xFFFFF3E0);
  static const Color _bronze = Color(0xFFA88757);

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (!context.mounted || !shouldLogout) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final profile = auth.profile;
    
    // Fallback profile if Firestore is slow/blocked
    final displayProfile = profile ?? AppUser(
      id: auth.user?.uid ?? 'temp',
      email: auth.user?.email ?? '',
      role: (auth.user?.email == 'phariharasudhan2004@gmail.com') ? 'admin' : 'seeker',
      username: auth.user?.email?.split('@')[0] ?? 'User',
      trustScore: 50,
      createdAt: DateTime.now(),
    );

    final isLender = displayProfile.role == 'lender';

    return Scaffold(
      appBar: AppBar(
        title: const Text('GrabTools'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit',
            onPressed: SystemNavigator.pop,
          ),
        ],
      ),
      drawer: _buildDrawer(
        context,
        profile: displayProfile,
        isLender: isLender,
        themeMode: themeProvider.themeMode,
      ),
      body: Container(
        color: _cream.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.05 : 1),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: Colors.transparent,
                child: _GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${displayProfile.username ?? 'User'}!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        displayProfile.role.toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.cyanAccent 
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (isLender)
                        StreamBuilder<List<Booking>>(
                          stream: BookingsService().streamBookingsForLender(displayProfile.id),
                          builder: (context, snapshot) {
                            var total = 0.0;
                            if (snapshot.hasData) {
                              final now = DateTime.now();
                              final completed = snapshot.data!.where((b) {
                                final isFinished = b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'finished';
                                final isToday = b.endDate.toLocal().year == now.year && 
                                                b.endDate.toLocal().month == now.month && 
                                                b.endDate.toLocal().day == now.day;
                                return isFinished && isToday;
                              });
                              total = completed.fold(0.0, (sum, b) => sum + b.totalPrice);
                            }
                            return Text(
                              'Earnings Today: INR ${total.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                      if (isLender)
                        StreamBuilder<List<Tool>>(
                          stream: ToolsService().streamToolsByOwner(displayProfile.id),
                          builder: (context, snap) {
                            final ownerTools = snap.data ?? [];
                            if (snap.hasData && ownerTools.any((t) => t.isSuspicious)) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ToolManagementScreen()),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange, width: 1.5),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.report_problem, color: Colors.orange, size: 20),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Attention: You have tools under review. Check "Manage Tools" for details.',
                                            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, color: Colors.orange, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      const SizedBox(height: 10),
                      if (!isLender && displayProfile.role != 'admin')
                        ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await context.read<AuthProvider>().updateRole('lender');
                            messenger.showSnackBar(const SnackBar(content: Text('Role updated to LENDER')));
                          },
                          icon: const Icon(Icons.upgrade),
                          label: const Text('Become Lender'),
                        ),
                      if (isLender)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await context.read<AuthProvider>().updateRole('seeker');
                            messenger.showSnackBar(const SnackBar(content: Text('Role updated to SEEKER')));
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Switch to Seeker'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
              Text(
                isLender ? 'Lender Menu' : 'Seeker Menu',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: isLender
                    ? [
                        _MenuCard(
                          icon: Icons.build,
                          label: 'Manage Tools',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ToolManagementScreen()),
                          ),
                        ),
                        _MenuCard(
                          icon: Icons.list_alt,
                          label: 'Bookings',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BookingsScreen()),
                          ),
                        ),
                        _MenuCard(
                          icon: Icons.trending_up,
                          label: 'Earnings',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EarningsScreen()),
                          ),
                        ),
                        _MenuCard(
                          icon: Icons.star,
                          label: 'My Ratings',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyRatingsScreen()),
                          ),
                        ),
                      ]
                    : [
                        _MenuCard(
                          icon: Icons.location_on,
                          label: 'Nearby Tools',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ToolMapSearchScreen()),
                          ),
                        ),
                        _MenuCard(
                          icon: Icons.search,
                          label: 'Search Tools',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ToolSearchScreen()),
                          ),
                        ),
                        if (displayProfile.role != 'admin')
                          _MenuCard(
                            icon: Icons.star,
                            label: 'My Ratings',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyRatingsScreen()),
                            ),
                          ),
                        if (displayProfile.role != 'admin')
                          _MenuCard(
                            icon: Icons.book_online,
                            label: 'My Bookings',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BookingsScreen()),
                            ),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context, {
    required AppUser profile,
    required bool isLender,
    required ThemeMode themeMode,
  }) {
    final shortcuts = <_ShortcutItem>[
      if (isLender)
        const _ShortcutItem(icon: Icons.build, label: 'Manage Tools', route: '/manage-tools'),
      if (isLender)
        const _ShortcutItem(icon: Icons.trending_up, label: 'Earnings', route: '/earnings'),
      if (isLender)
        const _ShortcutItem(icon: Icons.star, label: 'My Ratings', route: '/my-ratings'),
      if (!isLender)
        const _ShortcutItem(icon: Icons.location_on, label: 'Nearby Tools', route: '/nearby'),
      if (!isLender)
        const _ShortcutItem(icon: Icons.search, label: 'Search Tools', route: '/search'),
      if (!isLender && profile.role != 'admin')
        const _ShortcutItem(icon: Icons.star, label: 'My Ratings', route: '/my-ratings'),
      if (profile.role != 'admin')
        const _ShortcutItem(icon: Icons.list_alt, label: 'Bookings', route: '/bookings'),
      if (isLender) const _ShortcutItem(icon: Icons.storefront, label: 'Browse Tools', route: '/browse'),
      if (profile.role == 'admin')
        const _ShortcutItem(icon: Icons.admin_panel_settings, label: 'Admin Panel', route: '/admin'),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(context, profile),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      _showProfileDialog(context, profile);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      'Shortcuts',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final item in shortcuts)
                    ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, item.route);
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _confirmLogout(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _buildThemeToggle(context, themeMode: themeMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, AppUser profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _primary,
        border: Border(
          bottom: BorderSide(color: _secondary.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                ? Text(
                    (profile.username?.isNotEmpty ?? false) ? profile.username![0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            profile.username ?? 'User',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            profile.role.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context, AppUser profile) {
    showDialog(
      context: context,
      builder: (_) => _EditableProfileDialog(profile: profile),
    );
  }

  Widget _buildThemeToggle(BuildContext context, {required ThemeMode themeMode}) {
    final isSystem = themeMode == ThemeMode.system;
    final isDark = _isDarkModeActive(context, themeMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Change Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        if (isSystem)
          Text(
            'Default: Device Theme',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _cream.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.9),
            border: Border.all(color: _bronze.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: 18,
                color: isDark ? _primary : _secondary,
              ),
              const SizedBox(width: 8),
              Text(
                isDark ? 'Dark Mode' : 'Light Mode',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Switch(
                value: isDark,
                onChanged: (_) {
                  final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  context.read<ThemeProvider>().setThemeMode(nextMode);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isDarkModeActive(BuildContext context, ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final String route;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _GlassCard(
        borderColor: (isDark ? HomeScreen._primary : HomeScreen._bronze).withValues(alpha: 0.35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: isDark ? HomeScreen._primary : HomeScreen._secondary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.padding,
    this.borderColor,
  });

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: _hovered ? 12 : 6,
                    offset: Offset(0, _hovered ? 6 : 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: HomeScreen._secondary.withValues(alpha: _hovered ? 0.22 : 0.12),
                    blurRadius: _hovered ? 24 : 14,
                    spreadRadius: _hovered ? 0.6 : 0,
                    offset: Offset(0, _hovered ? 12 : 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: _hovered ? 0.18 : 0.08),
                    blurRadius: _hovered ? 18 : 10,
                    offset: const Offset(-1, -1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.66),
                border: Border.all(
                  color: widget.borderColor ?? Colors.white.withValues(alpha: isDark ? 0.18 : 0.72),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableProfileDialog extends StatefulWidget {
  final AppUser profile;

  const _EditableProfileDialog({required this.profile});

  @override
  State<_EditableProfileDialog> createState() => _EditableProfileDialogState();
}

class _EditableProfileDialogState extends State<_EditableProfileDialog> {
  static const List<String> _countryCodes = ['+91', '+1', '+44', '+61', '+971'];
  late TextEditingController usernameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController upiCtrl;
  String _selectedCountryCode = '+91';
  bool isEditing = false;
  bool isLoading = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  final PaymentsService _paymentsService = PaymentsService();
  final LocalAuthentication authPlugin = LocalAuthentication();
  String? _verificationId;

  Future<bool> _authenticateWithDeviceUnlock() async {
    try {
      final bool canAuthenticate = await authPlugin.isDeviceSupported();
      if (!canAuthenticate) return true; // If device doesn't support it, allow proceeding

      return await authPlugin.authenticate(
        localizedReason: 'Please authenticate to edit or save your profile',
        biometricOnly: false,
      );
    } catch (e) {
      if (!mounted) return false;
      showErrorAlert(context, 'Device unlock failed');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    usernameCtrl = TextEditingController(text: widget.profile.username ?? '');
    final split = _splitPhone(widget.profile.phoneNumber ?? '');
    _selectedCountryCode = split.$1;
    phoneCtrl = TextEditingController(text: split.$2);
    upiCtrl = TextEditingController(text: widget.profile.upiId ?? '');
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    phoneCtrl.dispose();
    upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Failed to pick image. Please try again.');
    }
  }

  Future<void> _saveChanges() async {
    if (usernameCtrl.text.isEmpty) {
      showErrorAlert(context, 'Username cannot be empty');
      return;
    }

    final authenticated = await _authenticateWithDeviceUnlock();
    if (!mounted) return;
    if (!authenticated) return;

    final rawPhone = phoneCtrl.text.trim();
    final newPhone = _formatPhoneNumber(_selectedCountryCode, rawPhone);
    final currentPhone = widget.profile.phoneNumber ?? '';
    final formattedNew = newPhone ?? '';
    final newUpiId = upiCtrl.text.trim();

    if (rawPhone.isNotEmpty && newPhone == null) {
      showErrorAlert(context, 'Enter a valid mobile number (at least 8 digits)');
      return;
    }
    if (newUpiId.isNotEmpty && !_paymentsService.isValidUpiId(newUpiId)) {
      showErrorAlert(context, 'Enter a valid UPI ID, for example name@bank');
      return;
    }

    // If phone number changed, verify via OTP first
    final phoneChanged = rawPhone.isNotEmpty && formattedNew != currentPhone;
    if (phoneChanged) {
      final verified = await _verifyPhoneNumber(formattedNew);
      if (!verified) return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      String? photoUrl = auth.profile?.photoUrl ?? widget.profile.photoUrl;
      final currentEmail = auth.profile?.email ?? widget.profile.email;

      if (_selectedImage != null) {
        photoUrl = await auth.uploadProfileImage(_selectedImage!);
      }

      final resolvedPhone = rawPhone.isEmpty ? widget.profile.phoneNumber : newPhone;

      await auth.updateProfile(
        username: usernameCtrl.text,
        email: currentEmail,
        phoneNumber: resolvedPhone,
        photoUrl: photoUrl,
        upiId: newUpiId.isEmpty ? '' : newUpiId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => isEditing = false);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Sends OTP to [phoneNumber] and shows verification dialog.
  /// Returns true if verified successfully.
  Future<bool> _verifyPhoneNumber(String phoneNumber) async {
    setState(() => isLoading = true);
    final completer = Completer<bool>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified on Android
        if (!completer.isCompleted) completer.complete(true);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        showErrorAlert(context, 'Failed to send OTP: ${e.message ?? e.code}');
        if (!completer.isCompleted) completer.complete(false);
      },
      codeSent: (String verificationId, int? resendToken) async {
        _verificationId = verificationId;
        if (!mounted) return;
        setState(() => isLoading = false);
        final verified = await _showOtpDialog(phoneNumber);
        if (!completer.isCompleted) completer.complete(verified);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  Future<bool> _showOtpDialog(String phoneNumber) async {
    final otpCtrl = TextEditingController();
    bool verifying = false;
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Verify Phone Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the 6-digit OTP sent to $phoneNumber'),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '------',
                  counterText: '',
                  errorText: error,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
              ),
              if (verifying) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: verifying
                  ? null
                  : () async {
                      final otp = otpCtrl.text.trim();
                      if (otp.length != 6) {
                        setDialogState(() => error = 'Enter the 6-digit OTP');
                        return;
                      }
                      if (_verificationId == null) {
                        setDialogState(() => error = 'Verification session expired. Try again.');
                        return;
                      }
                      setDialogState(() {
                        verifying = true;
                        error = null;
                      });
                      try {
                        final credential = PhoneAuthProvider.credential(
                          verificationId: _verificationId!,
                          smsCode: otp,
                        );
                        // Verify credential is valid without re-linking
                        await FirebaseAuth.instance.currentUser
                            ?.reauthenticateWithCredential(credential)
                            .catchError((_) async {
                          // If reauthenticate fails (different provider), just verify the code
                          return await FirebaseAuth.instance.signInWithCredential(credential);
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() {
                          verifying = false;
                          error = e.code == 'invalid-verification-code'
                              ? 'Invalid OTP. Please try again.'
                              : e.message ?? 'Verification failed';
                        });
                      }
                    },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    otpCtrl.dispose();
    return result ?? false;
  }

  String? _formatPhoneNumber(String countryCode, String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    return '$countryCode$digits';
  }

  (String, String) _splitPhone(String phone) {
    final trimmed = phone.trim();
    if (!trimmed.startsWith('+')) return ('+91', trimmed);
    for (final code in _countryCodes) {
      if (trimmed.startsWith(code)) {
        return (code, trimmed.substring(code.length));
      }
    }
    return ('+91', trimmed.replaceFirst(RegExp(r'^\+'), ''));
  }

  @override
  Widget build(BuildContext context) {
    final liveProfile = context.watch<AuthProvider>().profile ?? widget.profile;
    return AlertDialog(
      title: const Text('Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!) as ImageProvider
                        : (liveProfile.photoUrl != null && liveProfile.photoUrl!.isNotEmpty
                            ? NetworkImage(liveProfile.photoUrl!)
                            : null),
                    child: (_selectedImage == null &&
                            (liveProfile.photoUrl == null || liveProfile.photoUrl!.isEmpty))
                        ? Text(
                            (usernameCtrl.text.isNotEmpty) ? usernameCtrl.text[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  if (isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isEditing) ...[
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter phone number',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  prefixIconConstraints: const BoxConstraints(minWidth: 96, minHeight: 0),
                  prefixIcon: DropdownButtonHideUnderline(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 8),
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        isDense: true,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedCountryCode = v);
                          }
                        },
                        items: _countryCodes
                            .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              if (liveProfile.role == 'lender') ...[
                TextField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    hintText: 'example@okaxis',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              Text('Username: ${liveProfile.username ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Email: ${liveProfile.email}'),
              const SizedBox(height: 8),
              Text('Mobile: ${liveProfile.phoneNumber ?? 'Not provided'}'),
              const SizedBox(height: 8),
              Text('Role: ${liveProfile.role.toUpperCase()}'),
              if (liveProfile.role == 'lender') ...[
                const SizedBox(height: 8),
                Text('UPI ID: ${liveProfile.upiId?.isNotEmpty == true ? liveProfile.upiId : 'Not provided'}'),
              ],
              if (liveProfile.role == 'lender') ...[
                const SizedBox(height: 8),
                StreamBuilder<List<Booking>>(
                  stream: BookingsService().streamBookingsForLender(liveProfile.id),
                  builder: (context, snapshot) {
                    var total = 0.0;
                    if (snapshot.hasData) {
                      final completed = snapshot.data!.where((b) => 
                        b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'finished');
                      total = completed.fold(0.0, (sum, b) => sum + b.totalPrice);
                    }
                    return Text(
                      'Earnings: INR ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: isLoading ? null : () => setState(() => isEditing = false),
            child: const Text('Cancel'),
          ),
        if (isEditing)
          ElevatedButton(
            onPressed: isLoading ? null : _saveChanges,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: () async {
              final authenticated = await _authenticateWithDeviceUnlock();
              if (authenticated && mounted) {
                setState(() => isEditing = true);
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ],
    );
  }
}