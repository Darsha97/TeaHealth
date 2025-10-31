// lib/app.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'presentation/pages/splash_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home_page.dart';

class TeaScanAppp extends StatelessWidget {
  const TeaScanAppp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TeaScan',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const _SplashRouter(), // 👈 always start on a splash-aware router
    );
  }
}

/// Shows Splash for at least [_minSplash] and then routes based on auth.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter({super.key});

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  static const _minSplash = Duration(milliseconds: 2000);

  User? _firstUser;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    // Take the first auth value (restored user or null)
    final firstAuth = FirebaseAuth.instance.authStateChanges().first.then((u) {
      _firstUser = u;
    });

    // Enforce a minimum splash time
    final minDelay = Future<void>.delayed(_minSplash);

    // When both complete, mark ready
    Future.wait([firstAuth, minDelay]).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen(); // ⏳ show your splash

    // ✅ After splash + first auth value
    return _firstUser == null ? const LoginPage() : const HomePage();
  }
}
