 

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



import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, User, EmailAuthProvider, FirebaseAuthException;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../core/profile/user_profile_service.dart';
import '../../core/localization/app_localizations.dart';
import 'auth/login_page.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'map_history_page.dart';

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
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations?.logoutFailed ?? 'Logout failed'}: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Compress image to stay under Firestore's 1MB limit per field
  /// Target: max 600KB raw (becomes ~800KB base64)
  Future<Uint8List> _compressImage(Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return originalBytes;

      // Target dimensions: max 800px on longest side for profile pics (smaller than scan images)
      const maxDimension = 800;
      img.Image resized = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: maxDimension);
        } else {
          resized = img.copyResize(decoded, height: maxDimension);
        }
      }

      // Encode with quality 75, then reduce if needed
      int quality = 75;
      Uint8List compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      
      // If still too large, reduce quality further
      while (compressed.length > 500000 && quality > 40) {
        quality -= 10;
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      // If still too large, resize more aggressively
      if (compressed.length > 500000) {
        const aggressiveMax = 600;
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: aggressiveMax);
        } else {
          resized = img.copyResize(decoded, height: aggressiveMax);
        }
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 60));
      }

      return compressed;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return originalBytes;
    }
  }

  // --- Pick image -> compress -> store as Base64 in Firestore ---
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
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }

      // Read file bytes
      final originalBytes = await file.readAsBytes();
      
      // Compress image
      final compressedBytes = await _compressImage(originalBytes);
      
      // Convert to Base64
      final base64String = base64Encode(compressedBytes);
      
      // Check size (Base64 is ~33% larger, so 800KB base64 = ~600KB raw)
      if (base64String.length > 800000) {
        throw Exception('Image too large even after compression. Please try a smaller image.');
      }

      // Store in Firestore (using photoB64 field)
      await UserProfileService.instance.updateProfile(
        extra: {'photoB64': base64String},
      );

      // Reload user data
      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.profilePhotoUpdated ?? 'Profile photo updated successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations?.uploadFailed ?? 'Upload failed'}: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Edit name + (optionally) email via verifyBeforeUpdateEmail ---
  Future<void> _editProfile() async {
    if (_user == null) return;

    // Get current values from user
    await _user!.reload();
    _user = FirebaseAuth.instance.currentUser;
    if (_user == null) return;

    final nameCtrl = TextEditingController(text: _user!.displayName ?? '');
    final emailCtrl = TextEditingController(text: _user!.email ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            localizations?.editProfile ?? 'Edit Profile',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: localizations?.name ?? 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? (localizations?.enterYourName ?? 'Enter your name') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: localizations?.email ?? 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    return (!t.contains('@') || t.startsWith('@') || t.endsWith('@'))
                        ? (localizations?.enterValidEmail ?? 'Enter a valid email')
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext);

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
                    final loc = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '${loc?.verificationSentTo ?? 'Verification sent to'} $newEmail. ${loc?.confirmViaInbox ?? 'Confirm via your inbox to finish updating.'}')));
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      await _reauthThen(
                        () => _user!.verifyBeforeUpdateEmail(newEmail),
                      );
                    } else if (mounted) {
                      final loc = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${loc?.emailUpdateFailed ?? 'Email update failed'}: ${e.code}')),
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
                final loc = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc?.profileUpdated ?? 'Profile updated')));
                setState(() {});
              } catch (e) {
                if (!mounted) return;
                final loc = AppLocalizations.of(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('${loc?.updateFailed ?? 'Update failed'}: $e')));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: Text(localizations?.save ?? 'Save'),
          ),
        ],
      );
      },
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
        final localizations = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(localizations?.changePassword ?? 'Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscure1,
                      decoration: InputDecoration(
                        labelText: localizations?.currentPassword ?? 'Current password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure1 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure1 = !obscure1),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? (localizations?.enterCurrentPassword ?? 'Enter current password') : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscure2,
                      decoration: InputDecoration(
                        labelText: localizations?.newPassword ?? 'New password (6+ chars)',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure2 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure2 = !obscure2),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? (localizations?.min6Characters ?? 'Min 6 characters') : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure3,
                      decoration: InputDecoration(
                        labelText: localizations?.confirmNewPassword ?? 'Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                              obscure3 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscure3 = !obscure3),
                        ),
                      ),
                      validator: (v) =>
                          (v != newCtrl.text) ? (localizations?.passwordsDoNotMatch ?? 'Passwords do not match') : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(localizations?.cancel ?? 'Cancel'),
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
                      final loc = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc?.passwordChanged ?? 'Password changed')));
                    } on FirebaseAuthException catch (e) {
                      if (!mounted) return;
                      final loc = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('${loc?.passwordChangeFailed ?? 'Password change failed'}: ${e.code}')));
                    } catch (e) {
                      if (!mounted) return;
                      final loc = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${loc?.passwordChangeFailed ?? 'Password change failed'}: $e')));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                  child: Text(localizations?.update ?? 'Update'),
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
        final localizations = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(localizations?.reauthenticationRequired ?? 'Re-authentication required'),
              content: TextField(
                controller: pwdCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: localizations?.currentPassword ?? 'Current password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setStateDialog(() => obscure = !obscure),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(localizations?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(localizations?.continueText ?? 'Continue'),
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
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.updatedSuccessfully ?? 'Updated successfully')));
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${localizations?.reauthFailed ?? 'Re-auth failed'}: ${e.code}')));
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
        // Try photoB64 first (Firestore), then photoURL (Storage/Auth), then fallback
        final photoB64 = data['photoB64'] as String?;
        final photoURL = (data['photoURL'] as String?) ?? authUser?.photoURL;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.profile ?? 'Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
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
                        elevation: 12,
                        shadowColor: Colors.black.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 56,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: photoB64 != null && photoB64.isNotEmpty
                                            ? MemoryImage(base64Decode(photoB64))
                                            : (photoURL != null && photoURL.isNotEmpty)
                                                ? NetworkImage(photoURL)
                                                : const AssetImage('assets/images/profile.png')
                                                    as ImageProvider,
                                        onBackgroundImageError: (_, __) {
                                          // Handle image load error
                                        },
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _busy ? null : _editProfilePicture,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 4, bottom: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          _busy ? Icons.hourglass_top : Icons.camera_alt,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email_outlined, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade50,
                                            Colors.green.shade100.withOpacity(0.5),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.green.shade200, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_user, size: 18, color: Colors.green.shade700),
                                          const SizedBox(width: 6),
                                          Builder(
                                            builder: (context) {
                                              final localizations = AppLocalizations.of(context);
                                              return Text(
                                                localizations?.teaHealthUser ?? 'TeaHealth user',
                                                style: TextStyle(
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade50,
                                            Colors.blue.shade100.withOpacity(0.5),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue.shade200, width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.insights, size: 18, color: Colors.blue.shade700),
                                          const SizedBox(width: 6),
                                          Builder(
                                            builder: (context) {
                                              final localizations = AppLocalizations.of(context);
                                              return Text(
                                                localizations?.healthChecks ?? 'Health Checks',
                                                style: TextStyle(
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Settings/actions
                      Card(
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(context);
                                  return Column(
                                    children: [
                                      _SettingsTile(
                                        icon: Icons.person_outline,
                                        iconColor: Colors.blue,
                                        title: localizations?.editProfile ?? 'Edit Profile',
                                        subtitle: localizations?.updateNameAndEmail ?? 'Update your name and email',
                                        onTap: _busy ? null : _editProfile,
                                      ),
                                      const Divider(height: 1, indent: 70, endIndent: 16),
                                      _SettingsTile(
                                        icon: Icons.lock_outline,
                                        iconColor: Colors.orange,
                                        title: localizations?.changePassword ?? 'Change Password',
                                        subtitle: localizations?.updateAccountPassword ?? 'Update your account password',
                                        onTap: _busy ? null : _changePassword,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logout
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return ElevatedButton.icon(
                              icon: const Icon(Icons.logout, size: 20),
                              label: Text(
                                localizations?.logout ?? 'Logout',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _busy ? null : _logout,
                            );
                          },
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
          bottomNavigationBar: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.white,
                    elevation: 12,
                    selectedItemColor: Colors.green,
                    unselectedItemColor: Colors.black54,
                    type: BottomNavigationBarType.fixed,
                    currentIndex: 3,
                    items: [
                      BottomNavigationBarItem(icon: const Icon(Icons.home), label: localizations?.home ?? 'Home'),
                      BottomNavigationBarItem(icon: const Icon(Icons.history), label: localizations?.history ?? 'History'),
                      BottomNavigationBarItem(icon: const Icon(Icons.map), label: localizations?.map ?? 'Map'),
                      BottomNavigationBarItem(icon: const Icon(Icons.person), label: localizations?.profile ?? 'Profile'),
                    ],
                onTap: (index) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryPage()),
                    );
                  } else if (index == 2) {
                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => MapHistoryPage(uid: user.uid)),
                      );
                    } else {
                      final localizations = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations?.pleaseLoginToViewMap ?? 'Please log in to view map')),
                      );
                    }
                  }
                },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Settings tile widget
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
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


