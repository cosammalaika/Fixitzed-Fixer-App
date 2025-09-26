import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_client.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _api = ApiClient.I;
  bool _loading = true;
  List<Map<String, dynamic>> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/api/subscription/plans');
      if (res.statusCode == 200) {
        final root = jsonDecode(res.body);
        List list = [];
        if (root is Map<String, dynamic>) {
          final data = root['data'];
          if (data is List) list = data;
        } else if (root is List) {
          list = root;
        }
        if (mounted) {
          setState(() => _plans = list.cast<Map<String, dynamic>>());
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        centerTitle: true,
        title: Text(
          'Subscription Plans',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  ..._plans.map((p) => _planCard(context, p)).toList(),
                  if (_plans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('No plans available')),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _planCard(BuildContext context, Map<String, dynamic> p) {
    final name = (p['name'] ?? 'Plan').toString();
    final coins = (p['coins'] ?? 0).toString();
    final priceCents = (p['price_cents'] ?? 0) as int;
    final price = (priceCents / 100).toStringAsFixed(2);
    final days = (p['valid_days'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF6EEEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_score, color: Color(0xFFF1592A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$coins coins • $days days', style: GoogleFonts.urbanist(color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('K$price', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Buy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
