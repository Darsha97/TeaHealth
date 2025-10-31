import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseAuthSource {
  final fb.FirebaseAuth auth;
  FirebaseAuthSource(this.auth);

  Stream<fb.User?> changes() => auth.authStateChanges();

  Future<fb.User> signInEmail(String email, String password) async {
    final cred = await auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user!;
  }

  Future<void> sendReset(String email, {String? continueUrl}) async {
    final acs = continueUrl == null
        ? null
        : fb.ActionCodeSettings(
            url: continueUrl,
            androidInstallApp: false,
            androidPackageName: 'com.example.teascan_app',
            handleCodeInApp: true,
          );
    await auth.sendPasswordResetEmail(email: email, actionCodeSettings: acs);
  }

  Future<void> signOut() => auth.signOut();
}
