import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/report_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> user = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.I.get('/api/me');
      if (res.statusCode == 200) {
        final root = jsonDecode(res.body);
        if (root is Map<String, dynamic>) {
          user = (root['user'] ?? root['data'] ?? {}) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _resolveImage(String? raw) {
          if (raw == null) return '';
          final trimmed = raw.trim();
          if (trimmed.isEmpty) return '';
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            return trimmed;
          }
          var origin = ApiClient.I.baseUrl;
          if (origin.endsWith('/api')) origin = origin.substring(0, origin.length - 4);
          final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
          return path.startsWith('storage/') ? '$origin/$path' : '$origin/storage/$path';
        }

  Widget _menuItem(IconData icon, String label, {VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8EEE8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AF1592A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor ?? const Color(0xFFF1592A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportSheet({required String type}) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool submitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF8F3), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
              child: StatefulBuilder(builder: (ctx, setLocal) {
                InputDecoration deco(String label, {String? hint, IconData? icon}) => InputDecoration(
                      labelText: label,
                      hintText: hint,
                      prefixIcon: icon != null ? Icon(icon) : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F5F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF1592A), Color(0xFFFFA26C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: const Color(0xFFF1592A).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 12))],
                      ),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.flag_outlined, color: Colors.white)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Report ${type == 'user' ? 'a User' : 'an Issue'}', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('Share details so we can act.', style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.9))),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: subjectCtrl, decoration: deco('Subject', hint: 'Short title', icon: Icons.subject_rounded)),
                    const SizedBox(height: 10),
                    TextField(controller: messageCtrl, maxLines: 5, decoration: deco('Message', hint: 'Describe the issue', icon: Icons.message_rounded)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                setLocal(() => submitting = true);
                                final ok = await ReportService().submit(
                                  type: type,
                                  subject: subjectCtrl.text.trim(),
                                  message: messageCtrl.text.trim(),
                                );
                                if (!mounted) return;
                                setLocal(() => submitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Report submitted' : 'Failed to submit report')));
                                if (ok) Navigator.of(ctx).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1592A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(submitting ? 'Submitting…' : 'Submit'),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = (user['first_name'] ?? '').toString();
    final last = (user['last_name'] ?? '').toString();
    final name = ((user['name'] ?? '') as String?)?.isNotEmpty == true ? user['name'] as String : ('$first $last').trim();
    final avatar = _resolveImage((user['avatar_url'] ?? user['avatar'] ?? user['profile_photo_url'] ?? user['profile_photo_path'])?.toString());
    final email = (user['email'] ?? '').toString();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        title: Text('Profile', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : const AssetImage('assets/images/logo-sm.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? '—' : name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(email, style: GoogleFonts.urbanist(color: Theme.of(context).hintColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).dividerColor, height: 24),

                  _menuItem(Icons.edit_rounded, 'Edit Profile', onTap: () async {
                    final res = await Navigator.pushNamed(context, '/profile/edit');
                    if (res == true) _load();
                  }),
                  _menuItem(Icons.work_history_rounded, 'My Bookings', onTap: () => Navigator.pushNamed(context, '/bookings')),
                  _menuItem(Icons.credit_card_rounded, 'Subscription Plans', onTap: () => Navigator.pushNamed(context, '/subscriptions')),
                  _menuItem(Icons.flag_outlined, 'Report a User', onTap: () => _showReportSheet(type: 'user')),
                  _menuItem(
                    Icons.logout_rounded,
                    'Logout',
                    iconColor: Colors.red,
                    onTap: () async {
                      await AuthService().logout();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (r) => false);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
