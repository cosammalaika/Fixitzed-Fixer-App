import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../ui/snack.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notifications_service.dart';
import '../services/fixer_service.dart';
import '../models/service_request.dart';
import '../config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _RequestSheetResult { accepted, declined, purchase }

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient.I;
  final _notifications = NotificationsService();
  final _fixer = FixerService();

  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _startPolling();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshDashboard() {
    final future = _load();
    setState(() => _future = future);
    return future;
  }

  Future<_DashboardData> _load() async {
    // Parallel fetches of endpoints that exist in your routes
    // Fetch a small notifications payload to get unread_count meta
    final notifMetaF = _api.get('/api/notifications', query: {'limit': '1'});
    final reqF = _api.get('/api/fixer/requests');
    final walletF = _api.get('/api/fixer/wallet');
    final meF = _api.get('/api/me');

    final notifMeta = await notifMetaF;
    final reqRes = await reqF;
    final walletRes = await walletF;
    final meRes = await meF;

    // Parse requests (supports paginated and plain list)
    List<ServiceRequest> requests = [];
    try {
      if (reqRes.statusCode == 200) {
        final root = jsonDecode(reqRes.body);
        List<dynamic>? list;
        if (root is List) {
          list = root;
        } else if (root is Map) {
          final data = root['data'];
          if (data is List) list = data;
          if (data is Map && data['data'] is List) list = data['data'] as List;
          list ??=
              root.values.firstWhere((v) => v is List, orElse: () => const [])
                  as List;
        }
        requests = (list ?? const [])
            .whereType<Map>()
            .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}

    // Parse wallet coins left
    int coins = 0;
    double earnings = 0;
    try {
      if (walletRes.statusCode == 200) {
        final root = jsonDecode(walletRes.body);
        Map<String, dynamic> m;
        if (root is Map) {
          final d = root['data'];
          if (d is Map) {
            m = Map<String, dynamic>.from(d);
          } else {
            m = Map<String, dynamic>.from(root as Map);
          }
          coins = ((m['coin_balance'] ?? m['coins'] ?? 0) as num).toInt();
          final total = m['total_earnings'] ?? m['earnings_total'] ?? m['total'];
          if (total is num) earnings = total.toDouble();
          if (total is String) {
            earnings = double.tryParse(total) ?? earnings;
          }
        }
      }
    } catch (_) {}

    // Compute completed requests count for stat box
    final completedCount = requests
        .where((r) => r.status == 'completed')
        .length;

    // Parse unread notifications count
    int unread = 0;
    try {
      if (notifMeta.statusCode == 200) {
        final root = jsonDecode(notifMeta.body);
        if (root is Map && root['unread_count'] != null) {
          unread = (root['unread_count'] as num?)?.toInt() ?? 0;
        } else if (root is Map && root['data'] is Map) {
          final d = root['data'] as Map;
          if (d['unread_count'] is num)
            unread = (d['unread_count'] as num).toInt();
        }
      }
    } catch (_) {}

    // Parse current user for greeting
    String name = '';
    String? avatarUrl;
    String location = '';
    try {
      if (meRes.statusCode == 200) {
        final root = jsonDecode(meRes.body);
        Map<String, dynamic>? data;
        if (root is Map) {
          final raw = (root['user'] ?? root['data'] ?? root);
          if (raw is Map) data = Map<String, dynamic>.from(raw);
        }
        if (data != null) {
          final first = (data['first_name'] ?? data['firstName'] ?? '')
              .toString();
          final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
          final n = (data['name'] ?? '').toString();
          name = n.isNotEmpty ? n : ('$first $last').trim();
          avatarUrl = _resolveImage(
            (data['avatar_url'] ??
                    data['avatar'] ??
                    data['profile_photo_url'] ??
                    data['profile_photo_path'] ??
                    data['photo'])
                ?.toString(),
          );
          location = (data['address'] ?? data['location'] ?? '').toString();
        }
      }
    } catch (_) {}

    return _DashboardData(
      notificationsUnread: unread,
      requests: requests,
      coins: coins,
      totalEarnings: earnings,
      completedCount: completedCount,
      name: name,
      avatarUrl: avatarUrl,
      location: location,
    );
  }

  String? _resolveImage(String? raw) {
    if (raw == null) return null;
    final resolved = resolveMediaUrl(raw);
    return resolved.isEmpty ? null : resolved;
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
        if (raw is Map) customer = Map<String, dynamic>.from(raw as Map);
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
        onAccept: () => _fixer.acceptRequest(r.id),
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
    return Scaffold(
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? _DashboardData.empty();
          final activeCount = data.requests
              .where((r) => r.status != 'completed' && r.status != 'cancelled')
              .length;
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(
                    data: data,
                    onNotificationsTap: () async {
                      await Navigator.pushNamed(context, '/notifications');
                      if (mounted) _refreshDashboard();
                    },
                  ),
                  const SizedBox(height: 16),
                  _StatRow(
                    notifications: data.notificationsUnread,
                    requests: data.requests.length,
                    completed: data.completedCount,
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
                  if (data.requests.isEmpty)
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
                    ...data.requests
                        .take(5)
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RequestCard(
                              request: r,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/booking_detail',
                                arguments: r.id,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final int notificationsUnread;
  final List<ServiceRequest> requests;
  final int coins;
  final double totalEarnings;
  final int completedCount;
  final String name;
  final String? avatarUrl;
  final String location;
  _DashboardData({
    required this.notificationsUnread,
    required this.requests,
    required this.coins,
    required this.totalEarnings,
    required this.completedCount,
    required this.name,
    required this.avatarUrl,
    required this.location,
  });
  factory _DashboardData.empty() => _DashboardData(
    notificationsUnread: 0,
    requests: const [],
    coins: 0,
    totalEarnings: 0,
    completedCount: 0,
    name: '',
    avatarUrl: null,
    location: '',
  );
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
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
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

class _HeaderCard extends StatelessWidget {
  final _DashboardData data;
  final VoidCallback onNotificationsTap;
  const _HeaderCard({required this.data, required this.onNotificationsTap});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    final currency = NumberFormat.currency(symbol: 'K', decimalDigits: 2);
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
              _DashboardAvatar(url: data.avatarUrl, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name.isEmpty ? 'Hi there,' : 'Hi, ${data.name}',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.location.isEmpty
                          ? 'Ready to serve today?'
                          : data.location,
                      style: GoogleFonts.urbanist(color: Colors.white70),
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
                    if (data.notificationsUnread > 0)
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
                        data.coins > 0
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
                Text(
                  '${data.coins}',
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
              onTap: () => Navigator.of(context).pushNamed('/wallet/transactions', arguments: data.totalEarnings),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      child: const Icon(Icons.payments_outlined, color: Colors.white),
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
                            data.totalEarnings > 0
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
                    Text(
                      currency.format(data.totalEarnings),
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
    final validUrl =
        url.isNotEmpty && url.toLowerCase() != 'null' ? url : '';
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
    const brand = Color(0xFFF1592A);
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
  final Future<bool> Function() onAccept;

  const _NewRequestSheet({
    required this.request,
    required this.address,
    required this.phone,
    required this.coins,
    required this.canAccept,
    required this.onAccept,
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
                            : () => Navigator.of(
                                context,
                              ).pop(_RequestSheetResult.declined),
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
                                final ok = await widget.onAccept();
                                if (!mounted) return;
                                setState(() => _processing = false);
                                if (!ok) {
                                  AppSnack.show(
                                    context,
                                    message:
                                        'Failed to accept request. Try again.',
                                    success: false,
                                  );
                                  return;
                                }
                                Navigator.of(
                                  context,
                                ).pop(_RequestSheetResult.accepted);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _processing ? 'Accepting…' : 'Accept request',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
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
