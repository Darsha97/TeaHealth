 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/auth/auth_service.dart';
import 'home_page.dart';
import 'package:teascan_app/presentation/pages/create_account_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _isLoading = false;
  String _errorText = '';

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _errorText = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);
  try {
    final cred = await ref.read(authServiceProvider).signInWithGoogle();
    if (!mounted) return;
    if (cred?.user != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } else {
      setState(() => _errorText = 'Google sign-in was cancelled.');
    }
  } on FirebaseAuthException catch (e) {
    setState(() => _errorText = _friendlyAuthError(e));
  } catch (e) {
    setState(() => _errorText = 'Google Sign-in failed: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}



  Future<void> _forgotPassword() async {
  final email = _emailController.text.trim();
  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter your email to reset password')),
    );
    return;
  }
  setState(() => _isLoading = true);
  try {
    // Optional deep-link back to app (you can omit actionCodeSettings)
    final acs = ActionCodeSettings(
      url: 'https://teahealth-6d55b.web.app/reset',
      androidPackageName: 'com.example.teascan_app',
      androidInstallApp: false,
      handleCodeInApp: true,
    );
    await ref
        .read(authServiceProvider)
        .sendPasswordResetEmail(email, actionCodeSettings: acs);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent')),
    );
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyAuthError(e))),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found': return 'No user found for that email.';
    case 'invalid-email': return 'Please enter a valid email address.';
    case 'wrong-password': return 'Wrong password.';
    case 'invalid-credential': return 'Invalid email or password.';
    case 'network-request-failed': return 'Network error. Try again.';
    case 'too-many-requests': return 'Too many attempts. Try later.';
    case 'missing-google-token': return 'Google token missing. Check setup.';
    case 'missing-continue-uri':
    case 'invalid-continue-uri':
    case 'missing-android-pkg-name':
      return 'Reset link setup error. Try again.';
    default: return 'Auth error: ${e.code}';
  }
}



  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // Gradient background + soft decorations
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _DecorativeCircle(size: 180, opacity: 0.15),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: _DecorativeCircle(size: 220, opacity: 0.12),
          ),

          // Content
          SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final kb = MediaQuery.of(context).viewInsets.bottom; // keyboard height
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 60, 16, kb + 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App avatar + title
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                            child: const Icon(Icons.eco, size: 32, color: Colors.green),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Welcome back 👋',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Log in to continue',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 24),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your email'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // Error text (animated)
                          AnimatedOpacity(
                            opacity: _errorText.isEmpty ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _errorText,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          if (_errorText.isNotEmpty) const SizedBox(height: 8),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Log in', style: TextStyle(fontSize: 16)),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // OR divider
                          const _OrDivider(),

                          const SizedBox(height: 16),

                          // Google button (outlined)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                              label: const Text('Sign in with Google'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                foregroundColor: Colors.black87,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: _isLoading ? null : _forgotPassword,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Sign up
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CreateAccountPage(),
                                          ),
                                        ),
                                child: const Text('Sign up'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
    // Loading overlay
    if (_isLoading)
      IgnorePointer(
        child: Container(
          color: Colors.black26,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      ),
  ],
),
);
  }
}

// Decorative soft circle
class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white70],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

// OR divider
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Divider(thickness: 1)),
      ],
    );
  }
}



 