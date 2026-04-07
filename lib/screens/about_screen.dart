import 'package:flutter/material.dart';
import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _supportEmail = 'support@fixitzed.com';
  static const String _supportPhone = '+260 979 871 199';
  static const String _supportHours = 'Mon – Fri, 08:00 – 18:00 CAT';
  static const String _scripture =
      '“Whatever you do, work at it with all your heart.” — Colossians 3:23';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).fx;
    final textTheme = GoogleFonts.urbanistTextTheme(
      Theme.of(context).textTheme,
    );

    Widget infoCard({
      required IconData icon,
      required String title,
      required String message,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (Theme.of(context).brightness == Brightness.light)
              BoxShadow(
                color: colors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: colors.brand),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        title: Text(
          'About FixitZed',
          style: GoogleFonts.urbanist(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF1592A), Color(0xFFFF8A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF1592A).withOpacity(0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Built for Fixers, Loved by Customers',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FixitZed connects skilled fixers with people who need reliable home services. '
                    'We help you showcase your expertise, manage bookings, and grow your reputation.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  if (Theme.of(context).brightness == Brightness.light)
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: colors.brand),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _scripture,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.apartment_rounded,
              title: 'Who We Are',
              message:
                  'FixitZed is a Zambian technology team building better access to trusted service professionals. '
                  'Our mission is to make home maintenance effortless while empowering fixers with digital tools.',
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.handshake_rounded,
              title: 'What You Get',
              message:
                  '• Smart job matching based on your skills and priority points.\n'
                  '• Secure payments and transparent booking management.\n'
                  '• Dedicated support to help you deliver outstanding service.',
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.support_agent_rounded,
              title: 'Need Help?',
              message:
                  'Email: $_supportEmail\n'
                  'Phone: $_supportPhone\n'
                  'Support Hours: $_supportHours',
            ),
          ],
        ),
      ),
    );
  }
}
