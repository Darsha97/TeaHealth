 

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'
//     show FirebaseAuth, User, EmailAuthProvider, FirebaseAuthException;
// import 'package:firebase_core/firebase_core.dart' show FirebaseException; // <-- for Storage errors
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';

// import 'login_page.dart';

// class ProfilePage extends StatefulWidget {
//   const ProfilePage({super.key});

//   @override
//   State<ProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<ProfilePage> {
//   User? _user;
//   bool _busy = false;

//   @override
//   void initState() {
//     super.initState();
//     _user = FirebaseAuth.instance.currentUser;
//   }

//   Future<void> _logout() async {
//     try {
//       await FirebaseAuth.instance.signOut();
//     } finally {
//       if (!mounted) return;
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginPage()),
//         (_) => false,
//       );
//     }
//   }

//   // --- Edit profile picture: pick -> upload to Storage -> update photoURL ---
//   Future<void> _editProfilePicture() async {
//     if (_user == null) return;
//     final picker = ImagePicker();
//     final x = await picker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 1200,
//       imageQuality: 90,
//     );
//     if (x == null) return;

//     setState(() => _busy = true);
//     try {
//       final file = File(x.path);
//       final ref =
//           FirebaseStorage.instance.ref().child('users/${_user!.uid}/avatar.jpg');
//       await ref.putFile(file);
//       final url = await ref.getDownloadURL();
//       await _user!.updatePhotoURL(url);
//       await _user!.reload();
//       _user = FirebaseAuth.instance.currentUser;
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
//       setState(() {});
//     } on FirebaseException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   // --- Edit name + email (email requires verification link on newer SDKs) ---
//   Future<void> _editProfile() async {
//     if (_user == null) return;

//     final nameCtrl = TextEditingController(text: _user!.displayName ?? '');
//     final emailCtrl = TextEditingController(text: _user!.email ?? '');
//     final formKey = GlobalKey<FormState>();

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Edit Profile'),
//         content: Form(
//           key: formKey,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextFormField(
//                 controller: nameCtrl,
//                 decoration: const InputDecoration(labelText: 'Name'),
//                 validator: (v) =>
//                     (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
//               ),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: emailCtrl,
//                 decoration: const InputDecoration(labelText: 'Email'),
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (v) =>
//                     (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel')),
//           ElevatedButton(
//             onPressed: () async {
//               if (!formKey.currentState!.validate()) return;
//               Navigator.pop(context); // close dialog
//               setState(() => _busy = true);
//               try {
//                 // Update display name
//                 final newName = nameCtrl.text.trim();
//                 if (newName != (_user!.displayName ?? '')) {
//                   await _user!.updateDisplayName(newName);
//                 }

//                 // Update email via verification link
//                 final newEmail = emailCtrl.text.trim();
//                 if (newEmail != (_user!.email ?? '')) {
//                   try {
//                     await _user!
//                         .verifyBeforeUpdateEmail(newEmail); // <-- FIX HERE
//                     if (mounted) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                               'Verification sent to $newEmail. Confirm from your inbox to finish updating your email.'),
//                         ),
//                       );
//                     }
//                   } on FirebaseAuthException catch (e) {
//                     if (e.code == 'requires-recent-login') {
//                       await _reauthThen(
//                         () => _user!.verifyBeforeUpdateEmail(newEmail),
//                       );
//                     } else {
//                       rethrow;
//                     }
//                   }
//                 }

//                 await _user!.reload();
//                 _user = FirebaseAuth.instance.currentUser;
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context)
//                     .showSnackBar(const SnackBar(content: Text('Profile updated')));
//                 setState(() {});
//               } catch (e) {
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context)
//                     .showSnackBar(SnackBar(content: Text('Update failed: $e')));
//               } finally {
//                 if (mounted) setState(() => _busy = false);
//               }
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- Change password (reauthenticate with current password first) ---
//   Future<void> _changePassword() async {
//     if (_user == null || (_user!.email ?? '').isEmpty) return;

//     final currentCtrl = TextEditingController();
//     final newCtrl = TextEditingController();
//     final confirmCtrl = TextEditingController();
//     final formKey = GlobalKey<FormState>();
//     bool obscure1 = true, obscure2 = true, obscure3 = true;

