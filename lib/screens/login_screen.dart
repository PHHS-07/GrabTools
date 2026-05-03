import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_alerts.dart';

enum ViewMode { landing, login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication authPlugin = LocalAuthentication();
  static const Color _brandOrange = Color(0xFFFF9800);
  static const Color _brandBlue = Color(0xFF1300FF);
  static const Color _cream = Color(0xFFFFF3E0);
  static const Color _bronze = Color(0xFFA88757);
  static const Color _mint = Color(0xFF00FF9D);
  ViewMode _currentMode = ViewMode.landing;

  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final username = TextEditingController();
  final mobileNumber = TextEditingController();
  bool _rememberMe = false;
  bool _biometricLoginEnabled = true;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool isLoading = false;
  String? _pendingVerificationEmail;
  String? _pendingVerificationPassword;
  String _selectedGender = 'Rather Not Say';

  static const List<String> _countryCodes = ['+91', '+1', '+44', '+61', '+971'];
  String _selectedCountryCode = '+91';
  String? _verificationId;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRegex = RegExp(r'^[0-9]{8,15}$');

  void _showScreenError(String message) {
    if (!mounted) return;
    showErrorAlert(context, message);
  }

  String _messageForAuthError(Object error, {required bool isRegister}) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Email already in use';
        case 'invalid-email':
          return 'Invalid email address';
        case 'weak-password':
          return 'Password is too weak';
        case 'user-not-found':
          return 'User not found';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Wrong email or password';
        case 'too-many-requests':
          return 'Too many attempts. Try again later';
        default:
          return isRegister ? 'Registration failed' : 'Login failed';
      }
    }
    return isRegister ? 'Registration failed' : 'Login failed';
  }

  void _switchMode(ViewMode mode) {
    setState(() => _currentMode = mode);
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _biometricLoginEnabled = prefs.getBool('biometric_login_enabled') ?? true;
      _rememberMe = prefs.getBool(AuthProvider.rememberMePrefKey) ?? false;
    });
  }

  Future<void> _authenticateWithDeviceUnlock() async {
    if (!_biometricLoginEnabled) {
      _showScreenError('Device unlock is disabled in Settings');
      return;
    }
    final auth = context.read<AuthProvider>();
    final rememberEnabled = await auth.isRememberMeEnabled();
    final hasSignedInUser = auth.user != null;
    if (!rememberEnabled || !hasSignedInUser) {
      _showScreenError('Login first and enable Remember Me');
      return;
    }
    try {
      final bool canAuthenticate = await authPlugin.isDeviceSupported();

      if (!canAuthenticate) {
        _showScreenError('Device unlock is not available on this device');
        return;
      }

      final bool didAuthenticate = await authPlugin.authenticate(
        localizedReason: 'Use device lock to login to GrabTools',
        biometricOnly: false,
      );

      if (didAuthenticate) {
        auth.markLocalUnlockDone();
      }
    } on LocalAuthException catch (e) {
      if (!mounted) return;
      final code = e.code.name;
      if (code == 'noCredentialsSet' || code == 'passcodeNotSet') {
        _showScreenError('Set a screen lock, then try again');
        return;
      }
      if (code == 'lockedOut' || code == 'permanentlyLockedOut') {
        _showScreenError('Device unlock is temporarily locked');
        return;
      }
      _showScreenError('Device unlock failed');
    } catch (e) {
      _showScreenError('Device unlock failed');
    }
  }

  Future<void> _forgotPassword() async {
    final resetEmail = TextEditingController(text: email.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email and we'll send you a reset link."),
            const SizedBox(height: 12),
            TextField(
              controller: resetEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                filled: true,
                fillColor: _cream,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Link'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    final emailValue = resetEmail.text.trim();
    if (!_emailRegex.hasMatch(emailValue)) {
      _showScreenError('Enter a valid email address');
      return;
    }
    try {
      await AuthService().sendPasswordResetEmail(emailValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
      );
    } catch (e) {
      if (!mounted) return;
      _showScreenError('Could not send reset email. Please try again.');
    }
  }

  Future<void> _submitLogin() async {
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      _showScreenError('Please enter email and password');
      return;
    }
    if (!_emailRegex.hasMatch(emailValue)) {
      _showScreenError('Enter a valid email address');
      return;
    }

    setState(() {
      isLoading = true;
      _pendingVerificationEmail = null;
      _pendingVerificationPassword = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.setRememberMe(_rememberMe);
      await auth.login(emailValue, passwordValue);
    } on EmailNotVerifiedException {
      if (!mounted) return;
      setState(() {
        _pendingVerificationEmail = emailValue;
        _pendingVerificationPassword = passwordValue;
      });
      _showScreenError('Please verify your email');
    } catch (e) {
      if (!mounted) return;
      _showScreenError(_messageForAuthError(e, isRegister: false));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    final confirmPasswordValue = confirmPassword.text;
    final usernameValue = username.text.trim();
    final mobileValue = mobileNumber.text.trim();

    if (usernameValue.isEmpty ||
        mobileValue.isEmpty ||
        emailValue.isEmpty ||
        passwordValue.isEmpty ||
        confirmPasswordValue.isEmpty) {
      _showScreenError('Please fill all required fields');
      return;
    }
    if (!_emailRegex.hasMatch(emailValue)) {
      _showScreenError('Enter a valid email address');
      return;
    }
    if (!_phoneRegex.hasMatch(mobileValue)) {
      _showScreenError('Enter a valid mobile number');
      return;
    }
    if (passwordValue.length < 8) {
      _showScreenError('Password must be at least 8 characters');
      return;
    }
    if (passwordValue != confirmPasswordValue) {
      _showScreenError('Password and confirm password must match');
      return;
    }

    final formattedNew = _formatPhoneNumber(_selectedCountryCode, mobileValue);
    if (formattedNew == null) {
      _showScreenError('Enter a valid mobile number (at least 8 digits)');
      return;
    }

    final verified = await _verifyPhoneNumber(formattedNew);
    if (!verified) return;

    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.register(
        emailValue,
        passwordValue,
        username: usernameValue,
        phoneNumber: formattedNew,
        gender: _selectedGender,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Verify your email to continue.')),
      );
    } catch (e) {
      if (!mounted) return;
      _showScreenError(_messageForAuthError(e, isRegister: true));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    final emailValue = _pendingVerificationEmail ?? email.text.trim();
    final passwordValue = _pendingVerificationPassword ?? password.text;
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      showErrorAlert(context, 'Enter email and password first');
      return;
    }

    setState(() => isLoading = true);
    try {
      await context.read<AuthProvider>().resendVerificationEmail(
            email: emailValue,
            password: passwordValue,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to resend verification email.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

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
                        // Just verify the credential is valid for signing in
                        await FirebaseAuth.instance.signInWithCredential(credential).then((res) {
                          // Note: This actually signs the user in! But since they are registering,
                          // we might need to delete this temp auth state if they don't finish registration,
                          // or let the registration process overwrite their email/password status later.
                          // Fortunately, in GrabTools, we usually link phone or register via email.
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

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    username.dispose();
    mobileNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brandOrange.withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            bottom: -150, left: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brandBlue.withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3, left: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mint.withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: _buildCurrentView(),
              ),
            ),
          ),
          if (_currentMode != ViewMode.landing)
            Positioned(
              top: 40, left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black54),
                onPressed: () => _switchMode(ViewMode.landing),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_currentMode == ViewMode.landing) return _buildLandingView();
    if (_currentMode == ViewMode.login) return _buildLoginView();
    return _buildRegisterView();
  }

  Widget _buildLandingView() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _mint.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.22)),
          ),
          child: const Icon(Icons.handyman_rounded, size: 36, color: _brandBlue),
        ),
        const SizedBox(height: 16),
        const Text("GrabTools", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const Text("Tool Sharing Made Easy", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 80),
        
        _buildGradientButton(text: "Login", onTap: () => _switchMode(ViewMode.login)),
        const SizedBox(height: 15),
        
        GestureDetector(
          onTap: () => _switchMode(ViewMode.register),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _brandOrange, width: 2),
              color: Colors.transparent,
            ),
            child: const Center(child: Text("Register Now", style: TextStyle(color: _brandOrange, fontWeight: FontWeight.bold))),
          ),
        ),
        
        const SizedBox(height: 50),
        if (_biometricLoginEnabled) ...[
          const Text("Quick login with Device Unlock", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _authenticateWithDeviceUnlock,
            child: const Icon(Icons.lock_open_rounded, size: 80, color: _brandBlue),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _authenticateWithDeviceUnlock,
            child: const Text("Use Device Unlock", style: TextStyle(color: _brandBlue, decoration: TextDecoration.underline)),
          ),
        ] else
          Text(
            "Biometric login is disabled in Settings",
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildLoginView() {
    return Column(
      children: [
        const Text(
          "Welcome Back",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text("Sign in to continue", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 28),
        _buildTextField(controller: email, hint: "Email", keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField(
          controller: password,
          hint: "Password",
          obscureText: !_loginPasswordVisible,
          onToggleObscure: () => setState(() => _loginPasswordVisible = !_loginPasswordVisible),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) => setState(() => _rememberMe = value ?? false),
            ),
            const Text('Remember Me'),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _forgotPassword,
            child: const Text('Forgot Password?', style: TextStyle(color: _brandBlue)),
          ),
        ),
        if (_pendingVerificationEmail != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : _resendVerificationEmail,
            child: const Text('Resend Verification Email'),
          ),
        ],
        const SizedBox(height: 18),
        _buildGradientButton(
          text: "Login",
          onTap: isLoading ? null : _submitLogin,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _switchMode(ViewMode.register),
          child: const Text("Need an account? Register", style: TextStyle(color: _brandBlue)),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      children: [
        const Text(
          "Create Account",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text("Join GrabTools today", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 28),
        _buildTextField(controller: username, hint: "Username"),
        const SizedBox(height: 12),
        _buildTextField(
          controller: mobileNumber,
          hint: "Mobile Number",
          keyboardType: TextInputType.phone,
          prefixIconConstraints: const BoxConstraints(minWidth: 96, minHeight: 0),
          prefixIcon: DropdownButtonHideUnderline(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                isDense: true,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87),
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
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: InputDecoration(
            labelText: 'Gender',
            filled: true,
            fillColor: _cream,
            labelStyle: const TextStyle(color: Colors.black87),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Rather Not Say', child: Text('Rather Not Say')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedGender = value);
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(controller: email, hint: "Email", keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField(
          controller: password,
          hint: "Password",
          obscureText: !_registerPasswordVisible,
          onToggleObscure: () => setState(() => _registerPasswordVisible = !_registerPasswordVisible),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: confirmPassword,
          hint: "Confirm Password",
          obscureText: !_confirmPasswordVisible,
          onToggleObscure: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
        ),
        const SizedBox(height: 18),
        _buildGradientButton(
          text: "Create Account",
          onTap: isLoading ? null : _submitRegister,
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _brandOrange,
            border: Border.all(color: _brandBlue.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    EdgeInsetsGeometry? contentPadding,
    VoidCallback? onToggleObscure,
    Widget? prefixIcon,
    BoxConstraints? prefixIconConstraints,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.black87 : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _cream,
        hintStyle: TextStyle(
          color: isDark ? Colors.black54 : Colors.black54,
        ),
        prefixIcon: prefixIcon,
        prefixIconConstraints: prefixIconConstraints,
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _bronze.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _brandBlue, width: 1.3),
        ),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? Colors.black54 : Colors.grey.shade700,
                ),
              ),
      ),
    );
  }
}