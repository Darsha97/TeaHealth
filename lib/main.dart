// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_core/firebase_core.dart';

// import 'presentation/pages/splash_screen.dart';
// import 'app.dart';


// // Read once and reuse everywhere
// const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

// // Future<void> main() async {
// //   WidgetsFlutterBinding.ensureInitialized();

// //   try {
// //     await Firebase.initializeApp(
// //       options: const FirebaseOptions(
// //         apiKey: "AIzaSyDpG04-zKXNF0u3nyp28C7brpTFYpr3atE",
// //         appId: "1:84109868679:android:89e207a51b561159978222",
// //         messagingSenderId: "84109868679",
// //         projectId: "teahealth-6d55b",
// //         storageBucket: "teahealth-6d55b.appspot.com",
// //       ),
// //     );
// //   } catch (e) {
// //     // If init fails, you can show a fallback screen or rethrow
// //     debugPrint('🔥 Firebase init failed: $e');
// //   }

// //   if (kGeminiApiKey.isEmpty) {
// //     // In release builds, assert won't run—so do a real check.
// //     debugPrint('⚠️ GEMINI_API_KEY missing; AI recommendations will be disabled.');
// //     // You could also block startup here if you prefer:
// //     // runApp(const MissingKeyScreen()); return;
// //   }
// //   print('🔑 GEMINI_API_KEY found, length ${kGeminiApiKey.length}.') ;
// //   runApp(const ProviderScope(child: TeaScanApp()));
// // }


// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const ProviderScope(child: TeaScanApp()));
// }

// class TeaScanApp extends StatelessWidget {
//   const TeaScanApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'TeaScan',
//       theme: ThemeData(
//         colorSchemeSeed: Colors.green,
//         scaffoldBackgroundColor: Colors.white,
//         fontFamily: 'Roboto',
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';
 
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase using platform defaults; do not reference DefaultFirebaseOptions.
 await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

  );
  runApp(const ProviderScope(child: TeaScanAppp()));
}

  