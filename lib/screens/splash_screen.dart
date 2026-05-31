import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_fixer_app/services/session_manager.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('fixer_onboarding_seen') ?? false;
    if (!mounted) return;

    if (!hasSeen) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final sessionState = await SessionManager.instance.probeStoredSession();
    if (!mounted) return;

    String route;
    if (sessionState == SessionValidationResult.missingToken ||
        sessionState == SessionValidationResult.wrongApp) {
      if (sessionState == SessionValidationResult.wrongApp) {
        await SessionManager.instance.ensureForcedLogout(
          reason: 'sessionExpired',
        );
      }
      route = '/signin';
    } else if (sessionState == SessionValidationResult.invalidToken) {
      await SessionManager.instance.ensureForcedLogout(
        reason: 'sessionExpired',
      );
      route = '/signin';
    } else if (sessionState == SessionValidationResult.accountDisabled) {
      await SessionManager.instance.ensureForcedLogout(
        reason: 'accountDisabled',
      );
      route = '/account_blocked';
    } else {
      // Keep signed-in fixers moving when validation is inconclusive due to connectivity.
      route = '/home';
    }

    if (!mounted) return;
    if (route == '/home') {
      unawaited(ref.read(preloadServiceProvider).preloadAll());
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C1A2B), Color(0xFF112B44)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -120,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 24,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'FixItZed Fixer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting pros to every job',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: 88,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
