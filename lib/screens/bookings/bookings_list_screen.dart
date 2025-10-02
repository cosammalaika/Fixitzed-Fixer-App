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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black12.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: const Color(0xFFF1592A),
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: theme.hintColor,
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
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Gradient intro banner for visual parity with popups
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF1592A).withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.event_available_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manage your bookings', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Track new, accepted and completed jobs at a glance.', style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.9))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
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
                ],
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
            border: Border.all(color: const Color(0x1AF1592A)),
          ),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/booking_detail', arguments: r.id),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0x1AF1592A), shape: BoxShape.circle),
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
                            child: Text(r.service.name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
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
      case 'awaiting_payment':
        bg = const Color(0x1AF1592A);
        fg = const Color(0xFFF1592A);
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
      child: Text(
        status == 'awaiting_payment' ? 'Awaiting Payment' : status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
