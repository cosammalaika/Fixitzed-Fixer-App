import 'package:flutter/material.dart';

class FixerBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const FixerBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    final items = [
      {'icon': currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined, 'label': 'Home'},
      {'icon': currentIndex == 1 ? Icons.calendar_today_rounded : Icons.calendar_month_outlined, 'label': 'Bookings'},
      {'icon': currentIndex == 2 ? Icons.credit_score : Icons.credit_card, 'label': 'Plans'},
      {'icon': currentIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    final bg = Theme.of(context).colorScheme.surface;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          boxShadow: [
            if (isLight)
              const BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final sel = i == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: sel ? BoxDecoration(color: const Color(0x1AF1592A), borderRadius: BorderRadius.circular(20)) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i]['icon'] as IconData, color: sel ? brand : Colors.black38, size: sel ? 26 : 24),
                    const SizedBox(height: 4),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? brand : Colors.black45),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