//     await showDialog(
//       context: context,
//       builder: (ctx) {
//         return StatefulBuilder(builder: (ctx, setStateDialog) {
//           return AlertDialog(
//             title: const Text('Change Password'),
//             content: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     controller: currentCtrl,
//                     obscureText: obscure1,
//                     decoration: InputDecoration(
//                       labelText: 'Current password',
//                       suffixIcon: IconButton(
//                         icon:
//                             Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
//                         onPressed: () =>
//                             setStateDialog(() => obscure1 = !obscure1),
//                       ),
//                     ),
//                     validator: (v) =>
//                         (v == null || v.isEmpty) ? 'Enter current password' : null,
//                   ),
//                   const SizedBox(height: 8),
//                   TextFormField(
//                     controller: newCtrl,
//                     obscureText: obscure2,
//                     decoration: InputDecoration(
//                       labelText: 'New password (6+ chars)',
//                       suffixIcon: IconButton(
//                         icon:
//                             Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
//                         onPressed: () =>
//                             setStateDialog(() => obscure2 = !obscure2),
//                       ),
//                     ),
//                     validator: (v) =>
//                         (v == null || v.length < 6) ? 'Min 6 characters' : null,
//                   ),
//                   const SizedBox(height: 8),
//                   TextFormField(
//                     controller: confirmCtrl,
//                     obscureText: obscure3,
//                     decoration: InputDecoration(
//                       labelText: 'Confirm new password',
//                       suffixIcon: IconButton(
//                         icon:
//                             Icon(obscure3 ? Icons.visibility_off : Icons.visibility),
//                         onPressed: () =>
//                             setStateDialog(() => obscure3 = !obscure3),
//                       ),
//                     ),
//                     validator: (v) =>
//                         (v != newCtrl.text) ? 'Passwords do not match' : null,
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text('Cancel')),
//               ElevatedButton(
//                 onPressed: () async {
//                   if (!formKey.currentState!.validate()) return;
//                   Navigator.pop(ctx);
//                   setState(() => _busy = true);
//                   try {
//                     final cred = EmailAuthProvider.credential(
//                       email: _user!.email!,
//                       password: currentCtrl.text,
//                     );
//                     await _user!.reauthenticateWithCredential(cred);
//                     await _user!.updatePassword(newCtrl.text);
//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Password changed')));
//                   } on FirebaseAuthException catch (e) {
//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Password change failed: ${e.code}')));
//                   } catch (e) {
//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('Password change failed: $e')));
//                   } finally {
//                     if (mounted) setState(() => _busy = false);
//                   }
//                 },
//                 child: const Text('Update'),
//               ),
//             ],
//           );
//         });
//       },
//     );
//   }

//   /// Helper to reauthenticate with a quick password prompt, then run [action].
//   Future<void> _reauthThen(Future<void> Function() action) async {
//     final pwdCtrl = TextEditingController();
//     bool obscure = true;
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (_) =>
//           StatefulBuilder(builder: (ctx, setStateDialog) {
//         return AlertDialog(
//           title: const Text('Re-authentication required'),
//           content: TextField(
//             controller: pwdCtrl,
//             obscureText: obscure,
//             decoration: InputDecoration(
//               labelText: 'Current password',
//               suffixIcon: IconButton(
//                 icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
//                 onPressed: () => setStateDialog(() => obscure = !obscure),
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text('Cancel')),
//             ElevatedButton(
//                 onPressed: () => Navigator.pop(ctx, true),
//                 child: const Text('Continue')),
//           ],
//         );
//       }),
//     );

//     if (ok != true) return;

//     setState(() => _busy = true);
//     try {
//       final email = _user!.email!;
//       final cred =
//           EmailAuthProvider.credential(email: email, password: pwdCtrl.text);
//       await _user!.reauthenticateWithCredential(cred);
//       await action();
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Updated successfully')));
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Re-auth failed: ${e.code}')));
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final photo = _user?.photoURL;

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         centerTitle: true,
//         title: const Text('Profile', style: TextStyle(color: Colors.white)),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Stack(
//         children: [
//           // Background gradient
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           const Positioned(top: -60, right: -40, child: _DecorativeCircle(size: 180, opacity: 0.18)),
//           const Positioned(bottom: -50, left: -30, child: _DecorativeCircle(size: 240, opacity: 0.14)),

