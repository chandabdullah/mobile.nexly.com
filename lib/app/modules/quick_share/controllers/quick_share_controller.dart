import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/models/quick_preset_option.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/quick_preset_selector.dart';
import '../../../data/services/share_intent_service.dart';

class QuickShareController extends GetxController {
  QuickShareController(
    this._downloadService,
    this._shareIntentService,
    this._localNotificationService,
  );
  final DownloadService _downloadService;
  final ShareIntentService _shareIntentService;
  final LocalNotificationService _localNotificationService;

  String? _sharedUrl;

  Future<String?> takeSharedUrl() async {
    if (_sharedUrl != null && _sharedUrl!.trim().isNotEmpty) {
      return _sharedUrl;
    }
    final String? url = await _shareIntentService.takeInitialSharedText();
    final String normalized = url?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    _sharedUrl = normalized;
    return normalized;
  }

  Future<void> startPresetDownloadAndClose(QuickPresetOption preset) async {
    final String? url = await takeSharedUrl();
    if (url == null || url.isEmpty) {
      cancelAndClose();
      return;
    }

    if (Platform.isAndroid) {
      await _localNotificationService.init();
      await _localNotificationService.showResolving(
        title: 'Resolving download',
        body: 'Preparing your selected quality...',
      );
    }

    try {
      final PreparedDownload prepared = await _downloadService.prepareDownload(
        url,
      );
      final PreparedDownloadOption selected = QuickPresetSelector.pick(
        prepared,
        preset,
      );
      await _downloadService.enqueuePreparedOption(selected);
    } on DownloadServiceException catch (e) {
      developer.log(
        'QuickShare preset download error: ${e.message}',
        name: 'nexly.quickshare',
      );
      if (Platform.isAndroid) {
        await _localNotificationService.showDownloadFailed(
          title: 'Download failed',
          body: e.message,
        );
      }
    } catch (_) {
      developer.log(
        'QuickShare preset download unknown error',
        name: 'nexly.quickshare',
      );
      if (Platform.isAndroid) {
        await _localNotificationService.showDownloadFailed(
          title: 'Download failed',
          body: 'Unable to resolve this link right now.',
        );
      }
    } finally {
      if (Platform.isAndroid) {
        await _localNotificationService.clearResolving();
      }
    }

    if (Platform.isAndroid) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      SystemNavigator.pop();
    }
  }

  void cancelAndClose() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    }
  }
}
