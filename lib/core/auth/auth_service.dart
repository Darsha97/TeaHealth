
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// /// Provider for the Authentication Service
// final authServiceProvider = Provider<AuthService>((ref) {
//   return AuthService(FirebaseAuth.instance, GoogleSignIn());
// });

// class AuthService {
//   AuthService(this._auth, this._googleSignIn);

//   final FirebaseAuth _auth;
//   final GoogleSignIn _googleSignIn;

//   /// Stream to listen to authentication state changes
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   /// Sign in with email and password
//   Future<UserCredential> signInWithEmailAndPassword(
//     String email,
//     String password,
//   ) async {
//     return await _auth.signInWithEmailAndPassword(
//       email: email,
//       password: password,
//     );
//   }

//   /// Register with email and password
//   Future<UserCredential> registerWithEmailAndPassword(
//     String email,
//     String password,
//   ) async {
//     return await _auth.createUserWithEmailAndPassword(
//       email: email,
//       password: password,
//     );
//   }

//   /// Sign in with Google
//   Future<UserCredential?> signInWithGoogle() async {
//     // Launch Google sign-in
//     final googleUser = await _googleSignIn.signIn();
//     if (googleUser == null) return null; // user cancelled

//     // Get auth tokens
//     final googleAuth = await googleUser.authentication;

//     // Build credential and sign in
//     final credential = GoogleAuthProvider.credential(
//       accessToken: googleAuth.accessToken,
//       idToken: googleAuth.idToken,
//     );
//     return await _auth.signInWithCredential(credential);
//   }

//   /// Send password reset email
//   Future<void> sendPasswordResetEmail(String email) async {
//     await _auth.sendPasswordResetEmail(email: email); // <-- instance call
//   }

//   /// Sign out from Firebase and Google
//   Future<void> signOut() async {
//     await _auth.signOut();
//     await _googleSignIn.signOut();
//   }

//   /// Current user (nullable)
//   User? getCurrentUser() => _auth.currentUser;
// }



// core/auth/auth_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// TODO: Replace with your real web client id from Firebase Console >
/// Project settings > General > Your web app > OAuth 2.0 Client IDs
const _kWebClientId = '84109868679-7li55kht69m2c51pl9ecjt648qdlsj05.apps.googleusercontent.com';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    FirebaseAuth.instance,
    GoogleSignIn(
      scopes: const ['email', 'profile'],
      // Passing clientId fixes the classic "idToken is null" on Android.
      clientId: _kWebClientId,
    ),
  );
});

class AuthService {
  AuthService(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Google sign-in that always provides an idToken/accessToken pair.
  Future<UserCredential?> signInWithGoogle() async {
  final googleUser = await _googleSignIn.signIn();
  if (googleUser == null) {
    print('[GOOGLE] cancelled');
    return null;
  }

  final googleAuth = await googleUser.authentication;
  print('[GOOGLE] idToken? ${googleAuth.idToken != null} accessToken? ${googleAuth.accessToken != null}');

  if (googleAuth.idToken == null && googleAuth.accessToken == null) {
    throw FirebaseAuthException(
      code: 'missing-google-token',
      message: 'No tokens from Google. Check Web client ID + SHA + google-services.json.',
    );
  }

  final cred = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,
    accessToken: googleAuth.accessToken,
  );
  return await FirebaseAuth.instance.signInWithCredential(cred);
}

  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
  }) {
    return _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore if GoogleSignIn wasn't used on this device
    }
  }

  User? getCurrentUser() => _auth.currentUser;
}
