import 'dart:math' as math;

import 'package:fixitzed_fixer_app/models/notification_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationDetailsSheet extends StatelessWidget {
  const NotificationDetailsSheet({super.key, required this.notification});

  final NotificationItem notification;

  static Future<void> show(
    BuildContext context, {
    required NotificationItem notification,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.62 : 0.42,
      ),
      builder: (_) => NotificationDetailsSheet(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = NotificationVisualStyle.resolve(theme, notification);
    final formattedDate = DateFormat(
      'dd MMM yyyy • HH:mm',
    ).format(notification.createdAt);
    final title = notification.title.trim().isEmpty
        ? 'Notification'
        : notification.title.trim();
    final body = notification.body.trim().isEmpty
        ? 'No additional details are available for this notification.'
        : notification.body.trim();
    final statusLabel = notification.read ? 'Read' : 'Unread';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final sheetTop = theme.brightness == Brightness.dark
        ? Color.alphaBlend(
            const Color(0xFFF1592A).withValues(alpha: 0.12),
            scheme.surface,
          )
        : const Color(0xFFFFF5EE);
    final sheetBottom = theme.brightness == Brightness.dark
        ? scheme.surface
        : scheme.surface;
    final cardBorder = scheme.outline.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
    );
    final textPrimary = scheme.onSurface;
    final textSecondary = scheme.onSurface.withValues(alpha: 0.62);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(12, bottomInset + 12)),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: size.height * 0.78,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sheetTop, sheetBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.34
                              : 0.12,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.18
                                      : 0.05,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: visual.backgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  visual.icon,
                                  color: visual.accentColor,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  customBorder: const CircleBorder(),
                                  child: Ink(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: textSecondary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.16
                                      : 0.04,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      formattedDate,
                                      style: GoogleFonts.urbanist(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _StatusChip(
                                    label: statusLabel,
                                    read: notification.read,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: scheme.outline.withValues(alpha: 0.12),
                                height: 1,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                body,
                                style: GoogleFonts.urbanist(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: textPrimary.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Divider(
                                color: scheme.outline.withValues(alpha: 0.12),
                                height: 1,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFF1592A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationVisualStyle {
  const NotificationVisualStyle({
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  static NotificationVisualStyle resolve(
    ThemeData theme,
    NotificationItem notification,
  ) {
    final scheme = theme.colorScheme;
    final hints = <String>[
      notification.type,
      notification.iconKey ?? '',
      notification.title,
      notification.body,
      notification.data['type']?.toString() ?? '',
      notification.data['notification_type']?.toString() ?? '',
      notification.data['icon']?.toString() ?? '',
      notification.data['category']?.toString() ?? '',
    ].join(' ').toLowerCase();

    const brand = Color(0xFFF1592A);
    const green = Color(0xFF2E9D6A);
    const blue = Color(0xFF3276E8);
    const red = Color(0xFFE45A4F);

    Color tinted(Color color, double opacity) {
      return Color.alphaBlend(color.withValues(alpha: opacity), scheme.surface);
    }

    if (_hasAny(hints, [
      'wallet',
      'payment',
      'payout',
      'earnings',
      'transaction',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.account_balance_wallet_outlined,
        accentColor: green,
        backgroundColor: tinted(
          green,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, ['chat', 'message', 'support', 'reply'])) {
      return NotificationVisualStyle(
        icon: Icons.chat_bubble_outline_rounded,
        accentColor: blue,
        backgroundColor: tinted(
          blue,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, [
      'alert',
      'warning',
      'cancel',
      'declined',
      'failed',
      'issue',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.error_outline_rounded,
        accentColor: red,
        backgroundColor: tinted(
          red,
          theme.brightness == Brightness.dark ? 0.18 : 0.12,
        ),
      );
    }
    if (_hasAny(hints, [
      'booking',
      'request',
      'service',
      'repair',
      'job',
      'fixer',
      'assigned',
    ])) {
      return NotificationVisualStyle(
        icon: Icons.event_available_rounded,
        accentColor: brand,
        backgroundColor: tinted(
          brand,
          theme.brightness == Brightness.dark ? 0.2 : 0.12,
        ),
      );
    }
    return NotificationVisualStyle(
      icon: Icons.notifications_active_outlined,
      accentColor: brand,
      backgroundColor: tinted(
        brand,
        theme.brightness == Brightness.dark ? 0.2 : 0.12,
      ),
    );
  }

  static bool _hasAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.read});

  final String label;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = read
        ? scheme.onSurface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
          )
        : const Color(0xFFF1592A).withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
          );
    final foreground = read
        ? scheme.onSurface.withValues(alpha: 0.82)
        : const Color(0xFFF1592A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
