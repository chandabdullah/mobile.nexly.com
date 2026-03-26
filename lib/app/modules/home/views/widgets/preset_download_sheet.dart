import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/quick_preset_option.dart';

class PresetDownloadSheet {
  PresetDownloadSheet._();

  static Future<QuickPresetOption?> show({
    required String appName,
    Color? barrierColor,
  }) {
    return Get.bottomSheet<QuickPresetOption>(
      _PresetSheetBody(appName: appName),
      isScrollControlled: true,
      backgroundColor: AppColor.transparent,
      barrierColor: barrierColor ?? AppColor.scrim,
    );
  }
}

class _PresetSheetBody extends StatefulWidget {
  const _PresetSheetBody({required this.appName});

  final String appName;

  @override
  State<_PresetSheetBody> createState() => _PresetSheetBodyState();
}

class _PresetSheetBodyState extends State<_PresetSheetBody> {
  QuickPresetOption selected = QuickPresetOption.videoHigh;

  @override
  Widget build(BuildContext context) {
    final bool isAudio = selected == QuickPresetOption.audio;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColor.stroke),
          boxShadow: const [
            BoxShadow(
              color: AppColor.shadow,
              blurRadius: 28,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                width: 34,
                child: Divider(thickness: 3, color: AppColor.stroke),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColor.primarySoft.withAlpha(82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColor.stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColor.primaryDeep, AppColor.secondary],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icons/nexly.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.appName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColor.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Instant preset mode',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Download type',
              style: GoogleFonts.spaceGrotesk(
                color: AppColor.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColor.primarySoft.withAlpha(70),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColor.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Video',
                      selected: !isAudio,
                      onTap: () => setState(
                        () => selected = QuickPresetOption.videoHigh,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TypeButton(
                      label: 'Audio',
                      selected: isAudio,
                      onTap: () =>
                          setState(() => selected = QuickPresetOption.audio),
                    ),
                  ),
                ],
              ),
            ),
            if (!isAudio) ...[
              const SizedBox(height: 12),
              Text(
                'Video quality',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColor.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _PresetItem(
                title: 'High',
                subtitle: 'Best available quality',
                selected: selected == QuickPresetOption.videoHigh,
                onTap: () =>
                    setState(() => selected = QuickPresetOption.videoHigh),
              ),
              const SizedBox(height: 8),
              _PresetItem(
                title: 'Medium',
                subtitle: 'Balanced quality',
                selected: selected == QuickPresetOption.videoMedium,
                onTap: () =>
                    setState(() => selected = QuickPresetOption.videoMedium),
              ),
              const SizedBox(height: 8),
              _PresetItem(
                title: 'Low',
                subtitle: 'Smaller file size',
                selected: selected == QuickPresetOption.videoLow,
                onTap: () =>
                    setState(() => selected = QuickPresetOption.videoLow),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Audio will use the best available audio stream.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColor.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back<void>(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColor.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Get.back<QuickPresetOption>(result: selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primary,
                      foregroundColor: AppColor.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Download Selected'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColor.primary : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: selected ? AppColor.surface : AppColor.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetItem extends StatelessWidget {
  const _PresetItem({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColor.primary : AppColor.stroke,
            width: selected ? 1.4 : 1,
          ),
          color: selected
              ? AppColor.primary.withAlpha(16)
              : AppColor.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColor.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColor.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColor.primary : AppColor.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
