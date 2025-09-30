
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:riverpod/riverpod.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// // Provider for the Authentication Service
// final authServiceProvider = Provider<AuthService>((ref) {
//   return AuthService(FirebaseAuth.instance);
// });

// class AuthService {
//   final FirebaseAuth _firebaseAuth;

//   AuthService(this._firebaseAuth);

//   // Stream to listen to authentication state changes
//   Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

//   // Sign in with email and password
//   Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
//     try {
//       return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
//     } on FirebaseAuthException catch (e) {
//       // Handle specific Firebase Auth exceptions
//       throw e;
//     } catch (e) {
//       // Handle other exceptions
//       rethrow;
//     }
//   }

//   // Register with email and password
//   Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
//     try {
//       return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
//     } on FirebaseAuthException catch (e) {
//       // Handle specific Firebase Auth exceptions
//       throw e;
//     } catch (e) {
//       // Handle other exceptions
//       rethrow;
//     }
//   }

//   // Sign in with Google
//   Future<UserCredential?> signInWithGoogle() async {
//     try {
//       // Trigger the Google Sign In flow
//       final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

//       // Obtain the auth details from the request
//       final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

//       // Create a new credential
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth?.accessToken,
//         idToken: googleAuth?.idToken,
//       );

//       // Sign in to Firebase with the credential
//       return await _firebaseAuth.signInWithCredential(credential);
//     } on FirebaseAuthException catch (e) {
//       // Handle specific Firebase Auth exceptions
//       throw e;
//     } catch (e) {
//       // Handle other exceptions
//       rethrow;
//     }
//   }

//   // Sign out
//   Future<void> signOut() async {
//     await _firebaseAuth.signOut();
//     await GoogleSignIn().signOut(); // Sign out from Google as well
//   }

//   // Get the current user
//   User? getCurrentUser() {
//     return _firebaseAuth.currentUser;
//   }

//    Future<void> sendPasswordResetEmail(String email) async {
//     await FirebaseAuth.sendPasswordResetEmail(email: email);
//   }
// }



import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provider for the Authentication Service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance, GoogleSignIn());
});

class AuthService {
  AuthService(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    // Launch Google sign-in
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    // Get auth tokens
    final googleAuth = await googleUser.authentication;

    // Build credential and sign in
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email); // <-- instance call
  }

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// Current user (nullable)
  User? getCurrentUser() => _auth.currentUser;
}
