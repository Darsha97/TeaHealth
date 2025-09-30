// import 'package:flutter/material.dart';
// import 'package:teascan_app/presentation/pages/create_account_page.dart';
// import 'auth_service.dart';
// import 'home_page.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _obscure = true;
//   final _formKey = GlobalKey<FormState>();
//   String _errorText = '';
//   bool _isLoading = false;

//   // void _login() {
//   //   final email = _emailController.text.trim();
//   //   final password = _passwordController.text;

//   //   if (email == 'madu@gmail.com' && password == '123456') {
//   //     Navigator.pushReplacement(
//   //       context,
//   //       MaterialPageRoute(builder: (_) => const HomePage()),
//   //     );
//   //   } else {
//   //     setState(() {
//   //       _errorText = 'Invalid email or password';
//   //     });
//   //   }
//   // }

//   Future<void> _signInWithEmailAndPassword() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       await ref.read(authServiceProvider).signInWithEmailAndPassword(
//             _emailController.text,
//             _passwordController.text,
//           );
//       // Navigation will be handled by the auth state listener
//     } catch (e) {
//       // TODO: Show error message to the user
//       print('Sign-in failed: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       await ref.read(authServiceProvider).signInWithGoogle();
//       // Navigation will be handled by the auth state listener
//     } catch (e) {
//       // TODO: Show error message to the user
//       print('Google Sign-in failed: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//    @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text(
//                   'TeaHealth Login',
//                   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
//                 ),
//                 const SizedBox(height: 32),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(
//                     labelText: 'Email',
//                     prefixIcon: Icon(Icons.email),
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: _obscure,
//                   decoration: InputDecoration(
//                     labelText: 'Password',
//                     prefixIcon: const Icon(Icons.lock),
//                     border: const OutlineInputBorder(),
//                     suffixIcon: IconButton(
//                       icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
//                       onPressed: () => setState(() => _obscure = !_obscure),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 if (_errorText.isNotEmpty)
//                   Text(
//                     _errorText,
//                     style: const TextStyle(color: Colors.red),
//                   ),
//                   const SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: _signInWithGoogle,
//                       child: const Text('Sign In with Google'),
//                     ),
//                 const SizedBox(height: 24),
//                 TextButton(
//   onPressed: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const CreateAccountPage()),
//     );
//   },
//   child: const Text("Don't have an account? Create one"),
// ),
// const SizedBox(height: 24),
//                 ElevatedButton(
//                   onPressed: _signInWithEmailAndPassword,
//                   child: const Text('Login'),
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: const Size(double.infinity, 50),
//                     backgroundColor: Colors.green,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'auth_service.dart';
// import 'home_page.dart';
// import 'package:teascan_app/presentation/pages/create_account_page.dart';

// class LoginPage extends ConsumerStatefulWidget {
//   const LoginPage({super.key});

//   @override
//   ConsumerState<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends ConsumerState<LoginPage> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   bool _obscure = true;
//   bool _isLoading = false;
//   String _errorText = '';

