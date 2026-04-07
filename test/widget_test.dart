import 'package:fixitzed_fixer_app/core/app_theme.dart';
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
}
