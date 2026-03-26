import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../controllers/home_controller.dart';

class DownloadActionCard extends GetView<HomeController> {
  const DownloadActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColor.surface.withAlpha(238),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColor.stroke),
        boxShadow: const [
          BoxShadow(
            color: AppColor.shadow,
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste your video link',
            style: TextStyle(
              color: AppColor.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drop any supported URL below and prepare it for download.',
            style: TextStyle(
              color: AppColor.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Obx(
            () => TextField(
              controller: controller.linkController,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.plusJakartaSans(
                color: AppColor.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'https://example.com/video-link',
                prefixIcon: const Icon(
                  Icons.link_rounded,
                  color: AppColor.primaryDeep,
                  size: 20,
                ),
                suffixIcon: controller.isLinkReady.value
                    ? GestureDetector(
                        onTap: controller.clearLink,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [AppColor.primary, AppColor.primaryDeep],
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColor.surface,
                            size: 20,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Obx(
            () => controller.hasDetectedPlatform.value
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColor.primarySoft.withAlpha(82),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColor.stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.detectedPlatformColor.value,
                          ),
                          child: Icon(
                            controller.detectedPlatformIcon.value,
                            color: AppColor.surface,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.detectedPlatformName.value,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColor.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          Obx(
            () => Text(
              controller.statusText.value,
              style: const TextStyle(
                color: AppColor.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isPreparing.value
                    ? null
                    : controller.startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      controller.isLinkReady.value &&
                          !controller.isPreparing.value
                      ? AppColor.primary
                      : AppColor.secondary,
                  foregroundColor: AppColor.surface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      controller.isPreparing.value
                          ? 'Preparing Download'
                          : controller.isDownloading.value
                          ? 'Downloading ${controller.downloadProgress.value}%'
                          : controller.isLinkReady.value
                          ? 'Download Now'
                          : 'Paste a Link First',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColor.surface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
