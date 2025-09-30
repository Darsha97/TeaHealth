import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teascan_app/presentation/pages/splash_screen.dart';
import 'presentation/pages/home_page.dart';
import 'package:firebase_core/firebase_core.dart';

// void main() {
//   runApp(const ProviderScope(child: TeaScanApp()));
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: const FirebaseOptions(
    apiKey: "AIzaSyDpG04-zKXNF0u3nyp28C7brpTFYpr3atE",
    appId: "1:84109868679:android:89e207a51b561159978222",
    messagingSenderId: "84109868679",
    projectId: "teahealth-6d55b",
    storageBucket: "teahealth-6d55b.appspot.com",
  ),);
  runApp(const ProviderScope(child: TeaScanApp()));
}


class TeaScanApp extends StatelessWidget {
  const TeaScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TeaScan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

