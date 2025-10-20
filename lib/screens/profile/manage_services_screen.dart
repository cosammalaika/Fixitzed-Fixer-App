import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/service_catalog.dart';
import '../../state/catalog_provider.dart';
import '../../state/fixer_profile_controller.dart';
import '../../widgets/offline_placeholder.dart';

class ManageServicesScreen extends ConsumerStatefulWidget {
  const ManageServicesScreen({super.key, this.initialServiceIds = const {}});

  final Set<int> initialServiceIds;

  @override
  ConsumerState<ManageServicesScreen> createState() =>
      _ManageServicesScreenState();
}

class _ManageServicesScreenState extends ConsumerState<ManageServicesScreen> {
  final Set<int> _selected = {};
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceIds.isNotEmpty) {
      _selected.addAll(widget.initialServiceIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(fixerProfileProvider);
    final catalogAsync = ref.watch(serviceCatalogProvider);
    final profile = profileAsync.valueOrNull;
    final catalog = catalogAsync.valueOrNull;

    if (!_seeded && profile != null) {
      _selected
        ..clear()
        ..addAll(profile.services.map((service) => service.id));
      _seeded = true;
    }

    final isLoading =
        (profile == null && profileAsync.isLoading) ||
        (catalog == null && catalogAsync.isLoading);

    final hasError = profileAsync.hasError || catalogAsync.hasError;
    final errorMessage =
        profileAsync.error?.toString() ?? catalogAsync.error?.toString();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        centerTitle: true,
        title: Text(
          'Services Offered',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading && catalog == null
            ? const Center(child: CircularProgressIndicator())
            : hasError && catalog == null
            ? _ErrorState(
                message: errorMessage ?? 'Unable to load services.',
                onRetry: _refresh,
              )
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      children: [
                        _HeaderBanner(total: _selected.length),
                        const SizedBox(height: 16),
                        if (catalog != null && catalog.isNotEmpty)
                          ...catalog.map(
                            (section) => _CategoryCard(
                              section: section,
                              isSelected: (int id) => _selected.contains(id),
                              onTap: _toggle,
                            ),
                          )
                        else
                          _EmptyCatalog(onRetry: _refresh),
                      ],
                    ),
                  ),
                  if (isLoading && catalog != null)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ElevatedButton(
          onPressed: _saving || _selected.isEmpty ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1592A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Save changes (${_selected.length})',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _seeded = false;
    ref.invalidate(serviceCatalogProvider);
    await Future.wait([
      ref.read(fixerProfileProvider.notifier).refresh(),
      ref.read(serviceCatalogProvider.future),
    ]);
  }

  void _toggle(int serviceId) {
    setState(() {
      if (_selected.contains(serviceId)) {
        _selected.remove(serviceId);
      } else {
        _selected.add(serviceId);
      }
    });
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    final success = await ref
        .read(fixerProfileProvider.notifier)
        .updateServices(_selected.toList());
    setState(() => _saving = false);
    if (!mounted) return;
    if (success) {
      _seeded = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services updated successfully.')),
      );
      Navigator.pop(context, true);
    } else {
      final err = ref.read(fixerProfileProvider).error;
      final message =
          err?.toString() ?? 'Could not update services. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1592A).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handyman_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your services',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'Choose at least one service to stay discoverable.'
                      : 'You have $total selected ${total == 1 ? 'service' : 'services'}.',
                  style: GoogleFonts.urbanist(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  final ServiceCatalogSection section;
  final bool Function(int serviceId) isSelected;
  final void Function(int serviceId) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        collapsedIconColor: Theme.of(context).hintColor,
        iconColor: const Color(0xFFF1592A),
        title: Text(
          section.name,
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        children: section.items.map((item) {
          final selected = isSelected(item.id);
          return CheckboxListTile(
            value: selected,
            onChanged: (_) => onTap(item.id),
            title: Text(
              item.name,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            subtitle: item.subcategoryName != null
                ? Text(
                    item.subcategoryName!,
                    style: GoogleFonts.urbanist(
                      color: Theme.of(context).hintColor,
                    ),
                  )
                : null,
            secondary: selected
                ? const Icon(Icons.check_circle, color: Color(0xFFF1592A))
                : const Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.black26,
                  ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return OfflinePlaceholder(
      title: 'Can’t load your services',
      message:
          'Reconnect to update the services you offer. We’ll save any changes once you’re back online.',
      onRetry: () {
        onRetry();
      },
      details: kDebugMode ? message : null,
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.handyman_outlined, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            'No services found',
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try refreshing to load the available catalog.',
            style: GoogleFonts.urbanist(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF1592A)),
            label: Text(
              'Reload catalog',
              style: GoogleFonts.urbanist(
                color: const Color(0xFFF1592A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
