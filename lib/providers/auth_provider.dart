import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/users_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String rememberMePrefKey = 'remember_me_login';
  final AuthService _service = AuthService();
  final UsersService _usersService = UsersService();
  final StorageService _storageService = StorageService();
  late final AiService aiService = AiService(functionUrl: AppConfig.aiProxyFunctionUrl);
  User? _user;
  AppUser? _profile;
  bool _requiresLocalUnlock = false;
  bool _skipLocalUnlockOnce = false;

  User? get user => _user;
  AppUser? get profile => _profile;
  bool get requiresLocalUnlock => _requiresLocalUnlock;
  bool get isEmailVerified => _user?.emailVerified ?? false;

  AuthProvider() {
    _service.authChanges.listen((user) async {
      _user = user;
      if (user != null) {
        try {
          _profile = await _usersService.getUser(user.uid);
        } catch (_) {
          _profile = null;
        }

        final rememberMe = await isRememberMeEnabled();
        if (!rememberMe && !_skipLocalUnlockOnce) {
          await _service.logout();
          return;
        }

        if (_skipLocalUnlockOnce) {
          _requiresLocalUnlock = false;
          _skipLocalUnlockOnce = false;
        } else {
          _requiresLocalUnlock = true;
        }
        notifyListeners();
      } else {
        _profile = null;
        _requiresLocalUnlock = false;
        notifyListeners();
      }
    });
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMePrefKey, value);
  }

  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(rememberMePrefKey) ?? false;
  }

  void markLocalUnlockDone() {
    if (!_requiresLocalUnlock) return;
    _requiresLocalUnlock = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _skipLocalUnlockOnce = true;
    await _service.login(email, password);
    final u = _service.currentUser;
    if (u != null) {
      final deviceId = await _usersService.getDeviceId();
      final currentProfile = await _usersService.getUser(u.uid);
      if (currentProfile != null) {
        final updated = AppUser(
          id: currentProfile.id,
          email: currentProfile.email,
          role: currentProfile.role,
          createdAt: currentProfile.createdAt,
          displayName: currentProfile.displayName,
          photoUrl: currentProfile.photoUrl,
          username: currentProfile.username,
          phoneNumber: currentProfile.phoneNumber,
          gender: currentProfile.gender,
          upiId: currentProfile.upiId,
          paymentMode: currentProfile.paymentMode,
          earnings: currentProfile.earnings,
          trustScore: currentProfile.trustScore,
          deviceId: deviceId,
          lastLoginAt: DateTime.now(),
          verificationLevel: currentProfile.verificationLevel,
          idDocumentUrl: currentProfile.idDocumentUrl,
          cancellationRate: currentProfile.cancellationRate,
          totalBookings: currentProfile.totalBookings,
          totalCancellations: currentProfile.totalCancellations,
          isSuspicious: currentProfile.isSuspicious,
        );
        await _usersService.createOrUpdateUser(updated);
        _profile = updated;
      }
    }
  }

  Future<void> register(
    String email,
    String password, {
    String role = 'seeker',
    String? username,
    String? phoneNumber,
    String gender = 'Rather Not Say',
    String? upiId,
  }) async {
    _skipLocalUnlockOnce = true;
    final credential = await _service.register(email, password);
    final u = credential.user;
    if (u != null) {
      final deviceId = await _usersService.getDeviceId();
      final deviceUsersCount = await _usersService.countUsersOnDevice(deviceId);
      
      bool isSuspicious = false;
      int initialTrustScore = 50;

      if (deviceUsersCount >= 2) {
        isSuspicious = true;
        initialTrustScore = 20; // Penalty
      }

      final appUser = AppUser(
        id: u.uid,
        email: email,
        role: role,
        createdAt: DateTime.now(),
        username: username,
        phoneNumber: phoneNumber,
        gender: gender,
        upiId: upiId,
        deviceId: deviceId,
        lastLoginAt: DateTime.now(),
        trustScore: initialTrustScore,
        isSuspicious: isSuspicious,
      );
      await _usersService.createOrUpdateUser(appUser);
      _user = _service.currentUser;
      _profile = await _usersService.getUser(u.uid) ?? appUser;
      notifyListeners();
    }
  }

  Future<void> resendVerificationEmail({
    String? email,
    String? password,
  }) async {
    await _service.resendVerificationEmail(email: email, password: password);
  }

  Future<bool> refreshEmailVerification() async {
    final verified = await _service.reloadAndCheckEmailVerified();
    final u = _service.currentUser;
    if (u != null) {
      _user = u;
      _profile = await _usersService.getUser(u.uid);
    }
    notifyListeners();
    return verified;
  }

  Future<void> logout() async {
    _skipLocalUnlockOnce = false;
    await _service.logout();
  }

  Future<void> updateRole(String role) async {
    final u = _service.currentUser;
    if (u == null) return;
    final updated = AppUser(
      id: u.uid,
      email: _profile?.email ?? u.email ?? '',
      role: role,
      createdAt: _profile?.createdAt,
      displayName: _profile?.displayName,
      photoUrl: _profile?.photoUrl,
      username: _profile?.username,
      phoneNumber: _profile?.phoneNumber,
      gender: _profile?.gender ?? 'Rather Not Say',
      upiId: _profile?.upiId,
      paymentMode: _profile?.paymentMode,
      earnings: _profile?.earnings ?? 0.0,
    );
    await _usersService.createOrUpdateUser(updated);
    _profile = await _usersService.getUser(u.uid) ?? updated;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? upiId,
    String? paymentMode,
  }) async {
    final u = _service.currentUser;
    if (u == null) return;

    final nextEmail = email ?? _profile?.email ?? u.email ?? '';
    final currentEmail = _profile?.email ?? u.email ?? '';
    if (nextEmail != currentEmail) {
      await _service.updateEmail(nextEmail);
    }

    final updated = AppUser(
      id: u.uid,
      email: nextEmail,
      role: _profile?.role ?? 'seeker',
      createdAt: _profile?.createdAt,
      displayName: _profile?.displayName,
      photoUrl: photoUrl ?? _profile?.photoUrl,
      username: username ?? _profile?.username,
      phoneNumber: phoneNumber ?? _profile?.phoneNumber,
      gender: _profile?.gender ?? 'Rather Not Say',
      upiId: upiId ?? _profile?.upiId,
      paymentMode: paymentMode ?? _profile?.paymentMode,
      earnings: _profile?.earnings ?? 0.0,
    );

    await _usersService.createOrUpdateUser(updated);
    _profile = await _usersService.getUser(u.uid) ?? updated;
    notifyListeners();
  }

  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final u = _service.currentUser;
      if (u == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = 'profile_images/${u.uid}_$timestamp.jpg';

      final result = await _storageService.uploadFile(imageFile.path, destPath);
      return result['url']!;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
