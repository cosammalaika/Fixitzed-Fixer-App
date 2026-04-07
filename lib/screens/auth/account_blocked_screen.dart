import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_fixer_app/core/app_theme.dart';

class AccountBlockedScreen extends StatelessWidget {
  const AccountBlockedScreen({super.key, this.supportEmail, this.supportPhone});

  final String? supportEmail;
  final String? supportPhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    final accent = colors.brand;

    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_outlined, color: accent, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Access blocked',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your fixer account is currently inactive and cannot access the app. Please contact support so we can help you get back online.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (supportEmail != null || supportPhone != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support contacts',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (supportEmail != null)
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 18,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  supportEmail!,
                                  style: GoogleFonts.urbanist(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (supportEmail != null && supportPhone != null)
                          const SizedBox(height: 8),
                        if (supportPhone != null)
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 18,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  supportPhone!,
                                  style: GoogleFonts.urbanist(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/signin', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
