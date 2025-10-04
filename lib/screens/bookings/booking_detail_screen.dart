import 'dart:convert';

import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/ui/snack.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/local_notification_service.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _api = ApiClient.I;
  final _fixer = FixerService();
  bool _loading = true;
  Map<String, dynamic>? _detail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as int?;
    if (id != null && _loading) {
      _load(id);
    }
  }

  Future<void> _load(int id) async {
    final detail = await _fetchDetail(id);
    if (!mounted) return;
    if (detail == null) {
      AppSnack.show(context, message: 'Unable to load booking details', success: false);
      setState(() {
        _loading = false;
        _detail = null;
      });
      return;
    }
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _fetchDetail(int id) async {
    try {
      final detail = await _fixer.requestDetail(id);
      if (detail != null) return detail;

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
        return (list ?? []).whereType<Map<String, dynamic>>().firstWhere(
          (row) => (row['id'] as int?) == id,
          orElse: () => <String, dynamic>{},
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        title: Text(
          'Booking Detail',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_detail == null
              ? Center(
                  child: Text(
                    'Unable to load booking details',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                )
              : _FixerBookingSheet(
                  detail: _detail!,
                  fixerService: _fixer,
                  showHandle: false,
                )),
    );
  }
}

class _FixerBookingSheet extends StatefulWidget {
  final Map<String, dynamic> detail;
  final FixerService fixerService;
  final bool showHandle;

  const _FixerBookingSheet({required this.detail, required this.fixerService, this.showHandle = true});

  @override
  State<_FixerBookingSheet> createState() => _FixerBookingSheetState();
}

class _FixerBookingSheetState extends State<_FixerBookingSheet> {
  bool _processing = false;
  bool _snoozing = false;

  Map<String, dynamic> get _data => widget.detail;

  int get _requestId => (_data['id'] as num).toInt();

  String _bookingCode() {
    final ref = _data['reference'] ?? _data['code'] ?? _data['booking_code'];
    final result = ref?.toString().trim();
    if (result == null || result.isEmpty || result == 'null') {
      return _requestId.toString();
    }
    return result;
  }

  DateTime? _scheduledAt() {
    final raw = _data['scheduled_at'] ?? _data['scheduledAt'] ?? _data['schedule'];
    return _parseDate(raw);
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed.toLocal();
    for (final pattern in const [
      'yyyy-MM-dd HH:mm:ss',
      "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
      "yyyy-MM-dd'T'HH:mm:ssZ",
      'yyyy-MM-dd HH:mm',
    ]) {
      try {
        return DateFormat(pattern).parse(text, true).toLocal();
      } catch (_) {}
    }
    return null;
  }

  String? _formatDateTime(dynamic raw) {
    final dt = _parseDate(raw);
    if (dt == null) return null;
    return DateFormat('d MMM yyyy • HH:mm').format(dt);
  }

  String _status() => (_data['status'] ?? '').toString();

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<void> _setProcessing(bool value) async {
    if (!mounted) return;
    setState(() => _processing = value);
  }

  Future<void> _acceptRequest() async {
    await _setProcessing(true);
    final ok = await widget.fixerService.acceptRequest(_requestId);
    await _setProcessing(false);
    if (!mounted) return;
    AppSnack.show(
      context,
      message: ok ? 'Request accepted' : 'Failed to accept request',
      success: ok,
    );
    if (ok) {
      LocalNotificationService.instance.notifyJobUpdate(
        bookingCode: _bookingCode(),
        status: 'accepted',
        scheduledAt: _scheduledAt(),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _cancelRequest() async {
    await _setProcessing(true);
    final result = await widget.fixerService.declineRequest(_requestId);
    await _setProcessing(false);
    if (!mounted) return;
    final ok = result['success'] == true;
    final msg = (result['message'] as String?)?.trim();
    AppSnack.show(
      context,
      message: ok
          ? (msg != null && msg.isNotEmpty ? msg : 'Request declined')
          : (msg != null && msg.isNotEmpty ? msg : 'Failed to decline request'),
      success: ok,
    );
    if (ok) {
      LocalNotificationService.instance.notifyJobUpdate(
        bookingCode: _bookingCode(),
        status: 'declined',
        scheduledAt: _scheduledAt(),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _snoozeRequest() async {
    setState(() => _snoozing = true);
    final ok = await widget.fixerService.snoozeRequest(_requestId);
    setState(() => _snoozing = false);
    if (!mounted) return;
    AppSnack.show(
      context,
      message: ok ? 'We will remind you again in an hour.' : 'Unable to snooze this request.',
      success: ok,
    );
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _sendBill() async {
    final amount = await _promptAmount();
    if (amount == null) return;
    await _setProcessing(true);
    final ok = await widget.fixerService.createBill(_requestId, amount);
    await _setProcessing(false);
    if (!mounted) return;
    AppSnack.show(
      context,
      message: ok ? 'Bill sent to customer' : 'Failed to create bill',
      success: ok,
    );
    if (ok) {
      LocalNotificationService.instance.notifyJobUpdate(
        bookingCode: _bookingCode(),
        status: 'awaiting payment',
        scheduledAt: _scheduledAt(),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<double?> _promptAmount() async {
    final controller = TextEditingController();
    bool submitting = false;

    final theme = Theme.of(context);
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.4),
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFF8F3), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF1592A).withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.attach_money_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enter service charge',
                                      style: GoogleFonts.urbanist(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Send the customer a clear, itemised bill for the work you have completed.',
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
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Amount (ZMW)',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF3F5F7),
                            hintText: 'e.g., 250.00',
                            prefixIcon: const Icon(
                              Icons.currency_exchange_rounded,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.of(ctx).pop(),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: submitting
                                    ? null
                                    : () {
                                        final value = double.tryParse(
                                          controller.text.trim(),
                                        );
                                        if (value == null || value <= 0) {
                                          AppSnack.show(
                                            ctx,
                                            message: 'Enter a valid amount',
                                            success: false,
                                          );
                                          return;
                                        }
                                        setLocal(() => submitting = true);
                                        Navigator.of(ctx).pop(value);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1592A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  submitting ? 'Sending…' : 'Send bill',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _callCustomer(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      AppSnack.show(context, message: 'Unable to start call', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    final service = _mapOf(_data['service']);
    final customer = _mapOf(_data['customer']);
    final title = (service['name'] ?? service['title'] ?? 'Service').toString();
    final scheduled = _formatDateTime(
      _data['scheduled_at'] ?? _data['scheduledAt'] ?? _data['schedule'],
    );
    final location = (_data['location'] ?? '').toString();
    final status = _status();
    final contactVisible = (_data['customer_contact_visible'] == true);
    final contactRaw =
        customer['contact_number'] ?? customer['phone'] ?? customer['mobile'];
    final contact = contactVisible && contactRaw != null
        ? contactRaw.toString()
        : null;
    final custName =
        (customer['name'] ??
                ((customer['first_name'] ?? '').toString() +
                    ' ' +
                    (customer['last_name'] ?? '').toString()))
            .toString()
            .trim();

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
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showHandle) ...[
                    Container(
                      width: 52,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [brand, const Color(0xFFFFA26C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: brand.withOpacity(0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.engineering_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                    ),
                                  ),
                                  if (scheduled != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        scheduled,
                                        style: GoogleFonts.urbanist(
                                          color: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _highlightCard(
                                icon: Icons.person_rounded,
                                label: 'Customer',
                                value: custName.isEmpty ? '—' : custName,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _highlightCard(
                                icon: Icons.payments_rounded,
                                label: 'Status',
                                value: _formatStatus(status),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _infoSection(
                    title: 'Booking details',
                    children: [
                      _infoTile(
                        Icons.place_rounded,
                        'Location',
                        location.isEmpty ? '—' : location,
                      ),
                      _infoTile(
                        Icons.phone_rounded,
                        'Contact',
                        contactVisible
                            ? (contact == null || contact.trim().isEmpty
                                  ? 'Customer contact not provided'
                                  : contact)
                            : 'Visible after you accept the request',
                        trailing:
                            contactVisible &&
                                contact != null &&
                                contact.trim().isNotEmpty
                            ? TextButton.icon(
                                onPressed: () => _callCustomer(contact),
                                icon: const Icon(Icons.call_rounded),
                                label: const Text('Call'),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _actionSection(status, brand),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlightCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFF1592A)),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _actionSection(String status, Color brand) {
    final lower = status.toLowerCase();
    final canAccept = lower == 'pending';
    final canSendBill = lower == 'accepted';
    final canDecline = lower != 'completed';
    final canSnooze = lower == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _processing || !canAccept ? null : _acceptRequest,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            _processing && canAccept ? 'Processing…' : 'Accept booking',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _processing || !canSendBill ? null : _sendBill,
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text(_processing && canSendBill ? 'Processing…' : 'Send bill'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _processing || _snoozing || !canSnooze ? null : _snoozeRequest,
          icon: const Icon(Icons.schedule_rounded),
          label: Text(_snoozing ? 'Snoozing…' : 'Accept later'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _processing || !canDecline ? null : _cancelRequest,
          icon: const Icon(Icons.cancel_outlined),
          label: Text(
            _processing && canDecline ? 'Processing…' : 'Decline request',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    switch (lower) {
      case 'pending':
        bg = Colors.white.withOpacity(0.18);
        fg = Colors.white;
        break;
      case 'accepted':
        bg = const Color(0xFF2E7D32).withOpacity(0.2);
        fg = Colors.white;
        break;
      case 'awaiting_payment':
        bg = Colors.white.withOpacity(0.2);
        fg = Colors.white;
        break;
      case 'completed':
        bg = Colors.white.withOpacity(0.2);
        fg = Colors.white;
        break;
      default:
        bg = Colors.white.withOpacity(0.15);
        fg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        _formatStatus(status),
        style: GoogleFonts.urbanist(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatStatus(String value) {
    if (value.isEmpty) return 'Pending';
    return value
        .split('_')
        .map(
          (part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }
}