//           SafeArea(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//               child: Column(
//                 children: [
//                   // Profile card
//                   Card(
//                     elevation: 10,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
//                       child: Column(
//                         children: [
//                           Stack(
//                             alignment: Alignment.bottomRight,
//                             children: [
//                               CircleAvatar(
//                                 radius: 52,
//                                 backgroundImage: photo != null && photo.isNotEmpty
//                                     ? NetworkImage(photo)
//                                     : const AssetImage('assets/images/profile.png')
//                                         as ImageProvider,
//                               ),
//                               InkWell(
//                                 onTap: _busy ? null : _editProfilePicture,
//                                 child: Container(
//                                   margin: const EdgeInsets.only(right: 2, bottom: 2),
//                                   decoration: const BoxDecoration(
//                                     color: Colors.green,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   padding: const EdgeInsets.all(6),
//                                   child: Icon(
//                                     _busy ? Icons.hourglass_top : Icons.edit,
//                                     size: 16,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           Text(
//                             _user?.displayName ?? 'TeaHealth User',
//                             style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(_user?.email ?? 'unknown@example.com',
//                               style: TextStyle(color: Colors.grey.shade600)),
//                           const SizedBox(height: 12),
//                           Wrap(
//                             alignment: WrapAlignment.center,
//                             spacing: 8,
//                             runSpacing: 8,
//                             children: const [
//                               Chip(avatar: Icon(Icons.verified_user, size: 18), label: Text('TeaHealth user')),
//                               Chip(avatar: Icon(Icons.insights, size: 18), label: Text('Disease & deficiency checks')),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   // Settings/actions
//                   Card(
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                     child: Column(
//                       children: [
//                         ListTile(
//                           leading: const Icon(Icons.edit_outlined, color: Colors.green),
//                           title: const Text('Edit Profile'),
//                           subtitle: const Text('Update your name and email'),
//                           trailing: const Icon(Icons.chevron_right),
//                           onTap: _busy ? null : _editProfile,
//                         ),
//                         const Divider(height: 1),
//                         ListTile(
//                           leading: const Icon(Icons.lock_reset, color: Colors.green),
//                           title: const Text('Change Password'),
//                           trailing: const Icon(Icons.chevron_right),
//                           onTap: _busy ? null : _changePassword,
//                         ),
//                         const Divider(height: 1),
//                         ListTile(
//                           leading: const Icon(Icons.help_outline, color: Colors.green),
//                           title: const Text('Help & Support'),
//                           trailing: const Icon(Icons.chevron_right),
//                           onTap: () {/* TODO */},
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 16),

//                   // Logout
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       icon: const Icon(Icons.logout),
//                       label: const Text('Logout'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.redAccent,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//                         elevation: 6,
//                       ),
//                       onPressed: _busy ? null : _logout,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           if (_busy)
//             IgnorePointer(
//               child: Container(
//                 color: Colors.black26,
//                 alignment: Alignment.center,
//                 child: const CircularProgressIndicator(),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// // Decorative soft circle
// class _DecorativeCircle extends StatelessWidget {
//   const _DecorativeCircle({required this.size, required this.opacity});
//   final double size;
//   final double opacity;

