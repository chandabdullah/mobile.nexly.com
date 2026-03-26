import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/quick_preset_option.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/quick_preset_selector.dart';
import '../../../data/services/share_intent_service.dart';
import '../views/widgets/preset_download_sheet.dart';
import '../views/widgets/status_dialog.dart';

class HomeController extends GetxController {
  HomeController(
    this._downloadService,
    this._shareIntentService,
    this._localNotificationService,
  );

  final DownloadService _downloadService;
  final ShareIntentService _shareIntentService;
  final LocalNotificationService _localNotificationService;
  final TextEditingController linkController = TextEditingController();
  final RxBool isLinkReady = false.obs;
  final RxBool isPreparing = false.obs;
  final RxBool isDownloading = false.obs;
  final RxBool hasDetectedPlatform = false.obs;
  final RxString detectedPlatformName = ''.obs;
  final Rx<IconData> detectedPlatformIcon = Icons.link_rounded.obs;
  final Rx<Color> detectedPlatformColor = AppColor.primaryDeep.obs;
  final RxInt downloadProgress = 0.obs;
  final RxString activeOptionLabel = ''.obs;
  final RxString activeSizeText = ''.obs;
  final RxString statusText =
      'Supports direct links, YouTube, and resolver-backed social video links.'
          .obs;

  StreamSubscription<DownloadTaskUpdate>? _downloadSubscription;
  StreamSubscription<String>? _sharedTextSubscription;
  Timer? _downloadMonitorTimer;
  String? _activeTaskId;
  String? _activeSavedFilePath;
  String? _lastSuccessMessage;
  bool _shouldAutoCloseAfterEnqueue = false;
  bool _isQuickShareSession = false;
  String? _lastHandledSharedText;
  DateTime? _lastHandledSharedAt;
  DateTime? _lastTaskSignalAt;
  int _lastObservedProgress = -1;
  int? _activeTotalBytes;
  String? _lastObservedStatusName;

  bool get isBusy => isPreparing.value || isDownloading.value;

  @override
  void onInit() {
    super.onInit();
    linkController.addListener(_onLinkChanged);
    _downloadSubscription = _downloadService.updates.listen(
      _handleDownloadUpdate,
    );
    _sharedTextSubscription = _shareIntentService.sharedTextStream.listen(
      _handleSharedText,
    );
    _loadInitialSharedText();
  }

  @override
  void onClose() {
    _downloadSubscription?.cancel();
    _sharedTextSubscription?.cancel();
    _downloadMonitorTimer?.cancel();
    linkController.removeListener(_onLinkChanged);
    linkController.dispose();
    super.onClose();
  }

