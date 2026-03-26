import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PlatformStrip extends StatelessWidget {
  const PlatformStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _PlatformItem('TikTok', Icons.music_note_rounded, AppColor.tiktok),
      _PlatformItem('Instagram', Icons.camera_alt_rounded, AppColor.instagram),
      _PlatformItem('Facebook', Icons.thumb_up_alt_rounded, AppColor.facebook),
      _PlatformItem('X', Icons.close_rounded, AppColor.x),
      _PlatformItem('Pinterest', Icons.push_pin_rounded, AppColor.pinterest),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColor.surface.withAlpha(232),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColor.stroke),
        boxShadow: const [
          BoxShadow(
            color: AppColor.shadow,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Works with the apps you use most',
            style: TextStyle(
              color: AppColor.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quick paste support for reels, shorts, posts, and audio clips.',
            style: TextStyle(
              color: AppColor.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _PlatformBadge(item: item),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.item});

  final _PlatformItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColor.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color,
            ),
            child: Icon(item.icon, color: AppColor.surface, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColor.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformItem {
  const _PlatformItem(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
