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
        List? list;
        if (root is Map<String, dynamic>) {
          final data = root['data'];
          list = (data is Map<String, dynamic>)
              ? (data['data'] as List?)
              : (data as List?);
        } else if (root is List) {
          list = root;
        }
        if (list != null) {
          requests = list
              .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}

    // Parse wallet coins left
    int coins = 0;
    try {
      if (walletRes.statusCode == 200) {
        final root = jsonDecode(walletRes.body) as Map<String, dynamic>;
        final map = (root['data'] ?? root) as Map<String, dynamic>;
        coins = ((map['coin_balance'] ?? map['coins'] ?? 0) as num).toInt();
      }
    } catch (_) {}

    // Compute completed requests count for stat box
    final completedCount = requests.where((r) => r.status == 'completed').length;

    // Parse unread notifications count
    int unread = 0;
    try {
      if (notifMeta.statusCode == 200) {
        final root = jsonDecode(notifMeta.body);
        if (root is Map<String, dynamic>) {
          unread = (root['unread_count'] as num?)?.toInt() ?? 0;
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
        if (root is Map<String, dynamic>) {
          data = (root['user'] ?? root['data'] ?? root) as Map<String, dynamic>;
        }
        if (data != null) {
          final first = (data['first_name'] ?? '').toString();
          final last = (data['last_name'] ?? '').toString();
          final n = (data['name'] ?? '').toString();
          name = (n.isNotEmpty ? n : ('$first $last').trim());
          avatarUrl = (data['avatar_url'] ?? data['avatar'])?.toString();
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
      final list = await _fixer.requests(status: 'pending');
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
        final customer = detail['customer'] as Map<String, dynamic>?;
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('New Service Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.service.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Customer: ${r.customer.name}'),
              if (address != null) Text('Location: $address'),
              if (phone != null) Text('Phone: $phone'),
              const SizedBox(height: 12),
              Text('Coins left: $_coins'),
              if (!canAccept)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'You need an active subscription to accept requests.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Decline'),
            ),
            if (!canAccept)
              TextButton(
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
                child: const Text('Purchase Plan'),
              ),
            if (canAccept)
              ElevatedButton(
                onPressed: () async {
                  final ok = await _fixer.acceptRequest(r.id);
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  final snackBar = SnackBar(
                    content: Text(ok ? 'Request accepted' : 'Failed to accept'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  // refresh coins after accept (server may deduct)
                  final w = await _fixer.wallet();
                  setState(
                    () => _coins =
                        ((w['coin_balance'] ?? w['coins'] ?? 0) as num).toInt(),
                  );
                  setState(() => _future = _load());
                },
                child: const Text('Accept'),
              ),
          ],
        );
      },
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
