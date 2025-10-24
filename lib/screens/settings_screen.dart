import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_fixer_app/core/app_theme.dart';
import 'package:fixitzed_fixer_app/core/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kPush = AppSettingsKeys.pushNotifications;
  static const _kEmail = AppSettingsKeys.emailNotifications;
  static const _kDark = AppSettingsKeys.darkMode;
  static const _kLanguage = AppSettingsKeys.language;

  bool pushOn = true;
  bool emailOn = true;
  bool darkOn = false;
  String language = 'English';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pushOn = prefs.getBool(_kPush) ?? true;
      emailOn = prefs.getBool(_kEmail) ?? true;
      darkOn = prefs.getBool(_kDark) ?? false;
      language = prefs.getString(_kLanguage) ?? 'English';
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Widget _heroCard(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFF8A5C);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      colors: isDark
          ? [brand.withOpacity(0.95), accent.withOpacity(0.85)]
          : const [brand, accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              color: brand.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: shadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tune your experience',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Control notifications, theme and language.',
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

  Widget _section({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: scheme.onSurface.withOpacity(isDark ? 0.65 : 0.55),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: scheme.outline.withOpacity(isDark ? 0.14 : 0.08),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tilePadding({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: child,
    );
  }

  Widget _languageTile(BuildContext context, Color textColor, Color hintColor) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            final sc = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sc.surface,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -6),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sc.outlineVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final lang in ['English', 'Bemba', 'Nyanja'])
                      ListTile(
                        leading: const Icon(Icons.translate_rounded),
                        title: Text(
                          lang,
                          style: GoogleFonts.urbanist(
                            fontWeight: lang == language
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: lang == language
                            ? Icon(Icons.check_rounded, color: sc.primary)
                            : null,
                        onTap: () => Navigator.pop(ctx, lang),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
        if (choice != null) {
          setState(() => language = choice);
          await _saveString(_kLanguage, choice);
          await AppSettings.setLanguage(choice);
        }
      },
      child: _tilePadding(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  language,
                  style: GoogleFonts.urbanist(fontSize: 13, color: hintColor),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color hintColor,
  }) {
    return _tilePadding(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(fontSize: 13, color: hintColor),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textColor = scheme.onSurface;
    final hintColor = scheme.onSurface.withOpacity(
      theme.brightness == Brightness.dark ? 0.6 : 0.55,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _heroCard(context),
                _section(
                  context: context,
                  title: 'General',
                  children: [_languageTile(context, textColor, hintColor)],
                ),
                _section(
                  context: context,
                  title: 'Notifications',
                  children: [
                    _switchTile(
                      title: 'Push Notifications',
                      subtitle: 'Receive in-app updates and alerts',
                      value: pushOn,
                      onChanged: (v) async {
                        setState(() => pushOn = v);
                        await _saveBool(_kPush, v);
                        await AppSettings.setPushEnabled(v);
                      },
                      textColor: textColor,
                      hintColor: hintColor,
                    ),
                    _switchTile(
                      title: 'Email Notifications',
                      subtitle: 'Get booking and promo emails',
                      value: emailOn,
                      onChanged: (v) async {
                        setState(() => emailOn = v);
                        await _saveBool(_kEmail, v);
                        await AppSettings.setEmailEnabled(v);
                      },
                      textColor: textColor,
                      hintColor: hintColor,
                    ),
                  ],
                ),
                _section(
                  context: context,
                  title: 'Appearance',
                  children: [
                    _switchTile(
                      title: 'Dark Mode',
                      subtitle: 'Reduce eye strain at night',
                      value: darkOn,
                      onChanged: (v) async {
                        setState(() => darkOn = v);
                        await _saveBool(_kDark, v);
                        await AppTheme.setDark(v);
                      },
                      textColor: textColor,
                      hintColor: hintColor,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
