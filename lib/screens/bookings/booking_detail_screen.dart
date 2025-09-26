import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/fixer_service.dart';
import '../../services/api_client.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _fixer = FixerService();
  final _api = ApiClient.I;
  bool _loading = true;
  Map<String, dynamic> _data = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as int?;
    if (id != null) {
      _load(id);
    }
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    try {
      // Prefer detailed request endpoint; fall back to fixer list + pick
      final detail = await _fixer.requestDetail(id);
      if (detail != null) {
        if (!mounted) return;
        setState(() {
          _data = detail;
        });
      } else {
        final res = await _api.get('/api/fixer/requests');
        if (res.statusCode == 200) {
          final root = jsonDecode(res.body);
          List? list;
          if (root is Map<String, dynamic>) {
            final data = root['data'];
            list = (data is Map<String, dynamic>) ? (data['data'] as List?) : (data as List?);
          } else if (root is List) {
            list = root;
          }
          final found = (list ?? []).cast<Map<String, dynamic>?>().firstWhere(
                (e) => (e?['id'] as int?) == id,
                orElse: () => null,
              );
          if (found != null && mounted) setState(() => _data = found);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = const Color(0xFFF1592A);
    final service = (_data['service'] ?? {}) as Map<String, dynamic>;
    final customer = (_data['customer'] ?? {}) as Map<String, dynamic>;
    final title = (service['name'] ?? service['title'] ?? 'Service').toString();
    final custName = (customer['name'] ?? ((customer['first_name'] ?? '').toString() + ' ' + (customer['last_name'] ?? '').toString())).toString().trim();
    final location = (_data['location'] ?? '').toString();
    final status = (_data['status'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        centerTitle: true,
        title: Text('Booking Details', style: GoogleFonts.urbanist(color: theme.colorScheme.onBackground, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 18)),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow(Icons.person, 'Customer', custName.isEmpty ? '—' : custName),
                      const SizedBox(height: 8),
                      _infoRow(Icons.place_outlined, 'Location', location.isEmpty ? '—' : location),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Actions', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: status == 'accepted' || status == 'completed'
                            ? null
                            : () async {
                                final id = _data['id'] as int?;
                                if (id == null) return;
                                final ok = await _fixer.acceptRequest(id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Request accepted' : 'Failed to accept')));
                                if (ok) Navigator.of(context).pop(true);
                              },
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFFF6EEEA), shape: BoxShape.circle),
          child: const Icon(Icons.info_outline, color: Color(0xFFF1592A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
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
      child: Text(status.isEmpty ? '—' : status, style: GoogleFonts.urbanist(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
