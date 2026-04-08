import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixitzed_fixer_app/screens/bookings/bookings_list_screen.dart';
import 'package:fixitzed_fixer_app/screens/dashboard_screen.dart';
import 'package:fixitzed_fixer_app/screens/subscriptions/subscription_screen.dart';
import 'package:fixitzed_fixer_app/screens/profile/profile_screen.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';
import 'package:fixitzed_fixer_app/widgets/bottom_nav.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [
    DashboardScreen(),
    BookingsListScreen(),
    SubscriptionScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: FixerBottomNav(
          currentIndex: _index,
          onTap: (i) {
            final wasCurrent = i == _index;
            setState(() => _index = i);
            if (i == 0 && wasCurrent) {
              AppSync.instance.emit(
                AppSyncTopic.dashboard,
                payload: const {'source': 'tab_reselected'},
              );
            }
          },
        ),
      ),
    );
  }
}
