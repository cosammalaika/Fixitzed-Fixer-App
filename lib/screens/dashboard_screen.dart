import 'package:fixitzed_fixer_app/data/models/dashboard_snapshot.dart';
import 'package:fixitzed_fixer_app/models/service_request.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/state/bookings_controller.dart';
import 'package:fixitzed_fixer_app/state/dashboard_controller.dart';
import 'package:fixitzed_fixer_app/ui/snack.dart';
import 'package:fixitzed_fixer_app/widgets/offline_placeholder.dart';
import 'package:fixitzed_fixer_app/common/connectivity/connectivity_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixitzed_fixer_app/widgets/skeletons.dart';
import 'package:fixitzed_fixer_app/widgets/swipe_action_button.dart';

const Color _fixerAcceptColor = Color(0xFF2E7D32);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

enum _RequestSheetResult { accepted, declined, purchase }

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  final _fixer = FixerService();
  DateTime? _lastRefreshTriggerAt;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerRefreshIfDue(reason: 'resume');
    }
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      ref.read(fixerDashboardControllerProvider.notifier).refresh(
        forceRefresh: true,
      ),
      ref.read(fixerBookingsProvider.notifier).refresh(),
    ]);
  }

  void _triggerRefreshIfDue({
    required String reason,
    Duration minInterval = const Duration(seconds: 5),
  }) {
    final now = DateTime.now();
    final last = _lastRefreshTriggerAt;
    if (last != null && now.difference(last) < minInterval) {
      return;
    }
    _lastRefreshTriggerAt = now;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshDashboard();
    });
  }

  // Polling for new requests and prompt fixer
  final Set<int> _seen = {};
  int _coins = 0;
  bool _polling = false;

  void _startPolling() async {
    // Initial wallet
    final w = await _fixer.wallet();
    setState(() {
      _coins = ((w['coin_balance'] ?? w['coins'] ?? 0) as num).toInt();
    });
    _tick();
  }

  Future<void> _tick() async {
    if (!mounted) return;
    if (_polling) return;
    _polling = true;
    try {
      // Assigned-to-me pending
      final assigned = await _fixer.requests(status: 'pending');
      // Attempt to fetch unassigned/eligible if backend supports it
      List<ServiceRequest> pool = [];
      try {
        pool = await _fixer.unassigned();
      } catch (_) {}
      final list = <ServiceRequest>[...assigned, ...pool];
      for (final r in list) {
        if (_seen.contains(r.id)) continue;
        _seen.add(r.id);
        if (!mounted) return;
        await _showRequestDialog(r);
      }
    } finally {
      _polling = false;
      if (mounted) {
        // schedule next tick
        Future.delayed(const Duration(seconds: 10), _tick);
      }
    }
  }

  Future<void> _showRequestDialog(ServiceRequest r) async {
    // Try to load more details (e.g., phone) if available
    String? phone;
    String? address = r.location;
    try {
      final detail = await _fixer.requestDetail(r.id);
      if (detail != null) {
        Map<String, dynamic>? customer;
        final raw = detail['customer'];
        if (raw is Map) customer = Map<String, dynamic>.from(raw);
        phone =
            (customer?['phone'] ??
                    customer?['mobile'] ??
                    customer?['phone_number'])
                ?.toString();
        address = (detail['location'] ?? address)?.toString();
      }
    } catch (_) {}

    if (!mounted) return;
    final result = await showModalBottomSheet<_RequestSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewRequestSheet(
        request: r,
        address: address,
        phone: phone,
        coins: _coins,
        canAccept: _coins > 0,
        onAccept: () => _fixer.acceptRequestDetailed(r.id),
        onDecline: () => _fixer.declineRequest(r.id),
      ),
    );

    if (!mounted) return;
    switch (result) {
      case _RequestSheetResult.accepted:
        AppSnack.show(context, message: 'Request accepted', success: true);
        final w = await _fixer.wallet();
        if (!mounted) return;
        setState(() {
          _coins = ((w['coin_balance'] ?? w['coins'] ?? 0) as num).toInt();
        });
        _refreshDashboard();
        break;
      case _RequestSheetResult.purchase:
        await Navigator.pushNamed(context, '/subscriptions');
        if (!mounted) return;
        final w = await _fixer.wallet();
        if (!mounted) return;
        setState(
          () =>
              _coins = ((w['coin_balance'] ?? w['coins'] ?? 0) as num).toInt(),
        );
        break;
      case _RequestSheetResult.declined:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.isOnline;
    if (_lastOnline == null) {
      _lastOnline = isOnline;
    } else if (_lastOnline == false && isOnline) {
      _lastOnline = isOnline;
      _triggerRefreshIfDue(reason: 'connectivity_regained');
    } else {
      _lastOnline = isOnline;
    }

    final dashboardAsync = ref.watch(fixerDashboardControllerProvider);
    final bookingsAsync = ref.watch(fixerBookingsProvider);
    final snapshot = dashboardAsync.valueOrNull;
    final isInitialLoading = dashboardAsync.isLoading && snapshot == null;

    if (isInitialLoading) {
      return const Scaffold(body: FixerDashboardSkeleton());
    }

    if (snapshot == null) {
      final err = dashboardAsync.error;
      return Scaffold(
        body: OfflinePlaceholder(
          title: 'You\'re offline',
          message:
              'We couldn’t refresh your dashboard. Connect to the internet and try again.',
          onRetry: () =>
              ref.read(fixerDashboardControllerProvider.notifier).refresh(),
          details: kDebugMode && err != null ? err.toString() : null,
        ),
      );
    }

    _coins = snapshot.coins;
    final bookingState = bookingsAsync.valueOrNull;
    final activeCount =
        bookingState?.active.length ??
        snapshot.activeRequests
            .where((r) => r.status != 'completed' && r.status != 'cancelled')
            .length;
    final isRefreshing = dashboardAsync.isLoading;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                snapshot: snapshot,
                isSyncing: isRefreshing,
                isOffline: !isOnline,
                onNotificationsTap: () async {
                  await Navigator.pushNamed(context, '/notifications');
                  if (mounted) _refreshDashboard();
                },
              ),
              const SizedBox(height: 16),
              if (dashboardAsync.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ErrorBanner(
                    message:
                        'Showing your last dashboard snapshot. Pull to refresh.',
                    onRetry: () => ref
                        .read(fixerDashboardControllerProvider.notifier)
                        .refresh(),
                  ),
                ),
              _StatRow(
                notifications: snapshot.unreadNotifications,
                requests: snapshot.activeRequests.length,
                completed: snapshot.completedCount,
              ),
              const SizedBox(height: 16),
              _ActionCard(
                title: 'Active Bookings',
                subtitle: activeCount == 0
                    ? 'No pending jobs right now'
                    : '$activeCount awaiting your action',
                icon: Icons.assignment_turned_in_rounded,
                onTap: () => Navigator.pushNamed(context, '/bookings'),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Requests',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.activeRequests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No requests yet. Once a customer books you, it will appear here.',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...snapshot.activeRequests
                    .take(5)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(
                          request: r,
                          onTap: () {
                            assert(r.id > 0, 'Dashboard booking request id is missing');
                            final payload = r.toJson();
                            if (kDebugMode) {
                              debugPrint(
                                '[Dashboard] tap recent booking id=${r.id} request_id=${payload['request_id'] ?? payload['id']} status=${r.status} keys=${payload.keys.toList()}',
                              );
                            }
                            Navigator.pushNamed(
                              context,
                              '/booking_detail',
                              arguments: {
                                'id': r.id,
                                'request': payload,
                              },
                            );
                          },
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int notifications;
  final int requests;
  final int completed;
  const _StatRow({
    required this.notifications,
    required this.requests,
    required this.completed,
  });
  @override
  Widget build(BuildContext context) {
    Widget box(IconData icon, String label, int value) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFFF1592A)),
            const SizedBox(height: 6),
            _AnimatedValueText(
              text: '$value',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box(Icons.notifications, 'Notifications', notifications),
        box(Icons.work_history, 'Requests', requests),
        box(Icons.check_circle, 'Completed', completed),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26F1592A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFF1592A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.urbanist(
                color: const Color(0xFF5F341F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final FixerDashboardSnapshot snapshot;
  final bool isSyncing;
  final bool isOffline;
  final VoidCallback onNotificationsTap;
  const _HeaderCard({
    required this.snapshot,
    required this.isSyncing,
    required this.isOffline,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    final currency = NumberFormat.currency(symbol: 'K', decimalDigits: 2);
    final lastUpdatedAt = snapshot.serverUpdatedAt ?? snapshot.fetchedAt;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFE45526)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33593F2B),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardAvatar(url: snapshot.avatarUrl, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.displayName.isEmpty
                          ? 'Hi there,'
                          : 'Hi, ${snapshot.displayName}',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.location.isEmpty
                          ? 'Ready to serve today?'
                          : snapshot.location,
                      style: GoogleFonts.urbanist(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    _SyncBadge(
                      isSyncing: isSyncing,
                      isOffline: isOffline,
                      fromCache: snapshot.fromCache,
                      lastUpdatedAt: lastUpdatedAt,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onNotificationsTap,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                    if (snapshot.unreadNotifications > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0x1AF1592A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.electric_bolt_rounded, color: brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscription Coins',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        snapshot.coins > 0
                            ? 'Keep accepting requests to earn more.'
                            : 'Top up to continue accepting jobs.',
                        style: GoogleFonts.urbanist(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _AnimatedValueText(
                  text: '${snapshot.coins}',
                  style: GoogleFonts.urbanist(
                    color: brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).pushNamed(
                '/wallet/transactions',
                arguments: snapshot.totalEarnings,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                      ),
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
                                  'Total Earnings',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ],
                          ),
                          Text(
                            snapshot.totalEarnings > 0
                                ? 'Great job! Keep the momentum going.'
                                : 'Complete jobs to start earning.',
                            style: GoogleFonts.urbanist(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AnimatedValueText(
                      text: currency.format(snapshot.totalEarnings),
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({
    required this.isSyncing,
    required this.isOffline,
    required this.fromCache,
    required this.lastUpdatedAt,
  });

  final bool isSyncing;
  final bool isOffline;
  final bool fromCache;
  final DateTime lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final label = isOffline
        ? 'Offline • showing saved data'
        : isSyncing
            ? 'Syncing...'
            : 'Updated ${_relative(lastUpdatedAt)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOffline
                ? Colors.white60
                : isSyncing
                    ? const Color(0xFFFFE6B3)
                    : const Color(0xFFC3FFD8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fromCache && !isOffline && !isSyncing ? '$label • cache' : label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              color: Colors.white.withOpacity(0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _relative(DateTime value) {
    final delta = DateTime.now().difference(value);
    if (delta.inSeconds < 10) return 'just now';
    if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
    if (delta.inHours < 1) return '${delta.inMinutes}m ago';
    return '${delta.inHours}h ago';
  }
}

class _AnimatedValueText extends StatelessWidget {
  const _AnimatedValueText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
      ),
    );
  }
}

class _DashboardAvatar extends StatefulWidget {
  final String? url;
  final double radius;

  const _DashboardAvatar({required this.url, required this.radius});

  @override
  State<_DashboardAvatar> createState() => _DashboardAvatarState();
}

class _DashboardAvatarState extends State<_DashboardAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final innerRadius = widget.radius - 2;
    final placeholder = ClipOval(
      child: Image.asset(
        'assets/images/logo-sm.png',
        width: innerRadius * 2,
        height: innerRadius * 2,
        fit: BoxFit.cover,
      ),
    );

    Widget child;
    final url = widget.url?.trim() ?? '';
    final validUrl = url.isNotEmpty && url.toLowerCase() != 'null' ? url : '';
    if (!_failed && validUrl.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          validUrl,
          width: innerRadius * 2,
          height: innerRadius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (!_failed && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
            }
            return placeholder;
          },
        ),
      );
    } else {
      child = placeholder;
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.white,
      child: child,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Material(
      color: const Color(0xFFF8EEE8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0x1AF1592A),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = request.status;
    final scheduled = request.scheduledAt != null
        ? DateFormat('d MMM, HH:mm').format(request.scheduledAt!.toLocal())
        : 'Schedule pending';
    final location = request.location?.isNotEmpty == true
        ? request.location!
        : 'No location provided';

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.service.name,
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatStatus(status),
                      style: GoogleFonts.urbanist(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.customer.name,
                      style: GoogleFonts.urbanist(color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      scheduled,
                      style: GoogleFonts.urbanist(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: GoogleFonts.urbanist(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'awaiting_payment':
        return 'Awaiting Payment';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return status.isEmpty
            ? 'Pending'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'completed':
        return const Color(0xFF1976D2);
      case 'awaiting_payment':
      case 'pending':
        return const Color(0xFFF1592A);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFFF1592A);
    }
  }
}

class _NewRequestSheet extends StatefulWidget {
  final ServiceRequest request;
  final String? address;
  final String? phone;
  final int coins;
  final bool canAccept;
  final Future<Map<String, dynamic>> Function() onAccept;
  final Future<Map<String, dynamic>> Function() onDecline;

  const _NewRequestSheet({
    required this.request,
    required this.address,
    required this.phone,
    required this.coins,
    required this.canAccept,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    final scheduled = widget.request.scheduledAt != null
        ? DateFormat(
            'EEE, d MMM • HH:mm',
          ).format(widget.request.scheduledAt!.toLocal())
        : null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF8F3), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [brand, accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: brand.withOpacity(0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New service request',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.request.service.name,
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'A customer is waiting for your response.',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _pill(
                            icon: Icons.person_rounded,
                            label: 'Customer',
                            value: widget.request.customer.name,
                          ),
                          if (scheduled != null)
                            _pill(
                              icon: Icons.schedule_rounded,
                              label: 'Scheduled',
                              value: scheduled,
                            ),
                          _pill(
                            icon: Icons.savings_rounded,
                            label: 'Coins left',
                            value: widget.coins.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _detailTile(
                        icon: Icons.person_outline,
                        label: 'Customer',
                        value: widget.request.customer.name,
                      ),
                      const SizedBox(height: 14),
                      _detailTile(
                        icon: Icons.place_outlined,
                        label: 'Location',
                        value: widget.address?.isNotEmpty == true
                            ? widget.address!
                            : 'Not provided',
                      ),
                      const SizedBox(height: 14),
                      _detailTile(
                        icon: Icons.call_outlined,
                        label: 'Contact',
                        value: widget.phone ?? 'Visible after you accept',
                        trailing: widget.phone != null
                            ? TextButton.icon(
                                onPressed: () => _call(widget.phone!),
                                icon: const Icon(Icons.call_rounded),
                                label: const Text('Call'),
                                style: TextButton.styleFrom(
                                  foregroundColor: brand,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2EA),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on_outlined,
                          color: brand,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.canAccept
                              ? 'Accepting will use your active plan.'
                              : 'You need an active subscription or coins to take this job.',
                          style: GoogleFonts.urbanist(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.canAccept) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Boost your availability by purchasing a plan – it unlocks new bookings instantly.',
                    style: GoogleFonts.urbanist(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing
                            ? null
                            : () async {
                                setState(() => _processing = true);
                                final result = await widget.onDecline();
                                if (!mounted) return;
                                final ok = result['success'] == true;
                                final statusCode = result['statusCode'] as int?;
                                final msg = (result['message'] as String?)?.trim();
                                if (!ok && statusCode != 409 && statusCode != 410) {
                                  setState(() => _processing = false);
                                  AppSnack.show(
                                    context,
                                    message: msg != null && msg.isNotEmpty
                                        ? msg
                                        : 'Failed to decline request. Try again.',
                                    success: false,
                                  );
                                  return;
                                }
                                if (!ok) {
                                  AppSnack.show(
                                    context,
                                    message: 'This request is no longer available.',
                                    success: false,
                                  );
                                } else {
                                  AppSnack.show(
                                    context,
                                    message: msg != null && msg.isNotEmpty
                                        ? msg
                                        : 'Request declined',
                                    success: true,
                                  );
                                }
                                Navigator.of(context).pop(_RequestSheetResult.declined);
                              },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Decline',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (!widget.canAccept || _processing)
                            ? null
                            : () async {
                                setState(() => _processing = true);
                                final result = await widget.onAccept();
                                if (!mounted) return;
                                final ok = result['success'] == true;
                                final statusCode = result['statusCode'] as int?;
                                final msg = (result['message'] as String?)?.trim();
                                if (!ok) {
                                  setState(() => _processing = false);
                                  AppSnack.show(
                                    context,
                                    message: statusCode == 409 || statusCode == 410
                                        ? 'This request is no longer available.'
                                        : (msg != null && msg.isNotEmpty
                                              ? msg
                                              : 'Failed to accept request. Try again.'),
                                    success: false,
                                  );
                                  if (statusCode == 409 || statusCode == 410) {
                                    Navigator.of(context).pop(_RequestSheetResult.declined);
                                  }
                                } else {
                                  Navigator.of(
                                    context,
                                  ).pop(_RequestSheetResult.accepted);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _fixerAcceptColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.canAccept
                                    ? 'Accept request'
                                    : 'Subscription required',
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                if (!widget.canAccept) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(_RequestSheetResult.purchase),
                    icon: const Icon(Icons.credit_score_rounded),
                    label: Text(
                      'Purchase plan',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.urbanist(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    const brand = Color(0xFFF1592A);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0x1AF1592A),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.urbanist(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      AppSnack.show(context, message: 'Unable to start call', success: false);
    }
  }
}
