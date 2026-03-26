import 'dart:async';

import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

class ShareIntentService {
  final ShareHandlerPlatform _shareHandler = ShareHandlerPlatform.instance;
  static const MethodChannel _entryModeChannel = MethodChannel(
    'nexly/entry_mode',
  );
  String? _cachedInitialSharedText;
  bool _didWarmUpInitialSharedText = false;

  Stream<String> get sharedTextStream => _shareHandler.sharedMediaStream
      .map(_extractIncomingText)
      .where((value) => value != null && value.trim().isNotEmpty)
      .map((value) => value!.trim());

  bool get hasPrimedSharedText =>
      (_cachedInitialSharedText?.trim().isNotEmpty ?? false);

  Future<bool> isQuickShareLaunch() async {
    try {
      final String? mode = await _entryModeChannel.invokeMethod<String>(
        'getLaunchMode',
      );
      return mode == 'quick';
    } catch (_) {
      return false;
    }
  }

  Future<void> warmUpInitialSharedText() async {
    if (_didWarmUpInitialSharedText) {
      return;
    }
    _didWarmUpInitialSharedText = true;

    final SharedMedia? media = await _shareHandler.getInitialSharedMedia();
    final String? text = _extractIncomingText(media);
    _cachedInitialSharedText = text?.trim();
  }

  Future<String?> takeInitialSharedText() async {
    await warmUpInitialSharedText();

    final String cached = _cachedInitialSharedText?.trim() ?? '';
    _cachedInitialSharedText = null;
    await _shareHandler.resetInitialSharedMedia();
    return cached.isEmpty ? null : cached;
  }

  String? _extractIncomingText(SharedMedia? media) {
    if (media == null) {
      return null;
    }

    final String content = media.content?.trim() ?? '';
    if (content.isNotEmpty) {
      return content;
    }

    final List<SharedAttachment?> attachments =
        media.attachments ?? <SharedAttachment?>[];
    if (attachments.isEmpty) {
      return null;
    }

    final SharedAttachment? attachment = attachments.first;
    final String path = attachment == null ? '' : attachment.path.trim();
    return path.isEmpty ? null : path;
  }
}
