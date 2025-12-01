import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfflinePlaceholder extends StatelessWidget {
  const OfflinePlaceholder({
    super.key,
    this.title = 'You\'re offline',
    this.message =
        'We couldn’t reach FixitZed. Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.details,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC7A0), Color(0xFFF1592A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF1592A).withOpacity(0.28),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontSize: 15,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.65),
              ),
            ),
            // if (details != null && details!.isNotEmpty) ...[
            //   const SizedBox(height: 12),
            //   Container(
            //     padding: const EdgeInsets.all(12),
            //     decoration: BoxDecoration(
            //       color: colorScheme.surfaceVariant.withOpacity(0.45),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Text(
            //       details!,
            //       textAlign: TextAlign.center,
            //       style: GoogleFonts.urbanist(
            //         fontSize: 12,
            //         color:
            //             theme.textTheme.bodySmall?.color?.withOpacity(0.55) ??
            //                 Colors.black54,
            //       ),
            //     ),
            //   ),
            // ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1592A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  shadowColor: const Color(0xFFF1592A).withOpacity(0.38),
                  elevation: 8,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  retryLabel,
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
