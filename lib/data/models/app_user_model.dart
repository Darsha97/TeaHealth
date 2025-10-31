import '../../domain/app_user.dart';

class AppUserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  AppUserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  AppUser toEntity() => AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );
}
