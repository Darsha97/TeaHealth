import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/app_user.dart';
import '../../domain/repositories/auth_repo.dart';
import '../../domain/auth_usecases.dart';

import '../../data/sources/firebase_auth_source.dart';
import '../../data/sources/google_sign_in_source.dart';
import '../../data/repositories/auth_repo_impl.dart';

 
final _firebaseAuthSourceProvider =
    Provider<FirebaseAuthSource>((ref) => FirebaseAuthSource(fb.FirebaseAuth.instance));

final _googleSignInSourceProvider = Provider<GoogleSignInSource>((ref) {
  return GoogleSignInSource(
    GoogleSignIn(scopes: const ['email', 'profile']),
    fb.FirebaseAuth.instance,
  );
});

 
final authRepoProvider = Provider<AuthRepo>((ref) {
  final fbSrc = ref.watch(_firebaseAuthSourceProvider);
  final gSrc  = ref.watch(_googleSignInSourceProvider);
  return AuthRepoImpl(fbSrc, gSrc);
});

 
final signInEmailProvider       = Provider((ref) => SignInEmail(ref.watch(authRepoProvider)));
final signInGoogleProvider      = Provider((ref) => SignInGoogle(ref.watch(authRepoProvider)));
final sendPasswordResetProvider = Provider((ref) => SendPasswordReset(ref.watch(authRepoProvider)));
final observeAuthStateProvider  = Provider((ref) => ObserveAuthState(ref.watch(authRepoProvider)));
final signOutProvider           = Provider((ref) => SignOut(ref.watch(authRepoProvider)));

 
final appUserStreamProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(observeAuthStateProvider).execute(),
);
