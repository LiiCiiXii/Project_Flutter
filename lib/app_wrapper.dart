import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/views/auth_selector_screen.dart';
import 'package:flutter_project/views/first_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project/views/home_screen.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
  }

  Future<void> _determineInitialScreen() async {
    try {
      // Check if user is logged in with Firebase
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // User is logged in, go directly to HomeScreen
        setState(() {
          _initialScreen = const HomeScreen();
          _isLoading = false;
        });
      } else {
        // User is not logged in, check if they've seen onboarding
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;
        
        if (hasSeenOnboarding) {
          // User has seen onboarding before but is logged out, go to auth selector
          setState(() {
            // _initialScreen = const AuthSelectorScreen();
            _initialScreen = const WelcomeScreen();
            _isLoading = false;
          });
        } else {
          // New user, show welcome screen (full onboarding flow)
          setState(() {
            _initialScreen = const WelcomeScreen();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // If there's an error, default to welcome screen
      setState(() {
        _initialScreen = const WelcomeScreen();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    return _initialScreen ?? const WelcomeScreen();
  }
}