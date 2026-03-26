import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/quick_preset_option.dart';
import '../../home/views/widgets/preset_download_sheet.dart';
import '../controllers/quick_share_controller.dart';

class QuickShareView extends StatefulWidget {
  const QuickShareView({super.key});

  @override
  State<QuickShareView> createState() => _QuickShareViewState();
}

class _QuickShareViewState extends State<QuickShareView> {
  bool _didPresentSheet = false;
  bool _isOpening = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPresentSheet) {
      return;
    }
    _didPresentSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPresetSheet();
    });
  }

  Future<void> _showPresetSheet() async {
    final QuickShareController controller = Get.find<QuickShareController>();
    final String? url = await controller.takeSharedUrl();
    if (url == null) {
      controller.cancelAndClose();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (mounted) {
      setState(() => _isOpening = false);
    }

    final QuickPresetOption? preset = await PresetDownloadSheet.show(
      appName: 'Nexly',
      barrierColor: Colors.transparent,
    );

    if (!mounted) {
      return;
    }

    if (preset == null) {
      controller.cancelAndClose();
      return;
    }

    unawaited(controller.startPresetDownloadAndClose(preset));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColor.transparent,
        body: _isOpening ? const _OpeningOverlay() : const SizedBox.expand(),
      ),
    );
  }
}

class _OpeningOverlay extends StatelessWidget {
  const _OpeningOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColor.surface.withAlpha(236),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColor.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Text(
              'Opening sheet...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