  Future<void> pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    final String text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      await StatusDialog.show(
        title: 'Clipboard Empty',
        message: 'Copy a video link first, then try again.',
        isError: true,
      );
      return;
    }

    linkController.text = text;
  }

  void clearLink() {
    linkController.clear();
    hasDetectedPlatform.value = false;
    detectedPlatformName.value = '';
    statusText.value =
        'Supports direct links, YouTube, and resolver-backed social video links.';
  }

  Future<void> startDownload() async {
    if (!isLinkReady.value) {
      await StatusDialog.show(
        title: 'Link Required',
        message: 'Paste a valid video link to continue.',
        isError: true,
      );
      return;
    }

    if (isPreparing.value || isDownloading.value) {
      return;
    }

    _resetActiveDownloadPresentation();
    statusText.value = 'Open the sheet and choose your preset.';

    final QuickPresetOption? selectedPreset = await PresetDownloadSheet.show(
      appName: 'Nexly',
      barrierColor: _isQuickShareSession && Platform.isAndroid
          ? Colors.transparent
          : AppColor.scrim,
    );

    if (selectedPreset == null) {
      statusText.value = 'Download cancelled.';
      if (_isQuickShareSession && Platform.isAndroid) {
        _isQuickShareSession = false;
        _shouldAutoCloseAfterEnqueue = false;
        SystemNavigator.pop();
      }
      return;
    }

    _showResolvingStartedToast();

    try {
      statusText.value = 'Resolving selected quality...';
      if (Platform.isAndroid) {
        await _localNotificationService.showResolving(
          title: 'Resolving download',
          body: 'Preparing your selected quality...',
        );
      }
      final PreparedDownload prepared = await _downloadService.prepareDownload(
        linkController.text,
      );
      final PreparedDownloadOption selectedOption = QuickPresetSelector.pick(
        prepared,
        selectedPreset,
      );
      await _queuePreparedOption(selectedOption);
    } on DownloadServiceException catch (error) {
      isPreparing.value = false;
      isDownloading.value = false;
      _resetActiveDownloadPresentation();
      final String friendlyMessage = _toUserFriendlyErrorMessage(error.message);
      statusText.value = friendlyMessage;
      developer.log(
        'Download failed: ${error.message}',
        name: 'nexly.download',
        error: error.message,
      );
      await StatusDialog.show(
        title: 'Download Failed',
        message: friendlyMessage,
        isError: true,
      );
      if (_isQuickShareSession && Platform.isAndroid) {
        _isQuickShareSession = false;
        _shouldAutoCloseAfterEnqueue = false;
        SystemNavigator.pop();
      }
    } catch (_) {
      isPreparing.value = false;
      isDownloading.value = false;
      _resetActiveDownloadPresentation();
      statusText.value = 'Something went wrong while starting the download.';
      developer.log(
        'Download failed: Something went wrong while starting the download.',
        name: 'nexly.download',
      );
      await StatusDialog.show(
        title: 'Download Failed',
        message: 'Something went wrong while starting the download.',
        isError: true,
      );
      if (_isQuickShareSession && Platform.isAndroid) {
        _isQuickShareSession = false;
        _shouldAutoCloseAfterEnqueue = false;
        SystemNavigator.pop();
      }
    } finally {
      if (Platform.isAndroid) {
        await _localNotificationService.clearResolving();
      }
    }
  }

  void _onLinkChanged() {
    final String value = linkController.text.trim();
    isLinkReady.value = value.isNotEmpty;
    _detectPlatform(value);
  }

  void _detectPlatform(String value) {
    if (value.isEmpty) {
      hasDetectedPlatform.value = false;
      detectedPlatformName.value = '';
      return;
    }

    final Uri? uri = Uri.tryParse(value);
    final String host = (uri?.host ?? '').toLowerCase();
    hasDetectedPlatform.value = true;

    if (host.contains('youtube') || host.contains('youtu.be')) {
      detectedPlatformName.value = 'Detected: YouTube';
      detectedPlatformIcon.value = Icons.smart_display_rounded;
      detectedPlatformColor.value = const Color(0xFFFF0000);
      return;
    }
    if (host.contains('instagram')) {
      detectedPlatformName.value = 'Detected: Instagram';
      detectedPlatformIcon.value = Icons.camera_alt_rounded;
      detectedPlatformColor.value = AppColor.instagram;
      return;
    }
    if (host.contains('facebook') || host.contains('fb.')) {
      detectedPlatformName.value = 'Detected: Facebook';
      detectedPlatformIcon.value = Icons.thumb_up_alt_rounded;
      detectedPlatformColor.value = AppColor.facebook;
      return;
    }
    if (host.contains('tiktok')) {
      detectedPlatformName.value = 'Detected: TikTok';
      detectedPlatformIcon.value = Icons.music_note_rounded;
      detectedPlatformColor.value = AppColor.tiktok;
      return;
    }
    if (host.contains('x.com') || host.contains('twitter')) {
      detectedPlatformName.value = 'Detected: X';
      detectedPlatformIcon.value = Icons.close_rounded;
      detectedPlatformColor.value = AppColor.x;
      return;
    }
    if (host.contains('pinterest')) {
      detectedPlatformName.value = 'Detected: Pinterest';
      detectedPlatformIcon.value = Icons.push_pin_rounded;
      detectedPlatformColor.value = AppColor.pinterest;
      return;
    }

    detectedPlatformName.value = 'Detected: Website link';
    detectedPlatformIcon.value = Icons.language_rounded;
    detectedPlatformColor.value = AppColor.primaryDeep;
  }

  Future<void> _queuePreparedOption(PreparedDownloadOption option) async {
    isPreparing.value = true;
    statusText.value = 'Starting ${option.label} download...';

    final QueuedDownload result = await _downloadService.enqueuePreparedOption(
      option,
    );

    _activeTaskId = result.taskId;
    _activeSavedFilePath = '${result.savedDir}/${result.fileName}';
    _activeTotalBytes = result.totalBytes;
    activeOptionLabel.value = result.optionLabel;
    activeSizeText.value = result.totalBytes == null
        ? 'Size will appear when available.'
        : '0 B / ${_formatBytes(result.totalBytes!)}';
    _lastTaskSignalAt = DateTime.now();
    _lastObservedProgress = 0;
    _lastObservedStatusName = DownloadTaskStatus.enqueued.name;
    isPreparing.value = false;
    isDownloading.value = true;
    statusText.value = 'Downloading ${result.fileName}';
    _showDownloadStartedToast(option.label);
    _startDownloadMonitor(result.taskId);
    unawaited(_refreshTaskSnapshot(result.taskId));
    if (_shouldAutoCloseAfterEnqueue && Platform.isAndroid) {
      _shouldAutoCloseAfterEnqueue = false;
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (isClosed) {
          return;
        }
        SystemNavigator.pop();
      });
    }
  }

  Future<void> _loadInitialSharedText() async {
    final String? sharedText = await _shareIntentService
        .takeInitialSharedText();
    if (sharedText == null || sharedText.isEmpty) {
      return;
    }

    _handleSharedText(sharedText);
  }

  void _handleSharedText(String sharedText) {
    unawaited(_processSharedText(sharedText));
  }

  Future<void> _processSharedText(String sharedText) async {
    final String trimmed = sharedText.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastHandledSharedText == trimmed &&
        _lastHandledSharedAt != null &&
        now.difference(_lastHandledSharedAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastHandledSharedText = trimmed;
    _lastHandledSharedAt = now;

    linkController.text = trimmed;
    linkController.selection = TextSelection.collapsed(
      offset: linkController.text.length,
    );
    final bool quickLaunch = await _shareIntentService.isQuickShareLaunch();
    if (quickLaunch) {
      // Quick share is handled by the dedicated quick-share route/activity.
      // Ignore this event in HomeController to avoid duplicate sheets.
      return;
    }

    _isQuickShareSession = false;
    _shouldAutoCloseAfterEnqueue = false;
    statusText.value = 'Shared link received. Ready to download.';
  }

  void _handleDownloadUpdate(DownloadTaskUpdate update) {
    if (update.taskId != _activeTaskId) {
      return;
    }

    _registerTaskSignal(update.status.name, update.progress);
    downloadProgress.value = update.progress;
    _refreshSizeText(update.progress);

    if (update.status == DownloadTaskStatus.running) {
      isPreparing.value = false;
      isDownloading.value = true;
      statusText.value = 'Downloading ${update.progress}%';
      return;
    }

    if (update.status == DownloadTaskStatus.complete) {
      _handleSuccessfulDownload();
      return;
    }

    if (update.status == DownloadTaskStatus.failed ||
        update.status == DownloadTaskStatus.canceled) {
      _downloadMonitorTimer?.cancel();
      isPreparing.value = false;
      isDownloading.value = false;
      _resetActiveDownloadPresentation();
      statusText.value = 'Download failed';
      developer.log(
        'Download failed: task status ${update.status.name}',
        name: 'nexly.download',
        error: update.status.name,
      );
      if (Platform.isIOS) {
        unawaited(
          _localNotificationService.showDownloadFailed(
            title: 'Download Failed',
            body: 'This file could not be downloaded.',
          ),
        );
      } else if (!Platform.isAndroid) {
        StatusDialog.show(
          title: 'Download Failed',
          message: 'This file could not be downloaded.',
          isError: true,
        );
      }
      if (_isQuickShareSession && Platform.isAndroid) {
        _isQuickShareSession = false;
        _shouldAutoCloseAfterEnqueue = false;
        SystemNavigator.pop();
      }
      return;
    }

    if (update.status == DownloadTaskStatus.enqueued) {
      statusText.value = 'Download queued';
    }
  }

  Future<void> _handleSuccessfulDownload() async {
    _downloadMonitorTimer?.cancel();
    isPreparing.value = false;
    isDownloading.value = false;
    statusText.value = 'Download complete';
    _refreshSizeText(100);

    String message;

    if (_activeSavedFilePath == null) {
      message = 'Your video was saved successfully.';
    } else if (Platform.isAndroid) {
      message =
          'Your video was saved successfully.\n\nSaved to:\n$_activeSavedFilePath\n\nFolder:\nDownload/Nexly';
    } else {
      message =
          'Your video was saved successfully.\n\nSaved to:\n$_activeSavedFilePath';
    }

    if (_activeSavedFilePath != null && Platform.isIOS) {
      try {
        final GallerySaveResult result = await _downloadService
            .saveVideoToGallery(_activeSavedFilePath!);
        message =
            '$message\n\nAlso added to gallery album:\n${result.albumName}';
      } on DownloadServiceException catch (error) {
        developer.log(
          'Gallery save failed: ${error.message}',
          name: 'nexly.download',
          error: error.message,
        );
        message = '$message\n\nGallery sync note:\n${error.message}';
      }
    }

    if (_lastSuccessMessage == message) {
      return;
    }

    _lastSuccessMessage = message;
    developer.log(
      'Download complete: ${_activeSavedFilePath ?? 'unknown path'}',
      name: 'nexly.download',
    );
    if (Platform.isIOS) {
      await _localNotificationService.showDownloadComplete(
        title: 'Download Complete',
        body: 'Your video was saved successfully in Nexly.',
      );
    } else if (!Platform.isAndroid) {
      await StatusDialog.show(title: 'Download Complete', message: message);
    }
    _isQuickShareSession = false;
  }

  String _toUserFriendlyErrorMessage(String message) {
    final String normalized = message.toLowerCase();

    if (normalized.contains('clipboard')) {
      return 'Copy a video link first, then try again.';
    }

    if (normalized.contains('link required') ||
        normalized.contains('valid http or https link')) {
      return 'Please paste a valid video link and try again.';
    }

    if (normalized.contains('instagram share token') ||
        normalized.contains('copy link')) {
      return 'Use the original Copy Link option from Instagram, then paste that URL here.';
    }

    if (normalized.contains('resolver backend is not reachable')) {
      return 'The video resolver is offline right now. Start it and try again.';
    }

    if (normalized.contains('resolver backend is not configured')) {
      return 'The video resolver is not configured for this device.';
    }

    if (normalized.contains('ssl verification')) {
      return 'The source platform could not be reached securely. Please try again in a moment.';
    }

    if (normalized.contains('youtube')) {
      return 'This YouTube link could not be processed right now. Please try again.';
    }

    if (normalized.contains('no direct downloadable') ||
        normalized.contains('does not expose a downloadable video source')) {
      return 'This link is not exposing a downloadable video right now.';
    }

    if (normalized.contains('unable to reach this server') ||
        normalized.contains('could not be verified')) {
      return 'This link could not be reached right now. Please try again.';
    }

    if (normalized.contains('invalid response') ||
        normalized.contains('unreadable data')) {
      return 'The download source returned an invalid response. Please try again.';
    }

    return 'Something went wrong while processing this video link. Please try again.';
  }

  void _startDownloadMonitor(String taskId) {
    _downloadMonitorTimer?.cancel();
    _downloadMonitorTimer = Timer.periodic(const Duration(milliseconds: 800), (
      Timer timer,
    ) async {
      if (_activeTaskId != taskId ||
          !(isPreparing.value || isDownloading.value)) {
        timer.cancel();
        return;
      }

      await _refreshTaskSnapshot(taskId);

      final DateTime? lastSignalAt = _lastTaskSignalAt;
      if (lastSignalAt == null) {
        return;
      }

      if (DateTime.now().difference(lastSignalAt) >
          const Duration(seconds: 45)) {
        timer.cancel();
        _handleStuckDownload();
      }
    });
  }

  Future<void> _refreshTaskSnapshot(String taskId) async {
    final DownloadTaskUpdate? snapshot = await _downloadService.getTaskUpdate(
      taskId,
    );

    if (snapshot != null) {
      _handleDownloadUpdate(snapshot);
    }
  }

  void _registerTaskSignal(String statusName, int progress) {
    if (_lastObservedStatusName != statusName ||
        _lastObservedProgress != progress) {
      _lastObservedStatusName = statusName;
      _lastObservedProgress = progress;
      _lastTaskSignalAt = DateTime.now();
    }
  }

  Future<void> _handleStuckDownload() async {
    _downloadMonitorTimer?.cancel();
    isPreparing.value = false;
    isDownloading.value = false;
    _resetActiveDownloadPresentation();
    statusText.value = 'Download timed out';
    developer.log(
      'Download failed: task stalled without progress callbacks',
      name: 'nexly.download',
      error: 'timeout',
    );
    if (Platform.isIOS) {
      await _localNotificationService.showDownloadFailed(
        title: 'Download Failed',
        body: 'The download did not respond in time. Please try again.',
      );
    } else if (!Platform.isAndroid) {
      await StatusDialog.show(
        title: 'Download Failed',
        message:
            'The download did not respond in time. Please try again. If it keeps happening, try another link.',
        isError: true,
      );
    }
  }

  void _refreshSizeText(int progress) {
    if (_activeTotalBytes == null) {
      activeSizeText.value = 'Size will appear when available.';
      return;
    }

    final int downloadedBytes = ((_activeTotalBytes! * progress) / 100).round();
    activeSizeText.value =
        '${_formatBytes(downloadedBytes)} / ${_formatBytes(_activeTotalBytes!)}';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }

    return '$bytes B';
  }

  void _resetActiveDownloadPresentation() {
    downloadProgress.value = 0;
    activeOptionLabel.value = '';
    activeSizeText.value = '';
    _activeTaskId = null;
    _activeSavedFilePath = null;
    _activeTotalBytes = null;
    _lastTaskSignalAt = null;
    _lastObservedProgress = -1;
    _lastObservedStatusName = null;
  }

  void _showDownloadStartedToast(String optionLabel) {
    Get.closeAllSnackbars();
    Get.snackbar(
      'Download Started',
      '$optionLabel download was added successfully.',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      borderRadius: 16,
      backgroundColor: const Color(0xCCBEE3FF),
      borderColor: const Color(0x99FFFFFF),
      borderWidth: 1,
      colorText: const Color(0xFF0A3970),
      barBlur: 18,
      duration: const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 220),
      icon: const Icon(
        Icons.download_done_rounded,
        color: Color(0xFF0A65D9),
        size: 20,
      ),
      shouldIconPulse: false,
      overlayBlur: 0,
      overlayColor: Colors.transparent,
    );
  }

  void _showResolvingStartedToast() {
    Get.closeAllSnackbars();
    Get.snackbar(
      'Resolving Link',
      'Preparing your selected quality...',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      borderRadius: 16,
      backgroundColor: const Color(0xCCBEE3FF),
      borderColor: const Color(0x99FFFFFF),
      borderWidth: 1,
      colorText: const Color(0xFF0A3970),
      barBlur: 18,
      duration: const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 220),
      icon: const Icon(Icons.sync_rounded, color: Color(0xFF0A65D9), size: 20),
      shouldIconPulse: false,
      overlayBlur: 0,
      overlayColor: Colors.transparent,
    );
  }
}
