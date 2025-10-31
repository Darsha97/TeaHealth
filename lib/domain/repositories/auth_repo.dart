import '../app_user.dart';

abstract class AuthRepo {
  Stream<AppUser?> authStateChanges();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signInWithGoogle();
  Future<void> sendPasswordReset(String email, {String? continueUrl});
  Future<void> signOut();
}
