import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';

class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final _api = ApiClient.I;
  final _currency = NumberFormat.currency(symbol: 'K', decimalDigits: 2);
  final DateFormat _dateFmt = DateFormat('dd MMM, yyyy • HH:mm');

  String _selectedFilter = 'all';
  bool _loading = true;
  List<_WalletEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/api/fixer/earnings/history', query: {
      if (_selectedFilter != 'all') 'filter': _selectedFilter,
    });
    if (!mounted) return;

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      List data;
      if (body is Map && body['data'] is List) {
        data = body['data'] as List;
      } else if (body is List) {
        data = body;
      } else {
        data = [];
      }
      _entries = data
          .whereType<Map>()
          .map((e) => _WalletEntry.fromJson(e))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Earnings History',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _Filters(
            selected: _selectedFilter,
            onChanged: (value) {
              setState(() => _selectedFilter = value);
              _load();
            },
          ),
          if (total is num)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1592A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earned',
                      style: GoogleFonts.urbanist(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currency.format(total),
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _EmptyState(filter: _selectedFilter)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final amount = (entry.amount ?? 0).toDouble();
                          final positive = amount >= 0;
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x15000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        positive ? const Color(0x1AF1592A) : const Color(0x1AF54832),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                    color: positive ? const Color(0xFFF1592A) : const Color(0xFFF54832),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title ?? 'Service earnings',
                                        style: GoogleFonts.urbanist(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                  Text(
                                    _dateFmt.format(entry.createdAt),
                                    style: GoogleFonts.urbanist(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (entry.paymentMethod?.isNotEmpty == true)
                                        _InfoChip(
                                          icon: Icons.account_balance_wallet_outlined,
                                          label: entry.paymentMethod!,
                                        ),
                                      if (entry.transactionId?.isNotEmpty == true)
                                        _InfoChip(
                                          icon: Icons.tag_outlined,
                                          label: entry.transactionId!,
                                        ),
                                      if (entry.serviceName?.isNotEmpty == true)
                                        _InfoChip(
                                          icon: Icons.home_repair_service_rounded,
                                          label: entry.serviceName!,
                                        ),
                                      if (entry.scheduledAt != null)
                                        _InfoChip(
                                          icon: Icons.calendar_month_rounded,
                                          label: DateFormat('dd MMM').format(entry.scheduledAt!),
                                        ),
                                    ],
                                  ),
                                  if (entry.note?.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.note!,
                                          style: GoogleFonts.urbanist(fontSize: 13),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _currency.format(amount),
                                  style: GoogleFonts.urbanist(
                                    color: positive ? const Color(0xFFF1592A) : const Color(0xFFF54832),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: _entries.length,
                      ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _Filters({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = {
      'all': 'All time',
      '7d': 'Last 7 days',
      '30d': 'Last 30 days',
      '90d': 'Last 90 days',
      'year': 'This year',
    };
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final key = filters.keys.elementAt(index);
          final label = filters[key]!;
          final active = selected == key;
          return ChoiceChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => onChanged(key),
            selectedColor: const Color(0xFFF1592A),
            labelStyle: GoogleFonts.urbanist(
              color: active ? Colors.white : const Color(0xFF5B5B5B),
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: const Color(0xFFF3F5F7),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final copy = filter == 'all'
        ? 'No earnings recorded yet.'
        : 'No earnings found for the selected range.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 52, color: Color(0xFFC6CBD1)),
            const SizedBox(height: 16),
            Text(
              copy,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _labelForFilter => filter;
}

class _WalletEntry {
  final int id;
  final double? amount;
  final String? title;
  final String? note;
  final DateTime createdAt;
  final String? paymentMethod;
  final String? transactionId;
  final String? serviceName;
  final DateTime? scheduledAt;

  _WalletEntry({
    required this.id,
    this.amount,
    this.title,
    this.note,
    required this.createdAt,
    this.paymentMethod,
    this.transactionId,
    this.serviceName,
    this.scheduledAt,
  });

  factory _WalletEntry.fromJson(Map json) {
    final created = json['paid_at'] ?? json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String();
    return _WalletEntry(
      id: (json['id'] ?? 0) as int,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? ''),
      title: json['title']?.toString() ?? json['service_name']?.toString() ?? json['description']?.toString(),
      note: json['note']?.toString() ?? json['message']?.toString() ?? json['location']?.toString(),
      createdAt: DateTime.tryParse(created.toString()) ?? DateTime.now(),
      paymentMethod: json['payment_method']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      serviceName: json['service_name']?.toString(),
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? ''),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5B5B5B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5B5B5B),
            ),
          ),
        ],
      ),
    );
  }
}
