import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:fixitzed_fixer_app/services/api_client.dart';

class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final _api = ApiClient.I;
  final _currency = NumberFormat.currency(symbol: 'K', decimalDigits: 2);
  final DateFormat _dateFmt = DateFormat('dd MMM, yyyy • HH:mm');

  String _selectedFilter = 'all';
  String _searchTerm = '';
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  List<_WalletEntry> _allEntries = const [];
  List<_WalletEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/api/fixer/earnings/history');
    if (!mounted) return;

    List<_WalletEntry> entries = const [];
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
      entries = data
          .whereType<Map>()
          .map((e) => _WalletEntry.fromJson(e))
          .toList();
    }
    final filtered = _filterEntries(entries);
    setState(() {
      _allEntries = entries;
      _entries = filtered;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = ModalRoute.of(context)?.settings.arguments;
    final theme = Theme.of(context);
    final brand = const Color(0xFFF1592A);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        title: Text(
          'Earnings History',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _Filters(
            selected: _selectedFilter,
            onChanged: (value) {
              if (_selectedFilter == value) return;
              setState(() {
                _selectedFilter = value;
                _entries = _filterEntries(_allEntries);
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                setState(() {
                  _searchTerm = value.trim().toLowerCase();
                  _entries = _filterEntries(_allEntries);
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by service, transaction or location',
                prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.hintColor),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchTerm = '';
                            _entries = _filterEntries(_allEntries);
                          });
                        },
                      ),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.black12.withOpacity(0.05),
                  ),
                ),
              ),
            ),
          ),
          if (total is num)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF1592A), Color(0xFFFF8A4C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF1592A).withOpacity(0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Earned',
                            style: GoogleFonts.urbanist(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currency.format(total),
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 220),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 160),
                        _EmptyState(
                          filter: _selectedFilter,
                          searchTerm: _searchTerm,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final amount = (entry.amount ?? 0).toDouble();
                        final positive = amount >= 0;
                        final accent = positive
                            ? brand
                            : const Color(0xFFF54832);
                        final title = entry.title ?? entry.serviceName;
                        final statusLabel = positive
                            ? 'Payout received'
                            : 'Adjustment';
                        final gradientColors = positive
                            ? const [Color(0xFFF1592A), Color(0xFFFF8A4C)]
                            : const [Color(0xFFF54832), Color(0xFFFF7B6B)];
                        final locationLabel = _formatLocation(entry.note);

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showEntryDetails(entry),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      16,
                                      18,
                                      14,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 44,
                                          width: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.18,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            positive
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title ?? 'Service earnings',
                                                style: GoogleFonts.urbanist(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                statusLabel,
                                                style: GoogleFonts.urbanist(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _dateFmt.format(
                                                  entry.createdAt,
                                                ),
                                                style: GoogleFonts.urbanist(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _currency.format(amount),
                                          style: GoogleFonts.urbanist(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      14,
                                      18,
                                      18,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (entry
                                                    .paymentMethod
                                                    ?.isNotEmpty ==
                                                true)
                                              _InfoChip(
                                                icon: Icons
                                                    .account_balance_wallet_outlined,
                                                label: entry.paymentMethod!,
                                              ),
                                            if (entry
                                                    .transactionId
                                                    ?.isNotEmpty ==
                                                true)
                                              _InfoChip(
                                                icon: Icons.tag_outlined,
                                                label: entry.transactionId!,
                                              ),
                                            if (entry.serviceName?.isNotEmpty ==
                                                true)
                                              _InfoChip(
                                                icon: Icons
                                                    .home_repair_service_rounded,
                                                label: entry.serviceName!,
                                              ),
                                            if (entry.scheduledAt != null)
                                              _InfoChip(
                                                icon: Icons
                                                    .calendar_month_rounded,
                                                label: DateFormat(
                                                  'dd MMM',
                                                ).format(entry.scheduledAt!),
                                              ),
                                          ],
                                        ),
                                        if (locationLabel.isNotEmpty) ...[
                                          const SizedBox(height: 14),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F5F7),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.location_on_rounded,
                                                  color: accent,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    locationLabel,
                                                    style: GoogleFonts.urbanist(
                                                      fontSize: 13,
                                                      color: theme
                                                          .colorScheme
                                                          .onBackground,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _entries.length,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<_WalletEntry> _filterEntries(List<_WalletEntry> entries) {
    Iterable<_WalletEntry> filtered = entries;

    if (_selectedFilter != 'all') {
      final now = DateTime.now();
      DateTime? start;
      switch (_selectedFilter) {
        case '7d':
          start = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          start = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          start = now.subtract(const Duration(days: 90));
          break;
        case 'year':
          start = DateTime(now.year, 1, 1);
          break;
      }
      final cutoff = start;
      if (cutoff != null) {
        filtered = filtered.where((e) => !e.createdAt.isBefore(cutoff));
      }
    }

    if (_searchTerm.isNotEmpty) {
      final query = _searchTerm.toLowerCase();
      filtered = filtered.where((entry) {
        final haystack = [
          entry.title,
          entry.note,
          entry.transactionId,
          entry.serviceName,
          entry.paymentMethod,
        ];
        return haystack.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(query),
        );
      });
    }

    final list = filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _showEntryDetails(_WalletEntry entry) async {
    final amount = (entry.amount ?? 0).toDouble();
    final positive = amount >= 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return _TransactionDetailModal(
          entry: entry,
          amount: amount,
          positive: positive,
          currency: _currency,
          dateFmt: _dateFmt,
          bottomInset: bottomInset,
          formatLocation: _formatLocation,
          onCopy: _copyToClipboard,
        );
      },
    );
  }

  String _formatLocation(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$value"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> items, {double spacing = 12}) {
  if (items.isEmpty) return const [];
  final spaced = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    spaced.add(items[i]);
    if (i < items.length - 1) {
      spaced.add(SizedBox(height: spacing));
    }
  }
  return spaced;
}

class _TransactionDetailModal extends StatelessWidget {
  final _WalletEntry entry;
  final double amount;
  final bool positive;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final double bottomInset;
  final String Function(String?) formatLocation;
  final void Function(String) onCopy;

  const _TransactionDetailModal({
    required this.entry,
    required this.amount,
    required this.positive,
    required this.currency,
    required this.dateFmt,
    required this.bottomInset,
    required this.formatLocation,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = positive ? const Color(0xFFF1592A) : const Color(0xFFF54832);
    final gradient = positive
        ? const [Color(0xFFF1592A), Color(0xFFFF8A4C)]
        : const [Color(0xFFF54832), Color(0xFFFF7B6B)];
    final statusLabel = positive ? 'Payout received' : 'Adjustment';
    final serviceLabel =
        (entry.title?.isNotEmpty == true ? entry.title : entry.serviceName)
            ?.toString()
            .trim();
    final locationLabel = formatLocation(entry.note);

    final chips = <Widget>[];
    if (entry.paymentMethod?.isNotEmpty == true) {
      chips.add(
        _InfoChip(
          icon: Icons.account_balance_wallet_outlined,
          label: entry.paymentMethod!,
        ),
      );
    }
    if (entry.transactionId?.isNotEmpty == true) {
      chips.add(
        _InfoChip(icon: Icons.tag_outlined, label: entry.transactionId!),
      );
    }
    if (entry.serviceName?.isNotEmpty == true) {
      chips.add(
        _InfoChip(
          icon: Icons.home_repair_service_rounded,
          label: entry.serviceName!,
        ),
      );
    }
    if (entry.scheduledAt != null) {
      chips.add(
        _InfoChip(
          icon: Icons.calendar_month_rounded,
          label: DateFormat('dd MMM yyyy').format(entry.scheduledAt!),
        ),
      );
    }

    final infoTiles = <Widget>[];
    if (entry.transactionId?.isNotEmpty == true) {
      infoTiles.add(
        _DetailTile(
          icon: Icons.tag_outlined,
          label: 'Transaction ID',
          value: entry.transactionId!,
          trailing: IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy ID',
            onPressed: () => onCopy(entry.transactionId!),
          ),
        ),
      );
    }
    if (entry.paymentMethod?.isNotEmpty == true) {
      infoTiles.add(
        _DetailTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Payment method',
          value: entry.paymentMethod!,
        ),
      );
    }
    if (serviceLabel != null && serviceLabel.isNotEmpty) {
      infoTiles.add(
        _DetailTile(
          icon: Icons.home_repair_service_rounded,
          label: 'Service',
          value: serviceLabel,
        ),
      );
    }
    infoTiles.add(
      _DetailTile(
        icon: Icons.schedule_rounded,
        label: 'Recorded on',
        value: dateFmt.format(entry.createdAt),
      ),
    );
    if (entry.scheduledAt != null) {
      infoTiles.add(
        _DetailTile(
          icon: Icons.event_available_rounded,
          label: 'Scheduled for',
          value: DateFormat(
            'EEE, dd MMM yyyy – HH:mm',
          ).format(entry.scheduledAt!),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transaction details',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  positive
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currency.format(amount),
                                      style: GoogleFonts.urbanist(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (serviceLabel != null &&
                                        serviceLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        serviceLabel,
                                        style: GoogleFonts.urbanist(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      statusLabel,
                                      style: GoogleFonts.urbanist(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dateFmt.format(entry.createdAt),
                                      style: GoogleFonts.urbanist(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Wrap(spacing: 10, runSpacing: 10, children: chips),
                        ],
                        if (infoTiles.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          ..._withSpacing(infoTiles, spacing: 12),
                        ],
                        if (locationLabel.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Location',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F5F7),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    locationLabel,
                                    style: GoogleFonts.urbanist(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (entry.transactionId?.isNotEmpty == true) ...[
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => onCopy(entry.transactionId!),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(
                                  color: accent.withOpacity(0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy transaction ID'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    const brand = Color(0xFFF1592A);
    final filters = {
      'all': 'All time',
      '7d': 'Last 7 days',
      '30d': 'Last 30 days',
      '90d': 'Last 90 days',
      'year': 'This year',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black12.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.entries.map((entry) {
              final active = selected == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active ? brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.value,
                      style: GoogleFonts.urbanist(
                        color: active ? Colors.white : const Color(0xFF5B5B5B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final String searchTerm;
  const _EmptyState({required this.filter, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    String copy;
    if (searchTerm.isNotEmpty) {
      copy = 'No earnings match "$searchTerm".';
    } else if (filter == 'all') {
      copy = 'No earnings recorded yet.';
    } else {
      copy = 'No earnings found for the selected range.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 52,
              color: Color(0xFFC6CBD1),
            ),
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
    final created =
        json['paid_at'] ??
        json['created_at'] ??
        json['createdAt'] ??
        DateTime.now().toIso8601String();
    return _WalletEntry(
      id: (json['id'] ?? 0) as int,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? ''),
      title:
          json['title']?.toString() ??
          json['service_name']?.toString() ??
          json['description']?.toString(),
      note:
          json['note']?.toString() ??
          json['message']?.toString() ??
          json['location']?.toString(),
      createdAt: DateTime.tryParse(created.toString()) ?? DateTime.now(),
      paymentMethod: json['payment_method']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      serviceName: json['service_name']?.toString(),
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? ''),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5B5B5B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF5B5B5B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            SizedBox(height: 36, child: trailing),
          ],
        ],
      ),
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
