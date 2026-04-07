import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:fixitzed_fixer_app/common/connectivity/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dark theme exposes FixItZed semantic colors', (tester) async {
    late ThemeData resolvedTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            resolvedTheme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedTheme.brightness, Brightness.dark);
    expect(resolvedTheme.fx.page, isNot(equals(AppTheme.light().fx.page)));
    expect(resolvedTheme.fx.textPrimary, isNot(equals(Colors.black)));
  });

  testWidgets('Connectivity banner shows offline copy when visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConnectivityBanner(visible: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. We'll reconnect automatically."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets('Connectivity banner shows restored copy when restored', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectivityBanner(
            visible: true,
            status: ConnectivityBannerStatus.restored,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Internet restored'), findsOneWidget);
  });
}
