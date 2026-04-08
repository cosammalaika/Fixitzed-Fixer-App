import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:fixitzed_fixer_app/screens/about_screen.dart';
import 'package:fixitzed_fixer_app/screens/auth/account_blocked_screen.dart';
import 'package:fixitzed_fixer_app/screens/bookings/booking_detail_screen.dart';
import 'package:fixitzed_fixer_app/screens/bookings/bookings_list_screen.dart';
import 'package:fixitzed_fixer_app/screens/dashboard_screen.dart';
import 'package:fixitzed_fixer_app/screens/home_shell.dart';
import 'package:fixitzed_fixer_app/screens/notifications/notifications_screen.dart';
import 'package:fixitzed_fixer_app/screens/onboarding_screen.dart';
import 'package:fixitzed_fixer_app/screens/profile/edit_profile_screen.dart';
import 'package:fixitzed_fixer_app/screens/profile/profile_screen.dart';
import 'package:fixitzed_fixer_app/screens/settings_screen.dart';
import 'package:fixitzed_fixer_app/screens/sign_in_screen.dart';
import 'package:fixitzed_fixer_app/screens/splash_screen.dart';
import 'package:fixitzed_fixer_app/screens/subscriptions/subscription_screen.dart';
import 'package:fixitzed_fixer_app/screens/transactions/wallet_transactions_screen.dart';
import 'package:fixitzed_fixer_app/services/local_notification_service.dart';
import 'package:fixitzed_fixer_app/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_fixer_app/common/connectivity/connectivity_overlay.dart';
import 'package:fixitzed_fixer_app/widgets/session_redirector.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await LocalNotificationService.instance.init();
  LocalNotificationService.instance.bindNavigator(appNavigatorKey);
  await FcmService.instance.init();
  runApp(const ProviderScope(child: FixerApp()));
}

class FixerApp extends ConsumerWidget {
  const FixerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final lightTheme = AppTheme.light();
        final darkTheme = AppTheme.dark();
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'FixItZed Fixer',
          debugShowCheckedModeBanner: false,
          theme: lightTheme.copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(lightTheme.textTheme),
          ),
          darkTheme: darkTheme.copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(darkTheme.textTheme),
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
            '/settings': (context) => const SettingsScreen(),
            '/wallet/transactions': (context) =>
                const WalletTransactionsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/about': (context) => const AboutScreen(),
            '/account_blocked': (context) => const AccountBlockedScreen(),
          },
          builder: (context, child) {
            final body = child ?? const SizedBox.shrink();
            return SessionRedirector(child: ConnectivityOverlay(child: body));
          },
        );
      },
    );
  }
}