//   Future<void> _signInWithEmailAndPassword() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);
//     try {
//       await ref.read(authServiceProvider).signInWithEmailAndPassword(
//             _emailController.text.trim(),
//             _passwordController.text,
//           );
//        if (!mounted) return;
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => const HomePage()),
//       (_) => false, // clear back stack
//     );
//     } catch (e) {
//       _errorText = 'Invalid email or password';
//       if (mounted) setState(() {});
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(authServiceProvider).signInWithGoogle();
//        if (!mounted) return;
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => const HomePage()),
//       (_) => false, // clear back stack
//     );
//     } catch (e) {
//       _errorText = 'Google Sign-in failed. ${e.toString()}';
//       if (mounted) setState(() {});
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text(
//                   'TeaHealth Login',
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(height: 32),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(
//                     labelText: 'Email',
//                     prefixIcon: Icon(Icons.email),
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: _obscure,
//                   decoration: InputDecoration(
//                     labelText: 'Password',
//                     prefixIcon: const Icon(Icons.lock),
//                     border: const OutlineInputBorder(),
//                     suffixIcon: IconButton(
//                       icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
//                       onPressed: () => setState(() => _obscure = !_obscure),
//                     ),
//                   ),
//                   validator: (v) =>
//                       (v == null || v.isEmpty) ? 'Enter your password' : null,
//                 ),
//                 const SizedBox(height: 12),
//                 if (_errorText.isNotEmpty)
//                   Text(_errorText, style: const TextStyle(color: Colors.red)),
//                 const SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _signInWithGoogle,
//                   child: _isLoading
//                       ? const SizedBox(
//                           height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
//                       : const Text('Sign In with Google'),
//                 ),
//                 const SizedBox(height: 24),
//                 TextButton(
//                   onPressed: _isLoading
//                       ? null
//                       : () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(builder: (_) => const CreateAccountPage()),
//                           );
//                         },
//                   child: const Text("Don't have an account? Create one"),
//                 ),
//                 const SizedBox(height: 24),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _signInWithEmailAndPassword,
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: const Size(double.infinity, 50),
//                     backgroundColor: Colors.green,
//                   ),
//                   child: const Text('Login'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // for error codes (optional)

// import 'auth_service.dart';
// import 'home_page.dart';
// import 'package:teascan_app/presentation/pages/create_account_page.dart';

// class LoginPage extends ConsumerStatefulWidget {
//   const LoginPage({super.key});

//   @override
//   ConsumerState<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends ConsumerState<LoginPage> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   bool _obscure = true;
//   bool _isLoading = false;
//   String _errorText = '';

//   Future<void> _signInWithEmailAndPassword() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);
//     try {
//       await ref.read(authServiceProvider).signInWithEmailAndPassword(
//             _emailController.text.trim(),
//             _passwordController.text,
//           );

//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const HomePage()),
//         (_) => false,
//       );
//     } on FirebaseAuthException catch (e) {
//       setState(() => _errorText = _friendlyAuthError(e));
//     } catch (e) {
//       setState(() => _errorText = 'Invalid email or password');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(authServiceProvider).signInWithGoogle();

//       if (!mounted) return;
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const HomePage()),
//         (_) => false,
//       );
//     } on FirebaseAuthException catch (e) {
//       setState(() => _errorText = _friendlyAuthError(e));
//     } catch (e) {
//       setState(() => _errorText = 'Google Sign-in failed');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _forgotPassword() async {
//     final email = _emailController.text.trim();
//     if (email.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Enter your email to reset password')),
//       );
//       return;
//     }
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(authServiceProvider).sendPasswordResetEmail(email);
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Password reset email sent')),
//       );
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(_friendlyAuthError(e))),
//       );
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   String _friendlyAuthError(FirebaseAuthException e) {
//     switch (e.code) {
//       case 'user-not-found':
//         return 'No user found for that email.';
//       case 'wrong-password':
//         return 'Wrong password.';
//       case 'invalid-credential':
//         return 'Invalid email or password.';
//       case 'network-request-failed':
//         return 'Network error. Try again.';
//       case 'too-many-requests':
//         return 'Too many attempts. Try later.';
//       default:
//         return 'Auth error: ${e.code}';
//     }
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 32),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text(
//                   'TeaHealth Login',
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green,
//                   ),
//                 ),
//                 const SizedBox(height: 32),

//                 // Email
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(
//                     labelText: 'Email',
//                     prefixIcon: Icon(Icons.email),
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
//                 ),
//                 const SizedBox(height: 16),

//                 // Password
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: _obscure,
//                   decoration: InputDecoration(
//                     labelText: 'Password',
//                     prefixIcon: const Icon(Icons.lock),
//                     border: const OutlineInputBorder(),
//                     suffixIcon: IconButton(
//                       icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
//                       onPressed: () => setState(() => _obscure = !_obscure),
//                     ),
//                   ),
//                   validator: (v) =>
//                       (v == null || v.isEmpty) ? 'Enter your password' : null,
//                 ),
//                 const SizedBox(height: 12),

//                 if (_errorText.isNotEmpty)
//                   Text(_errorText, style: const TextStyle(color: Colors.red)),

//                 const SizedBox(height: 16),

//                 // Login button
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _signInWithEmailAndPassword,
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: const Size(double.infinity, 50),
//                   ),
//                   child: const Text('Log in'),
//                 ),

//                 const SizedBox(height: 16),

//                 // OR divider
//                 const _OrDivider(),

//                 const SizedBox(height: 16),

//                 // Sign in with Google
//                 OutlinedButton.icon(
//                   onPressed: _isLoading ? null : _signInWithGoogle,
//                   icon: const Icon(Icons.g_mobiledata), // keep it simple; replace with Google asset if you have one
//                   label: const Text('Sign in with Google'),
//                   style: OutlinedButton.styleFrom(
//                     minimumSize: const Size(double.infinity, 50),
//                   ),
//                 ),

//                 const SizedBox(height: 16),

//                 // Forgot password
//                 TextButton(
//                   onPressed: _isLoading ? null : _forgotPassword,
//                   child: const Text('Forgot password?'),
//                 ),

//                 const SizedBox(height: 24),

//                 // Sign up
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text("Don't have an account? "),
//                     TextButton(
//                       onPressed: _isLoading
//                           ? null
//                           : () => Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const CreateAccountPage(),
//                                 ),
//                               ),
//                       child: const Text('Sign up'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // --- Little helper widget for the OR line ---
// class _OrDivider extends StatelessWidget {
//   const _OrDivider();

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: const [
//         Expanded(child: Divider(thickness: 1)),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 12),
//           child: Text('OR', style: TextStyle(color: Colors.grey)),
//         ),
//         Expanded(child: Divider(thickness: 1)),
//       ],
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
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
      await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _errorText = 'Google Sign-in failed');
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
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
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
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try later.';
      default:
        return 'Auth error: ${e.code}';
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
