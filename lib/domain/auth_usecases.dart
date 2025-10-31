import 'app_user.dart';
import 'repositories/auth_repo.dart';

class SignInEmail {
  final AuthRepo repo;
  SignInEmail(this.repo);
  Future<AppUser> execute(String email, String password) =>
      repo.signInWithEmail(email, password);
}

class SignInGoogle {
  final AuthRepo repo;
  SignInGoogle(this.repo);
  Future<AppUser> execute() => repo.signInWithGoogle();
}

class SendPasswordReset {
  final AuthRepo repo;
  SendPasswordReset(this.repo);
  Future<void> execute(String email, {String? continueUrl}) =>
      repo.sendPasswordReset(email, continueUrl: continueUrl);
}

class ObserveAuthState {
  final AuthRepo repo;
  ObserveAuthState(this.repo);
  Stream<AppUser?> execute() => repo.authStateChanges();
}

class SignOut {
  final AuthRepo repo;
  SignOut(this.repo);
  Future<void> execute() => repo.signOut();
}
