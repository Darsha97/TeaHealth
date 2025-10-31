 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import 'login_page.dart';

class CreateAccountPage extends ConsumerStatefulWidget {
  const CreateAccountPage({super.key});

  @override
  ConsumerState<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends ConsumerState<CreateAccountPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _registerWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).registerWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // Sign out so auth listener won’t send you to Home automatically.
      await ref.read(authServiceProvider).signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please log in.')),
      );

      // Go to Login page and clear back stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // keep message friendly; you can refine with FirebaseAuthException codes
            'Registration failed: The email may already be in use.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  double _passwordScore(String p) {
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\+=\[\]\\;/`~]').hasMatch(p)) score++;
    return (score / 6).clamp(0, 1);
  }

  String _passwordLabel(double s) {
    if (s == 0) return '';
    if (s < 0.34) return 'Weak';
    if (s < 0.67) return 'Medium';
    return 'Strong';
  }

  Color _passwordColor(double s) {
    if (s < 0.34) return Colors.red;
    if (s < 0.67) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _passwordScore(_passwordController.text);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Positioned(top: -60, right: -40, child: _DecorativeCircle(size: 180, opacity: 0.15)),
          const Positioned(bottom: -50, left: -30, child: _DecorativeCircle(size: 220, opacity: 0.12)),

          // Card
           SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final kb = MediaQuery.of(context).viewInsets.bottom; // keyboard height
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 60, 16, kb + 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                      elevation: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                                child: const Icon(Icons.person_add_alt_1, size: 32, color: Colors.green),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Create your account',
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Join TeaHealth in a minute',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                              ),
                              const SizedBox(height: 24),

                              // Name
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'User Name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                              ),
                              const SizedBox(height: 14),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                              ),
                              const SizedBox(height: 14),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                onChanged: (_) => setState(() {}), // refresh strength UI
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 6) ? 'Password must be 6+ characters' : null,
                              ),

                              // Password strength
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: strength,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor: AlwaysStoppedAnimation<Color>(_passwordColor(strength)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _passwordLabel(strength),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _passwordColor(strength),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () =>
                                        setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 6) ? 'Password must be 6+ characters' : null,
                              ),
                              const SizedBox(height: 20),

                              // Create Account
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _registerWithEmailAndPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Create Account', style: TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Already have an account
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Already have an account? '),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(builder: (_) => const LoginPage()),
                                            ),
                                    child: const Text('Log in'),
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
        if (_isLoading)
          IgnorePointer(
            child: Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    )
    );
  }
}

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
