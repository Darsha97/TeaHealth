import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class GoogleSignInSource {
  final GoogleSignIn g;
  final fb.FirebaseAuth auth;
  GoogleSignInSource(this.g, this.auth);

  Future<fb.User> signIn() async {
    final googleUser = await g.signIn();
    if (googleUser == null) {
      throw StateError('cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final cred = await auth.signInWithCredential(credential);
    return cred.user!;
  }
}
