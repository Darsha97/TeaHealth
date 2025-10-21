import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central place to read/write the user's profile document in Firestore.
/// Doc path: /users/{uid}
class UserProfileService {
  UserProfileService._();
  static final instance = UserProfileService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Create the user doc on first sign-in (or keep email/photo in sync).
  Future<void> ensureUserDoc() async {
    final u = _auth.currentUser;
    if (u == null) return;

    final ref = _doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': u.displayName,
        'email': u.email,
        'photoURL': u.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'email': u.email,
        'photoURL': u.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Partial update (only provided fields are written).
  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? photoURL,
    Map<String, dynamic>? extra,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;

    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
      if (photoURL != null) 'photoURL': photoURL,
      if (extra != null) ...extra,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _doc(u.uid).set(data, SetOptions(merge: true));
  }

  /// Live stream of the Firestore profile.
  Stream<Map<String, dynamic>?> profileStream() {
    final u = _auth.currentUser;
    if (u == null) return const Stream.empty();
    return _doc(u.uid).snapshots().map((s) => s.data());
  }
}
