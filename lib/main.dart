import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/email_verification_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/local_unlock_screen.dart';
import 'screens/add_tool_screen.dart';
import 'screens/tool_management_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/tool_list_screen.dart';
import 'screens/tool_search_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/my_ratings_screen.dart';
import 'screens/tool_map_search_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  const enableAppCheck = bool.fromEnvironment('ENABLE_APP_CHECK');
  const usePlayIntegrity = bool.fromEnvironment('USE_PLAY_INTEGRITY');
  if (enableAppCheck) {
    await FirebaseAppCheck.instance.activate(
      // Local Android release/profile builds are currently signed with the debug key,
      // so only enable Play Integrity when explicitly requested for production builds.
      providerAndroid: usePlayIntegrity
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
    );
  }
  runApp(const GrabToolsApp());
}

class GrabToolsApp extends StatelessWidget {
  const GrabToolsApp({super.key});

  static const Color _primary = Color(0xFFFF9800);
  static const Color _secondary = Color(0xFF1300FF);
  static const Color _cream = Color(0xFFFFF3E0);
  static const Color _bronze = Color(0xFFA88757);
  static const Color _mint = Color(0xFF00FF9D);

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      error: Colors.red.shade700,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _secondary,
          side: const BorderSide(color: _secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _bronze.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _secondary, width: 1.4),
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _secondary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      error: const Color(0xFFFF6B6B),
      onError: Colors.black,
      surface: const Color(0xFF0F172A),
      onSurface: const Color(0xFFF1F5F9),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _mint,
          side: const BorderSide(color: _mint),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF0F172A),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _secondary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'GrabTools',
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            routes: {
              '/add-tool': (_) => const AddToolScreen(),
              '/manage-tools': (_) => const ToolManagementScreen(),
              '/bookings': (_) => const BookingsScreen(),
              '/browse': (_) => const ToolListScreen(),
              '/search': (_) => const ToolSearchScreen(),
              '/nearby': (_) => const ToolMapSearchScreen(),
              '/earnings': (_) => const EarningsScreen(),
              '/my-ratings': (_) => const MyRatingsScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/admin': (_) => const AdminPanelScreen(),
            },
            home: const SplashScreenWrapper(
              child: _HomeRouter(),
            ),
          );
        },
      ),
    );
  }
}

class _HomeRouter extends StatelessWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) return const LoginScreen();
        if (!auth.isEmailVerified) return const EmailVerificationScreen();
        if (auth.requiresLocalUnlock) {
          return LocalUnlockScreen(
            onUnlocked: () => context.read<AuthProvider>().markLocalUnlockDone(),
          );
        }
        // User is fully logged in and verified — request location now.
        return const LocationRequestWrapper(child: HomeScreen());
      },
    );
  }
}

class SplashScreenWrapper extends StatefulWidget {
  final Widget child;

  const SplashScreenWrapper({required this.child, super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        displayDuration: const Duration(seconds: 3),
        onLoadingComplete: () {
          setState(() => _showSplash = false);
        },
      );
    }
    return widget.child;
  }
}

class LocationRequestWrapper extends StatefulWidget {
  final Widget child;

  const LocationRequestWrapper({required this.child, super.key});

  @override
  State<LocationRequestWrapper> createState() => _LocationRequestWrapperState();
}

class _LocationRequestWrapperState extends State<LocationRequestWrapper> {
  // Static flag — survives widget rebuilds so permission is only requested once per session.
  static bool _locationRequested = false;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    if (_locationRequested) return;
    _locationRequested = true;

    final locationService = LocationService();
    final hasPermission = await locationService.requestLocationPermission();

    if (!mounted) return;

    if (hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location enabled! You can now discover nearby tools.'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access denied. You can enable it later in settings.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}