import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/views/on_board_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project/views/home_screen.dart';
// import 'package:flutter_project/views/login_screen.dart';
// import 'package:flutter_project/on_board_screen.dart';
import 'package:flutter_project/wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth App',
      debugShowCheckedModeBanner: false,
      home: const LaunchDecider(),
    );
  }
}

class LaunchDecider extends StatefulWidget {
  const LaunchDecider({super.key});

  @override
  State<LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<LaunchDecider> {
  bool _loading = true;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkFirstSeen();
  }

  Future<void> _checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('onboarding_seen') ?? false;

    setState(() {
      _seenOnboarding = seen;
    });

    // Wait briefly to show splash/loading if desired
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If user is already logged in
    if (FirebaseAuth.instance.currentUser != null) {
      return const HomeScreen();
    }

    // If onboarding already shown, go to AuthWrapper (login/signup)
    if (_seenOnboarding) {
      return const AuthWrapper();
    }

    // First-time user, show onboarding
    return const OnboardingScreen();
  }
}
