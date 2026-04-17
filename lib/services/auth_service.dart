import 'package:firebase_auth/firebase_auth.dart';

class EmailNotVerifiedException implements Exception {
  final String email;

  const EmailNotVerifiedException(this.email);

  @override
  String toString() => 'Email not verified';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw Exception('Unable to sign in');
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      await _auth.signOut();
      throw EmailNotVerifiedException(email);
    }
  }

  Future<UserCredential> register(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
    return credential;
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await user.sendEmailVerification();
  }

  Future<void> resendVerificationEmail({
    String? email,
    String? password,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await currentUser.sendEmailVerification();
      return;
    }

    if (email == null || password == null) {
      throw Exception('Email and password are required');
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await credential.user?.sendEmailVerification();
    } finally {
      await _auth.signOut();
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('Password change is only available for email login');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await user.verifyBeforeUpdateEmail(newEmail);
  }
}