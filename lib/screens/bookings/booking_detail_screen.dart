import 'dart:convert';
import 'package:fixitzed_fixer_app/ui/snack.dart';
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

  Future<double?> _promptAmount(BuildContext context) async {
    final ctrl = TextEditingController();
    final val = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Service Charge'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'e.g., K250.00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Send Bill'),
          ),
        ],
      ),
    );
    return val;
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
            list = (data is Map<String, dynamic>)
                ? (data['data'] as List?)
                : (data as List?);
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
    final service = _mapOf(_data['service']);
    final customer = _mapOf(_data['customer']);
    final title = (service['name'] ?? service['title'] ?? 'Service').toString();
    final custName =
        (customer['name'] ??
                ((customer['first_name'] ?? '').toString() +
                    ' ' +
                    (customer['last_name'] ?? '').toString()))
            .toString()
            .trim();
    final location = (_data['location'] ?? '').toString();
    final status = (_data['status'] ?? '').toString();
    final contactVisible = (_data['customer_contact_visible'] == true);
    final contactRaw = customer['contact_number'] ?? customer['phone'] ?? customer['mobile'];
    final contact = contactVisible && contactRaw != null
        ? contactRaw.toString()
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        centerTitle: true,
        title: Text(
          'Booking Details',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
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
                                fontSize: 18,
                              ),
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        Icons.person,
                        'Customer',
                        custName.isEmpty ? '—' : custName,
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.phone,
                        'Contact',
                        contactVisible
                            ? (contact == null || contact.trim().isEmpty
                                ? 'Customer contact not provided'
                                : contact)
                            : 'Visible after you accept the request',
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.place_outlined,
                        'Location',
                        location.isEmpty ? '—' : location,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Actions',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (status == 'awaiting_payment')
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0x1AF1592A), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Awaiting customer payment', style: TextStyle(color: Color(0xFFF1592A), fontWeight: FontWeight.w700)),
                  ),
                Column(
                  children: [
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
                            onPressed: status == 'accepted' || status == 'completed' || status == 'awaiting_payment'
                                ? null
                                : () async {
                                    final id = _data['id'] as int?;
                                    if (id == null) return;
                                    final ok = await _fixer.acceptRequest(id);
                                    if (!mounted) return;
                                    AppSnack.show(
                                      context,
                                      message: ok
                                          ? 'Request accepted'
                                          : 'Failed to accept',
                                      success: ok,
                                    );
                                    if (ok) Navigator.of(context).pop(true);
                                  },
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: status == 'completed'
                                ? null
                                : () async {
                                    final id = _data['id'] as int?;
                                    if (id == null) return;
                                    final ok = await _fixer.updateStatus(
                                      id,
                                      'cancelled',
                                    );
                                    if (!mounted) return;
                                    AppSnack.show(
                                      context,
                                      message: ok
                                          ? 'Request cancelled'
                                          : 'Failed to cancel',
                                      success: ok,
                                    );
                                    if (ok) Navigator.of(context).pop(true);
                                  },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: status == 'accepted'
                                ? () async {
                                    final id = _data['id'] as int?;
                                    if (id == null) return;
                                    final amount = await _promptAmount(context);
                                    if (amount == null) return;
                                    final created = await _fixer.createBill(
                                      id,
                                      amount,
                                    );
                                    if (!mounted) return;
                                    if (!created) {
                                      AppSnack.show(
                                        context,
                                        message: 'Failed to create bill',
                                        success: false,
                                      );
                                      return;
                                    }
                                    if (!mounted) return;
                                    AppSnack.show(
                                      context,
                                      message: 'Bill sent to customer',
                                      success: true,
                                    );
                                    Navigator.of(context).pop(true);
                                  }
                                : null,
                            child: const Text('Send Bill'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFF6EEEA),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline, color: Color(0xFFF1592A)),
        ),
        const SizedBox(width: 10),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
              ),
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
    String format(String value) {
      if (value.isEmpty) return '—';
      return value
          .split('_')
          .map((part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        format(status),
        style: GoogleFonts.urbanist(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
