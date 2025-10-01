import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/fixer_service.dart';
import '../../models/service_request.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _fixer = FixerService();
  bool _loading = true;
  List<ServiceRequest> _pending = [];
  List<ServiceRequest> _accepted = [];
  List<ServiceRequest> _completed = [];
  List<ServiceRequest> _declined = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _fixer.requests(status: 'pending');
      final a = await _fixer.requests(status: 'accepted');
      final c = await _fixer.requests(status: 'completed');
      final d = await _fixer.requests(status: 'cancelled');
      if (!mounted) return;
      setState(() {
        _pending = p;
        _accepted = a;
        _completed = c;
        _declined = d;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        centerTitle: true,
        title: Text('Bookings', style: GoogleFonts.urbanist(color: theme.colorScheme.onBackground, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFF1592A),
          labelColor: theme.colorScheme.onBackground,
          labelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.urbanist(),
          tabs: const [
            Tab(text: 'New'),
            Tab(text: 'Accepted'),
            Tab(text: 'Completed'),
            Tab(text: 'Declined'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _list(_pending),
                    _list(_accepted),
                    _list(_completed),
                    _list(_declined),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _list(List<ServiceRequest> items) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.event_busy_rounded, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No bookings yet',
              style: GoogleFonts.urbanist(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/booking_detail', arguments: r.id),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFF6EEEA), shape: BoxShape.circle),
                  child: const Icon(Icons.handyman_rounded, color: Color(0xFFF1592A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.service.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          _statusChip(r.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.customer.name}${r.location != null ? ' • ${r.location}' : ''}',
                        style: GoogleFonts.urbanist(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'pending':
        bg = const Color(0xFFF6EEEA);
        fg = const Color(0xFFF1592A);
        break;
      case 'accepted':
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green;
        break;
      case 'completed':
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue;
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
