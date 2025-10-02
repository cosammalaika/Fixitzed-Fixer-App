import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        title: Text('Edit Profile', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      BoxShadow(color: brand.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Update your profile', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('Keep your info current so customers can reach you.', style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.9))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _dec(context, 'Full Name'),
                  cursorColor: brand,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: _dec(context, 'Email'),
                  cursorColor: brand,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Changes'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String label) => InputDecoration(
        labelText: label,
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
        ),
      );
}
