import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:fixitzed_fixer_app/models/fixer.dart';
import 'package:fixitzed_fixer_app/services/api_client.dart';
import 'package:fixitzed_fixer_app/services/fixer_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _fixer = FixerService();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String _availability = 'available';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    Map<String, dynamic> account = const <String, dynamic>{};
    Fixer? fixer;

    try {
      final meRes = await ApiClient.I.get('/api/me');
      if (meRes.statusCode == 200) {
        final root = jsonDecode(meRes.body);
        if (root is Map<String, dynamic>) {
          final raw = root['user'] ?? root['data'];
          if (raw is Map) {
            account = raw.map((key, value) => MapEntry(key.toString(), value));
          }
        }
      }
    } catch (_) {}

    try {
      fixer = await _fixer.profile();
    } catch (_) {}

    if (!mounted) return;

    final firstName = fixer?.user.firstName?.trim();
    final lastName = fixer?.user.lastName?.trim();
    final displayName = [
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ].join(' ').trim();

    _nameCtrl.text = displayName.isNotEmpty
        ? displayName
        : _accountName(account);
    _emailCtrl.text = fixer?.user.email.trim().isNotEmpty == true
        ? fixer!.user.email.trim()
        : (account['email']?.toString().trim() ?? '');
    _bioCtrl.text = fixer?.bio?.trim() ?? '';
    _locationCtrl.text =
        _stringValue(fixer?.location) ??
        _stringValue(account['location']) ??
        _stringValue(account['address']) ??
        '';
    _availability = _normalizeAvailability(fixer?.availability);

    setState(() {
      _loading = false;
      _loadError = fixer == null && account.isEmpty
          ? 'Unable to load your profile right now.'
          : null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _fixer.updateMe(
        bio: _bioCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        availability: _availability,
      );
      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save your profile right now.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save your profile right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _accountName(Map<String, dynamic> account) {
    final first = _stringValue(account['first_name']) ?? '';
    final last = _stringValue(account['last_name']) ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    return _stringValue(account['name']) ?? '';
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _normalizeAvailability(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'busy':
        return 'busy';
      case 'offline':
        return 'offline';
      default:
        return 'available';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.urbanist(
                          color: theme.fx.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [brand, accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: brand.withOpacity(0.18),
                              blurRadius: 18,
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
                                Icons.edit_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update your profile',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Account name and email come from your FixitZED account. Bio, location and availability update your fixer profile.',
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
                      TextFormField(
                        controller: _nameCtrl,
                        readOnly: true,
                        decoration: _dec(
                          context,
                          'Full Name',
                          helper:
                              'Managed by your account details and shown here for reference.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        readOnly: true,
                        decoration: _dec(
                          context,
                          'Email',
                          helper:
                              'Your sign-in email is read-only from this screen.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationCtrl,
                        decoration: _dec(
                          context,
                          'Service Area',
                          helper: 'Example: Lusaka West or Matero',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length > 120) {
                            return 'Keep location under 120 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _availability,
                        decoration: _dec(
                          context,
                          'Availability',
                          helper:
                              'Controls whether new customers can reach you for jobs.',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Available'),
                          ),
                          DropdownMenuItem(value: 'busy', child: Text('Busy')),
                          DropdownMenuItem(
                            value: 'offline',
                            child: Text('Offline'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _availability = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: 300,
                        decoration: _dec(
                          context,
                          'Bio',
                          helper:
                              'Share the kinds of jobs you handle and the experience customers should know about.',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length > 300) {
                            return 'Keep your bio under 300 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String label, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.18),
      labelStyle: TextStyle(color: Theme.of(context).hintColor),
      hintStyle: TextStyle(color: Theme.of(context).hintColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.2,
        ),
      ),
    );
  }
}
