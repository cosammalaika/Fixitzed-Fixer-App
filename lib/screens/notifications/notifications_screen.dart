import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/notifications_service.dart';
import '../../models/notification_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationsService();
  bool _loading = true;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _svc.list();
    if (!mounted) return;
    setState(() {
      _items = list;
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

  Widget _tile(NotificationItem n) {
    final timeStr = DateFormat('h:mm a').format(n.createdAt);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF6EEEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFFF1592A),
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
                        n.title.isEmpty ? 'Notification' : n.title,
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.urbanist(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    color: Colors.black54,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = <NotificationItem>[];
    final yesterday = <NotificationItem>[];
    final earlier = <NotificationItem>[];
    for (final n in _items) {
      final d = n.createdAt;
      if (_isToday(d))
        today.add(n);
      else if (_isYesterday(d))
        yesterday.add(n);
      else
        earlier.add(n);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Notification',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
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
                                  if (ok) _load();
                                },
                          child: const Text(
                            'Mark All As Read',
                            style: TextStyle(color: Color(0xFFF1592A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...today.map(_tile),
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
                    ...yesterday.map(_tile),
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
                    ...earlier.map(_tile),
                  ],
                  if (today.isEmpty && yesterday.isEmpty && earlier.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No notifications',
                            style: GoogleFonts.urbanist(color: Colors.black54),
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
