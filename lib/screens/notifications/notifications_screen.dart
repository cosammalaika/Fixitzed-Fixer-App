import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:fixitzed_fixer_app/models/notification_item.dart';
import 'package:fixitzed_fixer_app/screens/notifications/widgets/notification_details_sheet.dart';
import 'package:fixitzed_fixer_app/state/app_sync.dart';
import 'package:fixitzed_fixer_app/services/notifications_service.dart';
import 'package:fixitzed_fixer_app/state/service_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final NotificationsService _svc;
  bool _loading = true;
  bool _hardFailure = false;
  List<NotificationItem> _items = const [];
  StreamSubscription<AppSyncEvent>? _subscription;
  final Set<int> _deleting = <int>{};
  final Set<int> _markingRead = <int>{};
  final Set<String> _pendingRemovalKeys = <String>{};
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _svc = ref.read(notificationsServiceProvider);
    unawaited(_load());
    _subscription = AppSync.instance
        .on(AppSyncTopic.notifications)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    final existing = _loadFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _performLoad(silent: silent, forceRefresh: forceRefresh);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _performLoad({
    required bool silent,
    required bool forceRefresh,
  }) async {
    final shouldShowLoader = !silent && _items.isEmpty;
    if (shouldShowLoader && mounted) {
      setState(() => _loading = true);
    }
    final result = await _svc.load(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _items = result.items;
      _hardFailure =
          !result.success && !result.usedCacheFallback && result.items.isEmpty;
      _loading = false;
    });
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isYesterday(DateTime d) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }

  Widget _dismissBackground({required bool leading}) {
    final colors = Theme.of(context).fx;
    return Align(
      alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 78,
        height: 56,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.danger,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(NotificationItem notification, String key) async {
    if (_deleting.contains(notification.id)) return false;
    setState(() => _deleting.add(notification.id));
    final ok = await _svc.delete(notification.id);
    if (!mounted) return false;
    setState(() => _deleting.remove(notification.id));
    if (!ok) {
      _pendingRemovalKeys.add(key);
      _removeNotification(notification, synced: false);
      return true;
    }
    return true;
  }

  void _removeNotification(
    NotificationItem notification, {
    bool synced = true,
  }) {
    if (!mounted) return;
    setState(() {
      _items = _items.where((item) => item.id != notification.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Notification removed'
              : 'Notification hidden locally. Could not sync with server.',
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        backgroundColor: synced
            ? const Color(0xFF2E7D32)
            : const Color(0xFFE67E22),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleTap(NotificationItem notification) async {
    NotificationItem? current;
    for (final item in _items) {
      if (item.id == notification.id) {
        current = item;
        break;
      }
    }

    final selected = current ?? notification;
    final itemForSheet = _markAsReadOptimistically(selected);
    if (!mounted) return;
    final requestId = itemForSheet.serviceRequestId;
    if (requestId != null && requestId > 0) {
      await Navigator.of(
        context,
      ).pushNamed('/booking_detail', arguments: {'id': requestId});
      if (!mounted) return;
      unawaited(_load(silent: true, forceRefresh: true));
      return;
    }
    await NotificationDetailsSheet.show(context, notification: itemForSheet);
  }

  NotificationItem _markAsReadOptimistically(NotificationItem notification) {
    if (notification.read || _markingRead.contains(notification.id)) {
      return notification.read
          ? notification
          : notification.copyWith(
              read: true,
              readAt: notification.readAt ?? DateTime.now(),
            );
    }

    final updated = notification.copyWith(
      read: true,
      readAt: notification.readAt ?? DateTime.now(),
    );

    setState(() {
      _items = [
        for (final item in _items)
          if (item.id == notification.id) updated else item,
      ];
      _markingRead.add(notification.id);
    });

    unawaited(_syncReadState(notification.id));
    return updated;
  }

  Future<void> _syncReadState(int notificationId) async {
    final ok = await _svc.markRead(notificationId);
    if (!mounted) return;

    setState(() => _markingRead.remove(notificationId));

    if (!ok) {
      await _load(silent: true);
    }
  }

  Widget _dismissibleTile(NotificationItem notification) {
    final key = 'notif_${notification.id}';
    return Dismissible(
      key: ValueKey<String>(key),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(leading: true),
      secondaryBackground: _dismissBackground(leading: false),
      confirmDismiss: (_) => _confirmDelete(notification, key),
      onDismissed: (_) {
        if (_pendingRemovalKeys.remove(key)) return;
        _removeNotification(notification);
      },
      child: _tile(notification),
    );
  }

  Widget _tile(NotificationItem n) {
    final timeStr = DateFormat('HH:mm').format(n.createdAt);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.fx;
    final visual = NotificationVisualStyle.resolve(theme, n);
    final title = n.title.trim().isEmpty ? 'Notification' : n.title.trim();
    final preview = n.body.trim().isEmpty
        ? 'No additional details available.'
        : n.body.trim();
    final cardColor = n.read
        ? theme.brightness == Brightness.dark
              ? colors.surfaceRaised
              : colors.surfaceSubtle
        : Color.alphaBlend(
            colors.brand.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.05,
            ),
            colors.surface,
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(n),
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFFF1592A).withValues(alpha: 0.1),
        highlightColor: const Color(0xFFF1592A).withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: n.read
                    ? Colors.transparent
                    : colors.brand.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: visual.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visual.icon, color: visual.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: GoogleFonts.urbanist(
                              color: scheme.onSurface.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          color: scheme.onSurface.withValues(alpha: 0.62),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!n.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1592A),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = <NotificationItem>[];
    final yesterday = <NotificationItem>[];
    final earlier = <NotificationItem>[];
    for (final n in _items) {
      final d = n.createdAt;
      if (_isToday(d)) {
        today.add(n);
      } else if (_isYesterday(d)) {
        yesterday.add(n);
      } else {
        earlier.add(n);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Notification',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hardFailure
          ? RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Theme.of(context).fx.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load notifications',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).fx.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to try again when your connection is stable.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      color: Theme.of(context).fx.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (today.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Today',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _items.isEmpty
                              ? null
                              : () async {
                                  final ok = await _svc.markAllRead();
                                  if (ok) {
                                    await _load(
                                      silent: true,
                                      forceRefresh: true,
                                    );
                                  }
                                },
                          child: Text(
                            'Mark All As Read',
                            style: TextStyle(color: Theme.of(context).fx.brand),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...today.map(_dismissibleTile),
                    const SizedBox(height: 18),
                  ],
                  if (yesterday.isNotEmpty) ...[
                    Text(
                      'Yesterday',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...yesterday.map(_dismissibleTile),
                    const SizedBox(height: 18),
                  ],
                  if (earlier.isNotEmpty) ...[
                    Text(
                      'Earlier',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...earlier.map(_dismissibleTile),
                  ],
                  if (today.isEmpty && yesterday.isEmpty && earlier.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Theme.of(context).fx.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: GoogleFonts.urbanist(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
