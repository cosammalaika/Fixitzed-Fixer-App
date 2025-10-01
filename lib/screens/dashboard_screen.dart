import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../ui/snack.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notifications_service.dart';
import '../services/fixer_service.dart';
import '../models/service_request.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

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
      completedCount: completedCount,
      name: name,
      avatarUrl: avatarUrl,
      location: location,
    );
  }

  String? _resolveImage(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    var origin = _api.baseUrl;
    if (origin.endsWith('/api')) {
      origin = origin.substring(0, origin.length - 4);
    }
    final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$origin/$path';
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
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final canAccept = _coins > 0;
        final brand = Theme.of(context).primaryColor;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EEEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_rounded, color: brand),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'New Service Request',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.service.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              _infoRow(
                icon: Icons.person_outline,
                label: 'Customer',
                value: r.customer.name,
              ),
              if (address != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: address!,
                ),
              ],
              if (phone != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.call_outlined,
                  label: 'Phone',
                  value: phone!,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF1592A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Available Coins: $_coins',
                      style: TextStyle(
                        color: brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!canAccept) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You need an active subscription to accept requests.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!canAccept)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushNamed(context, '/subscriptions').then((
                          _,
                        ) async {
                          final w = await _fixer.wallet();
                          setState(
                            () => _coins =
                                ((w['coin_balance'] ?? w['coins'] ?? 0) as num)
                                    .toInt(),
                          );
                        });
                      },
                      icon: const Icon(Icons.credit_score_rounded),
                      label: const Text('Purchase Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (canAccept)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _fixer.acceptRequest(r.id);
                        if (!mounted) return;
                        Navigator.of(ctx).pop();
                        AppSnack.show(
                          context,
                          message: ok ? 'Request accepted' : 'Failed to accept',
                          success: ok,
                        );
                        final w = await _fixer.wallet();
                        setState(
                          () => _coins =
                              ((w['coin_balance'] ?? w['coins'] ?? 0) as num)
                                  .toInt(),
                        );
                        setState(() => _future = _load());
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final brand = Theme.of(context).primaryColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFF6EEEA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: brand, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
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
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(
                    data: data,
                    onNotificationsTap: () =>
                        Navigator.pushNamed(context, '/notifications'),
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
  final int completedCount;
  final String name;
  final String? avatarUrl;
  final String location;
  _DashboardData({
    required this.notificationsUnread,
    required this.requests,
    required this.coins,
    required this.completedCount,
    required this.name,
    required this.avatarUrl,
    required this.location,
  });
  factory _DashboardData.empty() => _DashboardData(
    notificationsUnread: 0,
    requests: const [],
    coins: 0,
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
    final avatarProvider =
        (data.avatarUrl != null && data.avatarUrl!.isNotEmpty)
        ? NetworkImage(data.avatarUrl!) as ImageProvider
        : const AssetImage('assets/images/logo-sm.png');

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
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: avatarProvider,
                ),
              ),
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
        ],
      ),
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
        ? DateFormat('d MMM, h:mm a').format(request.scheduledAt!.toLocal())
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
