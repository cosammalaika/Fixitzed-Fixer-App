import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:google_fonts/google_fonts.dart';
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
          list ??= root.values.firstWhere(
            (v) => v is List,
            orElse: () => const [],
          ) as List;
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
          if (d['unread_count'] is num) unread = (d['unread_count'] as num).toInt();
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
          final first = (data['first_name'] ?? data['firstName'] ?? '').toString();
          final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
          final n = (data['name'] ?? '').toString();
          name = n.isNotEmpty ? n : ('$first $last').trim();
          avatarUrl = (data['avatar_url'] ?? data['avatar'] ?? data['profile_photo_url'])?.toString();
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
            (customer?['phone'] ?? customer?['mobile'] ?? customer?['phone_number'])
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
                  style: TextStyle(fontWeight: FontWeight.w800),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Request accepted' : 'Failed to accept',
                            ),
                          ),
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
          final d = snap.data ?? _DashboardData.empty();
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header row (greeting + avatar + notifications)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            (d.avatarUrl != null && d.avatarUrl!.isNotEmpty)
                            ? (d.avatarUrl!.startsWith('http')
                                  ? NetworkImage(d.avatarUrl!) as ImageProvider
                                  : AssetImage(d.avatarUrl!))
                            : const AssetImage('assets/images/logo-sm.png'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${d.name.isEmpty ? 'there' : d.name}',
                              style: GoogleFonts.urbanist(fontSize: 16),
                            ),
                            Text(
                              d.location.isEmpty ? 'Welcome' : d.location,
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/notifications'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (Theme.of(context).brightness ==
                                      Brightness.light)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                            ),
                          ),
                          if (d.notificationsUnread > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BalanceCard(coins: d.coins),
                  const SizedBox(height: 12),
                  _StatRow(
                    notifications: d.notificationsUnread,
                    requests: d.requests.length,
                    completed: d.completedCount,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text('Active Bookings'),
                      subtitle: Text(
                        '${d.requests.where((r) => r.status != 'completed' && r.status != 'cancelled').length} active',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/bookings'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Recent Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...d.requests
                      .take(5)
                      .map(
                        (r) => Card(
                          child: ListTile(
                            title: Text(r.service.name),
                            subtitle: Text(
                              '${r.customer.name} • ${r.status}${r.location != null ? ' • ${r.location}' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/booking_detail',
                              arguments: r.id,
                            ),
                          ),
                        ),
                      ),
                  if (d.requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No requests yet',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 32),
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

class _BalanceCard extends StatelessWidget {
  final int coins;
  const _BalanceCard({required this.coins});
  @override
  Widget build(BuildContext context) {
    final orange = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: orange,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Subscription Coins Left',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
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
