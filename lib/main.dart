import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/bookings/bookings_list_screen.dart';
import 'screens/bookings/booking_detail_screen.dart';
import 'screens/subscriptions/subscription_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/home_shell.dart';
import 'screens/transactions/wallet_transactions_screen.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await LocalNotificationService.instance.init();
  runApp(const FixerApp());
}

class FixerApp extends StatelessWidget {
  const FixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) => MaterialApp(
        title: "FixItZed Fixer",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().copyWith(
          textTheme: GoogleFonts.urbanistTextTheme(Theme.of(context).textTheme),
        ),
        darkTheme: AppTheme.dark().copyWith(
          textTheme: GoogleFonts.urbanistTextTheme(Theme.of(context).textTheme),
        ),
        themeMode: mode,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/signin': (context) => const SignInScreen(),
          '/home': (context) => const HomeShell(),
          '/dashboard': (context) => const DashboardScreen(),
          '/bookings': (context) => const BookingsListScreen(),
          '/booking_detail': (context) => const BookingDetailScreen(),
          '/subscriptions': (context) => const SubscriptionScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/profile/edit': (context) => const EditProfileScreen(),
          '/wallet/transactions': (context) => const WalletTransactionsScreen(),
          '/notifications': (context) => const NotificationsScreen(),
        },
      ),
    );
  }
}