//   @override
//   Widget build(BuildContext context) {
//     return Opacity(
//       opacity: opacity,
//       child: Container(
//         width: size,
//         height: size,
//         decoration: const BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: LinearGradient(
//             colors: [Colors.white, Colors.white70],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, User, EmailAuthProvider, FirebaseAuthException;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/profile/user_profile_service.dart';
import 'auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    // Make sure Firestore doc exists:
    UserProfileService.instance.ensureUserDoc();
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Pick image -> upload to Storage -> update Auth photoURL + Firestore ---
  Future<void> _editProfilePicture() async {
    if (_user == null) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (x == null) return;

    setState(() => _busy = true);
    try {
      final file = File(x.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${_user!.uid}/avatar.jpg');

      final meta = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(file, meta);

      final url = await ref.getDownloadURL();

      await _user!.updatePhotoURL(url);
      await UserProfileService.instance.updateProfile(photoURL: url);

      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      setState(() {});
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Edit name + (optionally) email via verifyBeforeUpdateEmail ---
  Future<void> _editProfile() async {
    if (_user == null) return;

    final nameCtrl = TextEditingController(text: _user!.displayName ?? '');
    final emailCtrl = TextEditingController(text: _user!.email ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  return (!t.contains('@') || t.startsWith('@') || t.endsWith('@'))
                      ? 'Enter a valid email'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);

              setState(() => _busy = true);
              try {
                // 1) Update display name (Auth + Firestore)
                final newName = nameCtrl.text.trim();
                if (newName != (_user!.displayName ?? '')) {
                  await _user!.updateDisplayName(newName);
                  await UserProfileService.instance
                      .updateProfile(displayName: newName);
                }

                // 2) Update email via verification
                final newEmail = emailCtrl.text.trim();
                if (newEmail != (_user!.email ?? '')) {
                  try {
                    await _user!.verifyBeforeUpdateEmail(newEmail);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Verification sent to $newEmail. Confirm via your inbox to finish updating.')));
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      await _reauthThen(
                        () => _user!.verifyBeforeUpdateEmail(newEmail),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Email update failed: ${e.code}')),
                      );
                    }
                  }
                }

                // 3) Refresh local user & Firestore email (if it changed)
                await _user!.reload();
                _user = FirebaseAuth.instance.currentUser;
                final refreshedEmail = _user!.email;
                await UserProfileService.instance
                    .updateProfile(email: refreshedEmail);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')));
                setState(() {});
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Update failed: $e')));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- Change password (reauthenticate with current password first) ---
  Future<void> _changePassword() async {
    final currentEmail = _user?.email ?? '';
    if (_user == null || currentEmail.isEmpty) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure1 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure1 = !obscure1),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: 'New password (6+ chars)',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure2 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure2 = !obscure2),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure3,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure3 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure3 = !obscure3),
                        ),
                      ),
                      validator: (v) =>
                          (v != newCtrl.text) ? 'Passwords do not match' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext);

                    setState(() => _busy = true);
                    try {
                      final cred = EmailAuthProvider.credential(
                        email: currentEmail,
                        password: currentCtrl.text,
                      );
                      await _user!.reauthenticateWithCredential(cred);
                      await _user!.updatePassword(newCtrl.text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed')));
                    } on FirebaseAuthException catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('Password change failed: ${e.code}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Password change failed: $e')));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Helper: prompt password, reauth, then run [action].
  Future<void> _reauthThen(Future<void> Function() action) async {
    if (_user == null || (_user!.email ?? '').isEmpty) return;

    final pwdCtrl = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Re-authentication required'),
              content: TextField(
                controller: pwdCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setStateDialog(() => obscure = !obscure),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final email = _user!.email!;
      final cred =
          EmailAuthProvider.credential(email: email, password: pwdCtrl.text);
      await _user!.reauthenticateWithCredential(cred);
      await action();
      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully')));
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Re-auth failed: ${e.code}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build UI from Firestore live data (falls back to Auth values).
    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserProfileService.instance.profileStream(),
      builder: (context, snap) {
        final authUser = _user;
        final data = snap.data ?? {};
        final displayName =
            (data['displayName'] as String?) ?? authUser?.displayName ?? 'TeaHealth User';
        final email =
            (data['email'] as String?) ?? authUser?.email ?? 'unknown@example.com';
        final photo = (data['photoURL'] as String?) ?? authUser?.photoURL;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text('Profile', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const Positioned(
                  top: -60,
                  right: -40,
                  child: _DecorativeCircle(size: 180, opacity: 0.18)),
              const Positioned(
                  bottom: -50,
                  left: -30,
                  child: _DecorativeCircle(size: 240, opacity: 0.14)),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      // Profile card
                      Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 52,
                                    backgroundImage: (photo != null && photo.isNotEmpty)
                                        ? NetworkImage(photo)
                                        : const AssetImage('assets/images/profile.png')
                                            as ImageProvider,
                                  ),
                                  InkWell(
                                    onTap: _busy ? null : _editProfilePicture,
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 2, bottom: 2),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        _busy ? Icons.hourglass_top : Icons.edit,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(displayName,
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(email,
                                  style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 12),
                              const Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                      avatar: Icon(Icons.verified_user, size: 18),
                                      label: Text('TeaHealth user')),
                                  Chip(
                                      avatar: Icon(Icons.insights, size: 18),
                                      label: Text('Disease & deficiency checks')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Settings/actions
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit_outlined,
                                  color: Colors.green),
                              title: const Text('Edit Profile'),
                              subtitle: const Text('Update your name and email'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy ? null : _editProfile,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.lock_reset,
                                  color: Colors.green),
                              title: const Text('Change Password'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy ? null : _changePassword,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.help_outline,
                                  color: Colors.green),
                              title: const Text('Help & Support'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {/* TODO: your help screen */},
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logout
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 6,
                          ),
                          onPressed: _busy ? null : _logout,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_busy)
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
      },
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


