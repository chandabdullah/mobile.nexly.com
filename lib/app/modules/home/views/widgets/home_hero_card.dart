import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.primaryDeep, AppColor.primary, AppColor.secondary],
        ),
        border: Border.all(color: AppColor.secondary.withAlpha(70)),
        boxShadow: const [
          BoxShadow(
            color: AppColor.shadow,
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColor.surface.withAlpha(36),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/nexly.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Text(
                'Nexly',
                style: TextStyle(
                  color: AppColor.surface,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.surface.withAlpha(54),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColor.surface,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Paste a link and save clips from your favorite platforms in a cleaner, faster flow.',
            style: TextStyle(
              color: AppColor.surface.withAlpha(220),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
