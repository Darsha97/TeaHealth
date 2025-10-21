import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.read(authServiceProvider).authStateChanges,
);
