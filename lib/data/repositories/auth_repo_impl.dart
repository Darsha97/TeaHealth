import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/app_user.dart';
import '../../domain/repositories/auth_repo.dart';
import '../models/app_user_model.dart';
import '../sources/firebase_auth_source.dart';
import '../sources/google_sign_in_source.dart';

class AuthRepoImpl implements AuthRepo {
  final FirebaseAuthSource firebase;
  final GoogleSignInSource google;

  AuthRepoImpl(this.firebase, this.google);

  AppUser _map(fb.User u) => AppUserModel(
    uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL,
  ).toEntity();

  @override
  Stream<AppUser?> authStateChanges() =>
      firebase.changes().map((u) => u == null ? null : _map(u));

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final u = await firebase.signInEmail(email, password);
    return _map(u);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final u = await google.signIn();
    return _map(u);
  }

  @override
  Future<void> sendPasswordReset(String email, {String? continueUrl}) =>
      firebase.sendReset(email, continueUrl: continueUrl);

  @override
  Future<void> signOut() => firebase.signOut();
}
