import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSnack {
  static void show(BuildContext context, {required String message, required bool success}) {
    final color = success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.urbanist(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}

