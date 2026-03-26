import '../models/quick_preset_option.dart';
import 'download_service.dart';

class QuickPresetSelector {
  const QuickPresetSelector._();

  static PreparedDownloadOption pick(
    PreparedDownload prepared,
    QuickPresetOption preset,
  ) {
    if (preset == QuickPresetOption.audio) {
      final List<PreparedDownloadOption> audio = prepared.options
          .where(
            (PreparedDownloadOption o) => o.kind == PreparedDownloadKind.audio,
          )
          .toList();
      if (audio.isNotEmpty) {
        audio.sort((a, b) => _score(b).compareTo(_score(a)));
        return audio.first;
      }
      return prepared.defaultOption;
    }

    final List<PreparedDownloadOption> video = prepared.options
        .where(
          (PreparedDownloadOption o) => o.kind == PreparedDownloadKind.video,
        )
        .toList();
    if (video.isEmpty) {
      return prepared.defaultOption;
    }

    final List<PreparedDownloadOption> mp4WithAudio = video
        .where(_isMp4WithAudio)
        .toList();
    final List<PreparedDownloadOption> candidates = mp4WithAudio.isNotEmpty
        ? mp4WithAudio
        : video.where(_hasAudioTrack).toList();
    if (candidates.isEmpty) {
      throw const DownloadServiceException(
        'No MP4 video with audio is available for this link.',
      );
    }

    candidates.sort((a, b) => _score(b).compareTo(_score(a)));
    if (preset == QuickPresetOption.videoHigh) {
      return candidates.first;
    }
    if (preset == QuickPresetOption.videoLow) {
      return candidates.last;
    }
    return candidates[candidates.length ~/ 2];
  }

  static int _score(PreparedDownloadOption option) {
    final RegExpMatch? resMatch = RegExp(
      r'(\d{3,4})p',
    ).firstMatch(option.label.toLowerCase());
    if (resMatch != null) {
      return int.tryParse(resMatch.group(1) ?? '') ?? 0;
    }
    if (option.totalBytes != null && option.totalBytes! > 0) {
      final int kb = option.totalBytes! ~/ 1024;
      if (kb > 0) {
        return kb;
      }
    }
    return 0;
  }

  static bool _isMp4WithAudio(PreparedDownloadOption option) {
    return _isMp4(option) && _hasAudioTrack(option);
  }

  static bool _hasAudioTrack(PreparedDownloadOption option) {
    final String subtitle = option.subtitle.toLowerCase();
    if (subtitle.contains('video only')) {
      return false;
    }
    if (subtitle.contains('video + audio')) {
      return true;
    }
    return true;
  }

  static bool _isMp4(PreparedDownloadOption option) {
    final String fileName = option.fileName.toLowerCase();
    final String url = option.url.toLowerCase();
    final String subtitle = option.subtitle.toLowerCase();
    return fileName.endsWith('.mp4') ||
        url.contains('.mp4') ||
        subtitle.contains(' mp4 ') ||
        subtitle.startsWith('mp4 ') ||
        subtitle.contains('• mp4');
  }
}
