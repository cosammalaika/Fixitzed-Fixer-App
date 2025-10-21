// ignore_for_file: unnecessary_cast

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_fixer_app/config.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/auth_service.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';
import 'package:fixitzed_fixer_app/services/profile_photo_service.dart';
import 'package:fixitzed_fixer_app/services/report_service.dart';
import 'package:fixitzed_fixer_app/screens/profile/manage_services_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> user = {};
  bool _loading = true;
  bool _uploadingPhoto = false;
  int _avatarVersion = 0;
  late final VoidCallback _pointsListener;

  @override
  void initState() {
    super.initState();
    _pointsListener = () {
      final points = FixerService.priorityPointsNotifier.value;
      if (!mounted || points == null) return;
      setState(() {
        user = {
          ...user,
          'priority_points': points,
          'priorityPoints': points,
        };
      });
    };
    FixerService.priorityPointsNotifier.addListener(_pointsListener);
    _load();
  }

  @override
  void dispose() {
    FixerService.priorityPointsNotifier.removeListener(_pointsListener);
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, dynamic> nextUser = Map<String, dynamic>.from(user);
    Map<String, dynamic>? fixerData;

    try {
      final res = await ApiClient.I.get('/api/me');
      if (res.statusCode == 200) {
        final root = jsonDecode(res.body);
        if (root is Map) {
          final rawUser = root['user'] ?? root['data'] ?? {};
          if (rawUser is Map) {
            nextUser = Map<String, dynamic>.from(rawUser as Map);
          }
        }
      }
    } catch (_) {}

    try {
      final fixerRes = await ApiClient.I.get('/api/fixer/me');
      if (fixerRes.statusCode == 200) {
        final root = jsonDecode(fixerRes.body);
        if (root is Map) {
          final data = root['data'] ?? root['fixer'] ?? root['profile'];
          if (data is Map) {
            fixerData = Map<String, dynamic>.from(data as Map);
          }
        }
      }
    } catch (_) {}

    if (fixerData != null) {
      final points = _asInt(
        fixerData['priority_points'] ?? fixerData['priorityPoints'],
      );
      nextUser = {
        ...nextUser,
        'fixer': fixerData,
        'fixer_profile': fixerData,
        'fixerProfile': fixerData,
        if (points != null) 'priority_points': points,
        if (points != null) 'priorityPoints': points,
      };
      FixerService.broadcastPriorityPoints(points);
    }

    if (!mounted) return;
    setState(() {
      user = nextUser;
      _loading = false;
    });
  }

  String _resolveImage(String? raw) {
    if (raw == null) return '';
    final resolved = resolveMediaUrl(raw);
    return resolved;
  }

  Widget _menuItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? iconColor,
    bool showDivider = true,
  }) {
    const brand = Color(0xFFF1592A);
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x1AF1592A), Color(0x33F1592A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor ?? brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
    return Column(
      children: [
        tile,
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
      ],
    );
  }

  Future<void> _openEditProfile() async {
    final res = await Navigator.pushNamed(context, '/profile/edit');
    if (res == true) {
      await _load();
    }
  }

  void _showAvatarPreview(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            child: Image.network(
              trimmed,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Image.asset('assets/images/logo-sm.png', fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePhotoSheet() async {
    if (_uploadingPhoto) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Capture photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    final picker = ProfilePhotoService.instance;
    String? path;
    if (selection == 'camera') {
      path = await picker.pickFromCamera();
    } else if (selection == 'gallery') {
      path = await picker.pickFromGallery();
    }
    if (!mounted || path == null || path.isEmpty) return;
    await _uploadProfilePhoto(path);
  }

  Future<void> _uploadProfilePhoto(String path) async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    bool success = false;
    try {
      success = await AuthService().updateProfilePhoto(path);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _uploadingPhoto = false);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile photo updated.'
              : 'Failed to update profile photo.',
        ),
      ),
    );
    if (success) {
      await _load();
      if (mounted) {
        _avatarVersion++;
        setState(() {});
      }
    }
  }

  Set<int> _currentServiceIds() {
    final candidates = [
      user['fixer'],
      user['fixer_profile'],
      user['fixerProfile'],
    ];
    Map<String, dynamic>? profile;
    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic> && candidate.isNotEmpty) {
        profile = candidate;
        break;
      }
    }
    final servicesRaw = profile != null
        ? profile['services']
        : user['services'];
    final result = <int>{};
    if (servicesRaw is List) {
      for (final entry in servicesRaw) {
        final id = _resolveServiceId(entry);
        if (id != null) result.add(id);
      }
    }
    return result;
  }

  int? _resolveServiceId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value as Map);
      if (map['id'] != null) return _resolveServiceId(map['id']);
      if (map['service_id'] != null)
        return _resolveServiceId(map['service_id']);
      if (map['serviceId'] != null) return _resolveServiceId(map['serviceId']);
      if (map['pivot'] is Map) {
        final pivot = Map<String, dynamic>.from(map['pivot'] as Map);
        if (pivot['service_id'] != null) {
          return _resolveServiceId(pivot['service_id']);
        }
      }
    }
    return null;
  }

  int? _priorityPoints() {
    final variants = <Map<String, dynamic>>[
      Map<String, dynamic>.from(user),
      if (user['fixer'] is Map) Map<String, dynamic>.from(user['fixer'] as Map),
      if (user['fixer_profile'] is Map)
        Map<String, dynamic>.from(user['fixer_profile'] as Map),
      if (user['fixerProfile'] is Map)
        Map<String, dynamic>.from(user['fixerProfile'] as Map),
    ];

    for (final map in variants) {
      for (final key in const ['priority_points', 'priorityPoints']) {
        final resolved = _asInt(map[key]);
        if (resolved != null) return resolved;
      }
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  InputDecoration deco(
                    String label, {
                    String? hint,
                    IconData? icon,
                  }) => InputDecoration(
                    labelText: label,
                    hintText: hint,
                    prefixIcon: icon != null ? Icon(icon) : null,
                    filled: true,
                    fillColor: const Color(0xFFF3F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                              color: const Color(0xFFF1592A).withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flag_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Report ${type == 'user' ? 'a User' : 'an Issue'}',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share details so we can act.',
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: subjectCtrl,
                        decoration: deco(
                          'Subject',
                          hint: 'Short title',
                          icon: Icons.subject_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 5,
                        decoration: deco(
                          'Message',
                          hint: 'Describe the issue',
                          icon: Icons.message_rounded,
                        ),
                      ),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Report submitted'
                                            : 'Failed to submit report',
                                      ),
                                    ),
                                  );
                                  if (ok) Navigator.of(ctx).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1592A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(submitting ? 'Submitting…' : 'Submit'),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
    final name = ((user['name'] ?? '') as String?)?.isNotEmpty == true
        ? user['name'] as String
        : ('$first $last').trim();
    final avatar = _resolveImage(
      (user['avatar_url'] ??
              user['avatar'] ??
              user['profile_photo_url'] ??
              user['profile_photo_path'])
          ?.toString(),
    );
    final avatarDisplay = (avatar.isNotEmpty && _avatarVersion > 0)
        ? '$avatar${avatar.contains('?') ? '&' : '?'}v=$_avatarVersion'
        : avatar;
    final email = (user['email'] ?? '').toString();
    final location = ((user['address'] ?? user['location']) ?? '')
        .toString()
        .trim();
    final priorityPoints = _priorityPoints();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF1592A), Color(0xFFFF8A5C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF1592A).withOpacity(0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ProfileAvatar(
                              url: avatarDisplay,
                              radius: 36,
                              onChangePhoto: _showChangePhotoSheet,
                              onViewPhoto: () =>
                                  _showAvatarPreview(avatarDisplay),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'Welcome Fixer' : name,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    email.isEmpty ? 'No email on file' : email,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  if (location.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.place_outlined,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            location,
                                            style: GoogleFonts.urbanist(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
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
                                  Icons.verified_user_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Keep your profile updated to attract more service requests.',
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (priorityPoints != null) ...[
                    const SizedBox(height: 16),
                    _PriorityPointsCard(points: priorityPoints),
                  ],
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _menuItem(
                          Icons.edit_rounded,
                          'Edit Profile',
                          onTap: _openEditProfile,
                        ),
                        _menuItem(
                          Icons.home_repair_service_rounded,
                          'Manage Services',
                          onTap: () async {
                            final initialIds = _currentServiceIds();
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute<bool>(
                                builder: (_) => ManageServicesScreen(
                                  initialServiceIds: initialIds,
                                ),
                                settings: const RouteSettings(
                                  name: '/profile/manage-services',
                                ),
                              ),
                            );
                            if (updated == true) _load();
                          },
                        ),
                        _menuItem(
                          Icons.work_history_rounded,
                          'My Bookings',
                          onTap: () =>
                              Navigator.pushNamed(context, '/bookings'),
                        ),
                        _menuItem(
                          Icons.credit_card_rounded,
                          'Subscription Plans',
                          onTap: () =>
                              Navigator.pushNamed(context, '/subscriptions'),
                        ),
                        _menuItem(
                          Icons.info_rounded,
                          'About FixitZed',
                          onTap: () => Navigator.pushNamed(context, '/about'),
                        ),
                        _menuItem(
                          Icons.flag_outlined,
                          'Report a User',
                          onTap: () => _showReportSheet(type: 'user'),
                        ),
                        _menuItem(
                          Icons.logout_rounded,
                          'Logout',
                          iconColor: Colors.red,
                          showDivider: false,
                          onTap: () async {
                            await AuthService().logout();
                            if (!mounted) return;
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/signin', (r) => false);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PriorityPointsCard extends StatelessWidget {
  final int points;

  const _PriorityPointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFF8A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1592A).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priority Points',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points pts',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Higher points improve how often you are surfaced to clients.',
                  style: GoogleFonts.urbanist(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13.5,
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

class _ProfileAvatar extends StatefulWidget {
  final String url;
  final double radius;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onViewPhoto;
  const _ProfileAvatar({
    required this.url,
    required this.radius,
    this.onChangePhoto,
    this.onViewPhoto,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final double innerRadius = widget.radius - 2;
    final placeholder = ClipOval(
      child: Image.asset(
        'assets/images/logo-sm.png',
        width: innerRadius * 2,
        height: innerRadius * 2,
        fit: BoxFit.cover,
      ),
    );

    Widget imageChild;
    final url = widget.url.trim();
    final validUrl = url.isNotEmpty && url.toLowerCase() != 'null';
    if (!_failed && validUrl) {
      imageChild = ClipOval(
        child: Image.network(
          url,
          width: innerRadius * 2,
          height: innerRadius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (!_failed && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
            }
            return placeholder;
          },
        ),
      );
    } else {
      imageChild = placeholder;
    }

    return GestureDetector(
      onTap: () => _showOptions(context, hasImage: validUrl),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.white,
        child: imageChild,
      ),
    );
  }

  void _showOptions(BuildContext context, {required bool hasImage}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_rounded),
              title: const Text('View profile photo'),
              enabled: hasImage,
              onTap: hasImage
                  ? () {
                      Navigator.of(ctx).pop();
                      if (widget.onViewPhoto != null) {
                        widget.onViewPhoto!.call();
                      } else {
                        _defaultPreview(context);
                      }
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Edit profile photo'),
              enabled: widget.onChangePhoto != null,
              onTap: widget.onChangePhoto != null
                  ? () {
                      Navigator.of(ctx).pop();
                      widget.onChangePhoto!.call();
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _defaultPreview(BuildContext context) {
    final url = widget.url.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            child: url.isEmpty
                ? Image.asset('assets/images/logo-sm.png', fit: BoxFit.cover)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo-sm.png',
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
