import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('fixer_onboarding_seen') ?? false;
      if (!context.mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(hasSeen ? '/signin' : '/onboarding');
    });

    return const Scaffold(
      // Blank splash: we immediately navigate; no spinner flash.
      body: SizedBox.expand(),
    );
  }
}
