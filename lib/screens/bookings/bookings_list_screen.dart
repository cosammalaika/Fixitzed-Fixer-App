import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fixitzed_fixer_app/models/service_request.dart';
import 'package:fixitzed_fixer_app/state/bookings_controller.dart';
import 'package:fixitzed_fixer_app/state/fixer_profile_controller.dart';
import 'package:fixitzed_fixer_app/widgets/offline_placeholder.dart';
import 'package:fixitzed_fixer_app/widgets/skeletons.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final bookingsAsync = ref.watch(fixerBookingsProvider);
        final current = bookingsAsync.valueOrNull;
        final isRefreshing = bookingsAsync.isLoading && current != null;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
            centerTitle: true,
            title: Text(
              'Bookings',
              style: GoogleFonts.urbanist(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                    labelStyle: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                    ),
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
            child: bookingsAsync.when(
              loading: () => current == null
                  ? const FixerBookingsSkeleton()
                  : _buildBody(context, ref, current, isRefreshing: true),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () => ref
                    .read(fixerBookingsProvider.notifier)
                    .refresh(silent: false),
              ),
              data: (state) =>
                  _buildBody(context, ref, state, isRefreshing: isRefreshing),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FixerBookingsState state, {
    required bool isRefreshing,
  }) {
    return Stack(
      children: [
        Column(
          children: [
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage your bookings',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track new, accepted and completed jobs at a glance.',
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(fixerBookingsProvider.notifier).refresh(),
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _list(state.pending, ref),
                    _list(state.accepted, ref),
                    _list(state.completed, ref),
                    _list(state.declined, ref),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _list(List<ServiceRequest> items, WidgetRef ref) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Theme.of(context).hintColor,
          ),
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
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0x1AF1592A)),
          ),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.pushNamed<bool>(
                context,
                '/booking_detail',
                arguments: r.id,
              );
              if (!mounted) return;
              if (result == true) {
                await ref
                    .read(fixerBookingsProvider.notifier)
                    .refresh(silent: true);
                ref.invalidate(fixerProfileProvider);
              }
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0x1AF1592A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
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
                              r.service.name,
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _statusChip(r.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.customer.name}${r.location != null ? ' • ${r.location}' : ''}',
                        style: GoogleFonts.urbanist(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      if (r.declinedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Declined: ${DateFormat('d MMM • HH:mm').format(r.declinedAt!.toLocal())}',
                            style: GoogleFonts.urbanist(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        )
                      else if (r.scheduledAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Scheduled: ${DateFormat('d MMM • HH:mm').format(r.scheduledAt!.toLocal())}',
                            style: GoogleFonts.urbanist(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
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
      case 'declined':
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'awaiting_payment'
            ? 'Awaiting Payment'
            : status == 'declined'
            ? 'Declined'
            : status.isNotEmpty
            ? '${status[0].toUpperCase()}${status.substring(1)}'
            : status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OfflinePlaceholder(
      title: 'Couldn’t refresh bookings',
      message:
          'Pull to refresh or check your connection to see the latest bookings.',
      onRetry: onRetry,
      details: kDebugMode ? message : null,
    );
  }
}
