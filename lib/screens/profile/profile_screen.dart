import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ApiClient.I.get('/api/me'),
      builder: (context, snap) {
        Map<String, dynamic> user = {};
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          try {
            final res = snap.data as dynamic;
            if (res.statusCode == 200) {
              final root = jsonDecode(res.body);
              if (root is Map<String, dynamic>) {
                user = (root['user'] ?? root['data'] ?? {}) as Map<String, dynamic>;
              }
            }
          } catch (_) {}
        }
        final first = (user['first_name'] ?? '').toString();
        final last = (user['last_name'] ?? '').toString();
        final name = ((user['name'] ?? '') as String).isNotEmpty ? user['name'] as String : ('$first $last').trim();
        final avatar = (user['avatar_url'] ?? user['avatar'] ?? '').toString();
        final email = (user['email'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
            title: Text('Profile', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: avatar.isNotEmpty
                        ? (avatar.startsWith('http') ? NetworkImage(avatar) as ImageProvider : AssetImage(avatar))
                        : const AssetImage('assets/images/logo-sm.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? '—' : name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(email, style: GoogleFonts.urbanist(color: Colors.black54)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _menuTile(context, Icons.credit_card, 'Subscription Plans', () => Navigator.pushNamed(context, '/subscriptions')),
              _menuTile(context, Icons.work_outline, 'My Bookings', () => Navigator.pushNamed(context, '/bookings')),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/signin', (r) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF1592A)),
        title: Text(title, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
