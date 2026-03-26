import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class StatusDialog {
  StatusDialog._();

  static Future<void> show({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }

    await Get.dialog<void>(
      Dialog(
        backgroundColor: AppColor.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isError
                  ? const [AppColor.surfaceDark, AppColor.errorSoft]
                  : const [AppColor.surfaceDark, AppColor.primaryDeep],
            ),
            border: Border.all(
              color: isError
                  ? AppColor.error.withAlpha(140)
                  : AppColor.secondary.withAlpha(130),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColor.shadow,
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError
                      ? AppColor.error.withAlpha(44)
                      : AppColor.primary.withAlpha(48),
                ),
                child: Icon(
                  isError ? Icons.close_rounded : Icons.check_rounded,
                  color: AppColor.textInverse,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColor.textInverse,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColor.textInverse.withAlpha(232),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back<void>(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.surface,
                    foregroundColor: isError
                        ? AppColor.error
                        : AppColor.primaryDeep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
}
