import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../controllers/home_controller.dart';

class DownloadOverlay extends GetView<HomeController> {
  const DownloadOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final bool shouldShowOverlay =
            controller.isDownloading.value && !Platform.isAndroid;

        return IgnorePointer(
        ignoring: !shouldShowOverlay,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: shouldShowOverlay ? 1 : 0,
          child: shouldShowOverlay
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: AppColor.scrim,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.92, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColor.surfaceDark, AppColor.primaryDeep],
                          ),
                          border: Border.all(
                            color: AppColor.secondary.withAlpha(120),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColor.shadow,
                              blurRadius: 34,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColor.surface.withAlpha(32),
                                border: Border.all(
                                  color: AppColor.surface.withAlpha(50),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 5,
                                      value: controller.isDownloading.value
                                          ? controller.downloadProgress.value /
                                                100
                                          : null,
                                      backgroundColor: AppColor.surface
                                          .withAlpha(44),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColor.surface,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    controller.isPreparing.value
                                        ? Icons.auto_awesome_rounded
                                        : Icons.download_rounded,
                                    color: AppColor.surface,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              controller.isPreparing.value
                                  ? 'Preparing Your Video'
                                  : 'Downloading Video',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColor.surface,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              controller.statusText.value,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColor.surface.withAlpha(232),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            if (controller.isDownloading.value) ...[
                              const SizedBox(height: 8),
                              Text(
                                controller.activeOptionLabel.value,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppColor.surface.withAlpha(236),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppColor.surface.withAlpha(28),
                                border: Border.all(
                                  color: AppColor.surface.withAlpha(42),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: controller.isDownloading.value
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                child: LinearProgressIndicator(
                                                  minHeight: 9,
                                                  value: controller
                                                          .downloadProgress
                                                          .value /
                                                      100,
                                                  backgroundColor: AppColor
                                                      .surface
                                                      .withAlpha(46),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<Color>(
                                                        AppColor.surface,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                controller.activeSizeText.value,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: AppColor.surface
                                                          .withAlpha(220),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: LinearProgressIndicator(
                                              minHeight: 9,
                                              backgroundColor: AppColor.surface
                                                  .withAlpha(46),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<Color>(
                                                    AppColor.surface,
                                                  ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    controller.isPreparing.value
                                        ? '...'
                                        : '${controller.downloadProgress.value}%',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: AppColor.surface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
      },
    );
  }
}
