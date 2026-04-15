import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/environment/app_environment.dart';

const String _downloadPortName = 'nexly_download_port';

class DownloadService {
  static const String galleryAlbumName = 'Nexly';

  final ReceivePort _receivePort = ReceivePort();
  final StreamController<DownloadTaskUpdate> _updatesController =
      StreamController<DownloadTaskUpdate>.broadcast();

  bool _isInitialized = false;
  Future<void>? _initFuture;

  Stream<DownloadTaskUpdate> get updates => _updatesController.stream;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    try {
      if (_isInitialized) {
        return;
      }

      IsolateNameServer.removePortNameMapping(_downloadPortName);
      IsolateNameServer.registerPortWithName(
        _receivePort.sendPort,
        _downloadPortName,
      );

      _receivePort.listen((dynamic data) {
        if (data is! List || data.length < 3) {
          return;
        }

        final String taskId = data[0] as String;
        final DownloadTaskStatus status = DownloadTaskStatus.fromInt(
          data[1] as int,
        );
        final int progress = data[2] as int;

        _updatesController.add(
          DownloadTaskUpdate(
            taskId: taskId,
            status: status,
            progress: progress,
          ),
        );
      });

      await FlutterDownloader.registerCallback(downloadCallbackEntryPoint);
      _isInitialized = true;
    } finally {
      _initFuture = null;
    }
  }

  Future<QueuedDownload> enqueueDirectMedia(String inputUrl) async {
    final PreparedDownload preparedDownload = await prepareDownload(inputUrl);
    return enqueuePreparedOption(preparedDownload.defaultOption);
  }

  Future<PreparedDownload> prepareDownload(String inputUrl) async {
    final String normalizedInput = _normalizeInput(inputUrl);
    if (_looksLikeInstagramShareToken(normalizedInput)) {
      throw const DownloadServiceException(
        'This looks like an Instagram share token, not a real reel link. Tap Copy Link in Instagram and paste that URL here.',
      );
    }

    final Uri? uri = Uri.tryParse(normalizedInput);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw const DownloadServiceException('Enter a valid http or https link.');
    }

    if (_isYoutubeLink(uri)) {
      try {
        return await _prepareYoutubeDownload(normalizedInput);
      } on DownloadServiceException {
        return _prepareBackendDownload(normalizedInput, uri);
      }
    }

    if (_isSocialPlatformLink(uri)) {
      return _prepareBackendDownload(normalizedInput, uri);
    }

    final _ProbeResult probe = await _probeLink(uri);

    if (!_looksLikeDirectMedia(probe.finalUri, probe.contentType)) {
      try {
        return await _prepareBackendDownload(normalizedInput, uri);
      } on DownloadServiceException {
        final _ResolvedMediaLink link = await _resolveFromPageMetadata(
          probe.finalUri,
        );
        final _PagePreview? preview = await _loadPagePreview(probe.finalUri);
        return _buildPreparedDownload(
          link: link,
          sourceLabel: _hostLabel(probe.finalUri),
          title: preview?.title,
          thumbnailUrl: preview?.thumbnailUrl,
        );
      }
    }

    final String fileName = _buildFileName(
      probe.finalUri,
      probe.contentDisposition,
      probe.contentType,
    );

    return _buildPreparedDownload(
      link: _ResolvedMediaLink(
        url: probe.finalUri.toString(),
        fileName: fileName,
      ),
      sourceLabel: _hostLabel(probe.finalUri),
    );
  }

  Future<QueuedDownload> enqueuePreparedOption(
    PreparedDownloadOption option,
  ) async {
    await init();
    final bool useAndroidPublicStorage = Platform.isAndroid;
    final _ResolvedMediaLink rawLink = _ResolvedMediaLink(
      url: option.url,
      fileName: option.fileName,
      headers: option.headers,
    );
    final Directory directory = await _resolveSaveDirectory();
    await directory.create(recursive: true);
    final String uniqueFileName = await _resolveUniqueFileName(
      directory,
      rawLink.fileName,
    );
    final _ResolvedMediaLink link = _ResolvedMediaLink(
      url: rawLink.url,
      fileName: uniqueFileName,
      headers: rawLink.headers,
    );

    final String? taskId = await FlutterDownloader.enqueue(
      url: link.url,
      savedDir: directory.path,
      fileName: link.fileName,
      headers: link.headers,
      showNotification: useAndroidPublicStorage,
      openFileFromNotification: useAndroidPublicStorage,
      saveInPublicStorage: useAndroidPublicStorage,
    );

    if (taskId == null) {
      throw const DownloadServiceException(
        'Failed to queue the download task.',
      );
    }

    return QueuedDownload(
      taskId: taskId,
      fileName: link.fileName,
      savedDir: useAndroidPublicStorage
          ? '/storage/emulated/0/Download'
          : directory.path,
      optionLabel: option.label,
      totalBytes: option.totalBytes,
    );
  }

  Future<DownloadTaskUpdate?> getTaskUpdate(String taskId) async {
    await init();
    final List<DownloadTask>? tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) {
      return null;
    }

    for (final DownloadTask task in tasks) {
      if (task.taskId == taskId) {
        return DownloadTaskUpdate(
          taskId: task.taskId,
          status: task.status,
          progress: task.progress,
        );
      }
    }

    return null;
  }

  Future<GallerySaveResult> saveVideoToGallery(String filePath) async {
    final bool hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final bool granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const DownloadServiceException(
          'Gallery access was denied. The video is still saved in the app storage path.',
        );
      }
    }

    try {
      await Gal.putVideo(filePath, album: galleryAlbumName);
      return const GallerySaveResult(
        albumName: galleryAlbumName,
        storedInGallery: true,
      );
    } on GalException catch (_) {
      throw const DownloadServiceException(
        'The video was downloaded, but it could not be added to the gallery album.',
      );
    }
  }

  Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isIOS) {
      final Directory directory = await getApplicationDocumentsDirectory();
      return Directory('${directory.path}/downloads');
    }

    if (Platform.isAndroid) {
      final Directory directory = await getApplicationDocumentsDirectory();
      return Directory('${directory.path}/downloads');
    }

    final Directory directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/downloads');
  }

  Future<String> _resolveUniqueFileName(
    Directory directory,
    String desiredFileName,
  ) async {
    String candidate = desiredFileName;
    final int extensionIndex = desiredFileName.lastIndexOf('.');
    final bool hasExtension =
        extensionIndex > 0 && extensionIndex < desiredFileName.length - 1;
    final String baseName = hasExtension
        ? desiredFileName.substring(0, extensionIndex)
        : desiredFileName;
    final String extension = hasExtension
        ? desiredFileName.substring(extensionIndex)
        : '';

    int counter = 1;
    while (await File('${directory.path}/$candidate').exists()) {
      candidate = '$baseName ($counter)$extension';
      counter++;
    }

    return candidate;
  }

  Future<PreparedDownload> _prepareYoutubeDownload(String inputUrl) async {
    final YoutubeExplode yt = YoutubeExplode();

    try {
      final Video video = await yt.videos.get(inputUrl);
      final StreamManifest manifest = await yt.videos.streams.getManifest(
        inputUrl,
        ytClients: <YoutubeApiClient>[
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
        ],
      );

      if (manifest.muxed.isEmpty) {
        throw const DownloadServiceException(
          'This YouTube video does not expose a direct muxed stream for app download.',
        );
      }

      final List<PreparedDownloadOption> options = <PreparedDownloadOption>[];
      final Set<String> seenLabels = <String>{};
      for (final MuxedStreamInfo stream in manifest.muxed.sortByBitrate()) {
        final String signature =
            '${stream.qualityLabel}_${stream.container.name}';
        if (!seenLabels.add(signature)) {
          continue;
        }

        options.add(
          PreparedDownloadOption(
            id: signature,
            kind: PreparedDownloadKind.video,
            label: stream.qualityLabel,
            subtitle:
                'Video + audio • ${stream.container.name.toUpperCase()} • ${_formatFileSize(stream.size.totalMegaBytes)}',
            fileName: _sanitizeFileName(
              '${video.title}.${stream.container.name}',
            ),
            url: stream.url.toString(),
            headers: _youtubeHeaders,
            totalBytes: stream.size.totalBytes,
          ),
        );
      }

      final Set<String> seenVideoOnlyLabels = <String>{};
      for (final VideoOnlyStreamInfo stream
          in manifest.videoOnly.sortByBitrate()) {
        final String signature =
            'video_only_${stream.qualityLabel}_${stream.container.name}';
        if (!seenVideoOnlyLabels.add(signature)) {
          continue;
        }

        options.add(
          PreparedDownloadOption(
            id: signature,
            kind: PreparedDownloadKind.video,
            label: stream.qualityLabel,
            subtitle:
                'Video only • ${stream.container.name.toUpperCase()} • ${_formatFileSize(stream.size.totalMegaBytes)}',
            fileName: _sanitizeFileName(
              '${video.title}_${stream.qualityLabel}.${stream.container.name}',
            ),
            url: stream.url.toString(),
            headers: _youtubeHeaders,
            totalBytes: stream.size.totalBytes,
          ),
        );
      }

      final Set<String> seenAudioLabels = <String>{};
      for (final AudioOnlyStreamInfo stream
          in manifest.audioOnly.sortByBitrate()) {
        final String audioLabel = _audioLabel(stream);
        final String signature = 'audio_${audioLabel}_${stream.container.name}';
        if (!seenAudioLabels.add(signature)) {
          continue;
        }

        options.add(
          PreparedDownloadOption(
            id: signature,
            kind: PreparedDownloadKind.audio,
            label: audioLabel,
            subtitle:
                'Audio only • ${_audioContainerLabel(stream)} • ${_formatFileSize(stream.size.totalMegaBytes)}',
            fileName: _sanitizeFileName(
              '${video.title}_audio.${_audioFileExtension(stream)}',
            ),
            url: stream.url.toString(),
            headers: _youtubeHeaders,
            totalBytes: stream.size.totalBytes,
          ),
        );
      }

      if (options.isEmpty) {
        throw const DownloadServiceException(
          'This YouTube video does not expose a direct muxed stream for app download.',
        );
      }

      return PreparedDownload(
        title: video.title,
        sourceLabel: 'YouTube',
        thumbnailUrl: video.thumbnails.maxResUrl,
        options: options,
      );
    } on YoutubeExplodeException {
      throw const DownloadServiceException(
        'This YouTube link could not be resolved right now.',
      );
    } catch (_) {
      throw const DownloadServiceException(
        'This YouTube link could not be resolved right now.',
      );
    } finally {
      yt.close();
    }
  }

  Future<PreparedDownload> _prepareBackendDownload(
    String inputUrl,
    Uri sourceUri,
  ) async {
    final _ResolvedMediaLink link = await _resolveViaBackend(inputUrl);
    final _PagePreview? preview = await _loadPagePreview(sourceUri);

    return _buildPreparedDownload(
      link: link,
      sourceLabel: _hostLabel(sourceUri),
      title: preview?.title,
      thumbnailUrl: preview?.thumbnailUrl,
    );
  }

  Future<_ResolvedMediaLink> _resolveFromPageMetadata(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile Safari/604.1',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');

      final HttpClientResponse response = await request.close();
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> element) => previous..addAll(element),
      );
      final String html = utf8.decode(bytes, allowMalformed: true);

      final String? mediaUrl = _extractFirstMetaContent(html, <String>[
        'og:video:secure_url',
        'og:video:url',
        'og:video',
        'og:audio:secure_url',
        'og:audio',
        'twitter:player:stream',
      ]);

      if (mediaUrl == null || mediaUrl.trim().isEmpty) {
        throw const DownloadServiceException(
          'This link does not expose a downloadable video source in-app. Some Instagram, Facebook, and TikTok links still require a backend extractor.',
        );
      }

      final Uri mediaUri = Uri.parse(mediaUrl.trim());
      final String title =
          _extractFirstMetaContent(html, <String>[
            'og:title',
            'twitter:title',
          ]) ??
          'video';

      final _ProbeResult mediaProbe = await _probeLink(mediaUri);
      final String fileName = _sanitizeFileName(
        _buildFileName(
          mediaProbe.finalUri,
          mediaProbe.contentDisposition,
          mediaProbe.contentType,
        ).replaceFirst('download', title),
      );

      return _ResolvedMediaLink(
        url: mediaProbe.finalUri.toString(),
        fileName: fileName,
      );
    } on SocketException {
      throw const DownloadServiceException('Unable to reach this server.');
    } on FormatException {
      throw const DownloadServiceException(
        'This page returned unreadable media metadata.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_ResolvedMediaLink> _resolveViaBackend(String inputUrl) async {
    final String endpointUrl = AppEnvironment.resolverEndpoint;
    if (endpointUrl.isEmpty) {
      throw const DownloadServiceException(
        'Resolver backend is not configured for this device.',
      );
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    try {
      final Uri endpoint = Uri.parse(endpointUrl);
      final HttpClientRequest request = await client.postUrl(endpoint);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(<String, String>{'url': inputUrl})));

      final HttpClientResponse response = await request.close();
      final String body = await utf8.decodeStream(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DownloadServiceException(_extractBackendErrorMessage(body));
      }

      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      final String resolvedUrl =
          (data['resolved_url'] as String?)?.trim() ?? '';
      final String fileName = (data['file_name'] as String?)?.trim() ?? '';

      if (resolvedUrl.isEmpty || fileName.isEmpty) {
        throw const DownloadServiceException(
          'Resolver backend returned an invalid response.',
        );
      }

      return _ResolvedMediaLink(
        url: resolvedUrl,
        fileName: _sanitizeFileName(fileName),
      );
    } on SocketException {
      throw DownloadServiceException(
        'Resolver backend is not reachable right now. Please try again shortly.',
      );
    } on FormatException {
      throw const DownloadServiceException(
        'Resolver backend returned unreadable data.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_PagePreview?> _loadPagePreview(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile Safari/604.1',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');

      final HttpClientResponse response = await request.close();
      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> element) => previous..addAll(element),
      );
      final String html = utf8.decode(bytes, allowMalformed: true);
      final String? title = _extractFirstMetaContent(html, <String>[
        'og:title',
        'twitter:title',
      ]);
      final String? thumbnailUrl = _extractFirstMetaContent(html, <String>[
        'og:image',
        'twitter:image',
      ]);

      if ((title == null || title.trim().isEmpty) &&
          (thumbnailUrl == null || thumbnailUrl.trim().isEmpty)) {
        return null;
      }

      return _PagePreview(
        title: title?.trim(),
        thumbnailUrl: thumbnailUrl?.trim(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<_ProbeResult> _probeLink(Uri uri) async {
    try {
      return await _sendProbeRequest(uri, headOnly: true);
    } catch (_) {
      return _sendProbeRequest(uri, headOnly: false);
    }
  }

  Future<_ProbeResult> _sendProbeRequest(
    Uri uri, {
    required bool headOnly,
  }) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final HttpClientRequest request = headOnly
          ? await client.headUrl(uri)
          : await client.getUrl(uri);

      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 VideoDownloaderApp',
      );

      if (!headOnly) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      }

      final HttpClientResponse response = await request.close();
      await response.drain<void>();

      final Uri finalUri = response.redirects.isEmpty
          ? uri
          : response.redirects.last.location;

      return _ProbeResult(
        finalUri: finalUri,
        contentType: response.headers.contentType?.mimeType ?? '',
        contentDisposition: response.headers.value('content-disposition') ?? '',
      );
    } on SocketException {
      throw const DownloadServiceException('Unable to reach this server.');
    } on HttpException {
      throw const DownloadServiceException('This link could not be verified.');
    } finally {
      client.close(force: true);
    }
  }

  bool _looksLikeDirectMedia(Uri uri, String contentType) {
    const List<String> extensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.mp3',
      '.m4a',
      '.aac',
    ];

    final String path = uri.path.toLowerCase();

    return contentType.startsWith('video/') ||
        contentType.startsWith('audio/') ||
        extensions.any(path.endsWith);
  }

  bool _isYoutubeLink(Uri uri) {
    final String host = uri.host.toLowerCase();

    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  bool _isSocialPlatformLink(Uri uri) {
    final String host = uri.host.toLowerCase();

    return host.contains('instagram.com') ||
        host.contains('facebook.com') ||
        host.contains('fb.watch') ||
        host.contains('tiktok.com') ||
        host.contains('vm.tiktok.com') ||
        host.contains('x.com') ||
        host.contains('twitter.com');
  }

  bool _looksLikeInstagramShareToken(String input) {
    final String normalized = input.trim().toLowerCase();

    return !normalized.startsWith('http://') &&
        !normalized.startsWith('https://') &&
        (normalized.startsWith('gsh=') || normalized.startsWith('igsh='));
  }

  String _normalizeInput(String input) {
    final String trimmed = input.trim();
    final RegExp urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final RegExpMatch? match = urlPattern.firstMatch(trimmed);
    final String extracted = match != null ? match.group(0)!.trim() : trimmed;
    final String withScheme = extracted.startsWith('www.')
        ? 'https://$extracted'
        : extracted;

    final Uri? uri = Uri.tryParse(withScheme);
    if (uri != null && _isYoutubeLink(uri)) {
      final String? videoId = _extractYoutubeVideoId(uri);
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$videoId';
      }
    }

    return withScheme;
  }

  String? _extractYoutubeVideoId(Uri uri) {
    final String host = uri.host.toLowerCase();
    final List<String> segments = uri.pathSegments;

    if (host.contains('youtu.be')) {
      if (segments.isNotEmpty) {
        return _sanitizeYoutubeId(segments.first);
      }
      return null;
    }

    final String? queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) {
      return _sanitizeYoutubeId(queryId);
    }

    if (segments.length >= 2 &&
        (segments.first == 'shorts' ||
            segments.first == 'embed' ||
            segments.first == 'live' ||
            segments.first == 'watch')) {
      return _sanitizeYoutubeId(segments[1]);
    }

    if (segments.isNotEmpty) {
      final String first = segments.first;
      if (first.length >= 11) {
        return _sanitizeYoutubeId(first);
      }
    }

    return null;
  }

  String? _sanitizeYoutubeId(String raw) {
    final String cleaned = raw
        .split('?')
        .first
        .split('&')
        .first
        .split('/')
        .first
        .trim();

    final RegExp idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
    return idPattern.hasMatch(cleaned) ? cleaned : null;
  }

  String _buildFileName(
    Uri uri,
    String contentDisposition,
    String contentType,
  ) {
    final RegExp utfPattern = RegExp("filename\\*=UTF-8''([^;]+)");
    final RegExp basicPattern = RegExp('filename="?([^"]+)"?');

    final RegExpMatch? utfMatch = utfPattern.firstMatch(contentDisposition);
    if (utfMatch != null) {
      return _sanitizeFileName(Uri.decodeFull(utfMatch.group(1)!));
    }

    final RegExpMatch? basicMatch = basicPattern.firstMatch(contentDisposition);
    if (basicMatch != null) {
      return _sanitizeFileName(basicMatch.group(1)!);
    }

    final String segment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download';
    if (segment.contains('.')) {
      return _sanitizeFileName(segment);
    }

    if (contentType.startsWith('video/')) {
      return _sanitizeFileName('$segment.mp4');
    }

    if (contentType.startsWith('audio/')) {
      return _sanitizeFileName('$segment.mp3');
    }

    return _sanitizeFileName('$segment.bin');
  }

  String _sanitizeFileName(String value) {
    final String cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'[#%]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'download.bin';
    }

    const int maxLength = 96;
    if (cleaned.length <= maxLength) {
      return cleaned;
    }

    final int lastDot = cleaned.lastIndexOf('.');
    if (lastDot <= 0 || lastDot >= cleaned.length - 1) {
      return cleaned.substring(0, maxLength).trim();
    }

    final String extension = cleaned.substring(lastDot);
    final int baseMaxLength = maxLength - extension.length;
    final String base = cleaned.substring(0, lastDot);
    final String trimmedBase = base.substring(
      0,
      baseMaxLength.clamp(1, base.length),
    );
    return '${trimmedBase.trim()}$extension';
  }

  PreparedDownload _buildPreparedDownload({
    required _ResolvedMediaLink link,
    required String sourceLabel,
    String? title,
    String? thumbnailUrl,
  }) {
    final String cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : _titleFromFileName(link.fileName);

    return PreparedDownload(
      title: cleanTitle,
      sourceLabel: sourceLabel,
      thumbnailUrl: thumbnailUrl,
      options: <PreparedDownloadOption>[
        PreparedDownloadOption(
          id: 'best_available',
          kind: PreparedDownloadKind.video,
          label: 'Best Available',
          subtitle: _labelFromFileName(link.fileName),
          fileName: link.fileName,
          url: link.url,
          headers: link.headers,
          totalBytes: null,
        ),
      ],
    );
  }

  String _titleFromFileName(String fileName) {
    final int lastDot = fileName.lastIndexOf('.');
    final String base = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    return base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  String _labelFromFileName(String fileName) {
    final String extension = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    return '$extension • Best available source';
  }

  String _formatFileSize(double megaBytes) {
    if (megaBytes >= 1024) {
      return '${(megaBytes / 1024).toStringAsFixed(2)} GB';
    }

    if (megaBytes >= 1) {
      return '${megaBytes.toStringAsFixed(1)} MB';
    }

    return '${(megaBytes * 1024).toStringAsFixed(0)} KB';
  }

  String _audioLabel(AudioOnlyStreamInfo stream) {
    final String quality = stream.qualityLabel.trim();
    if (quality.isNotEmpty) {
      return quality;
    }

    final int kbps = (stream.bitrate.bitsPerSecond / 1000).round();
    return '$kbps kbps';
  }

  String _audioContainerLabel(AudioOnlyStreamInfo stream) {
    if (stream.container.name.toLowerCase() == 'mp4') {
      return 'M4A';
    }
    return stream.container.name.toUpperCase();
  }

  String _audioFileExtension(AudioOnlyStreamInfo stream) {
    if (stream.container.name.toLowerCase() == 'mp4') {
      return 'm4a';
    }
    return stream.container.name.toLowerCase();
  }

  String _hostLabel(Uri uri) {
    final String host = uri.host.toLowerCase();
    if (host.contains('instagram')) {
      return 'Instagram';
    }
    if (host.contains('facebook') || host.contains('fb.')) {
      return 'Facebook';
    }
    if (host.contains('tiktok')) {
      return 'TikTok';
    }
    if (host.contains('youtube') || host.contains('youtu.be')) {
      return 'YouTube';
    }
    if (host.contains('twitter') || host.contains('x.com')) {
      return 'X';
    }
    return uri.host;
  }

  static const Map<String, String> _youtubeHeaders = <String, String>{
    'User-Agent': 'com.google.android.youtube/20.12.37 (Linux; U; Android 14)',
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  String? _extractFirstMetaContent(String html, List<String> propertyNames) {
    for (final String property in propertyNames) {
      final RegExp propertyFirst = RegExp(
        '<meta[^>]+(?:property|name)=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']+)["\'][^>]*>',
        caseSensitive: false,
      );
      final RegExp contentFirst = RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']${RegExp.escape(property)}["\'][^>]*>',
        caseSensitive: false,
      );

      final RegExpMatch? propertyMatch = propertyFirst.firstMatch(html);
      if (propertyMatch != null) {
        return _decodeHtml(propertyMatch.group(1)!);
      }

      final RegExpMatch? contentMatch = contentFirst.firstMatch(html);
      if (contentMatch != null) {
        return _decodeHtml(contentMatch.group(1)!);
      }
    }

    return null;
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&#x27;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _extractBackendErrorMessage(String body) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      final String? detail = data['detail'] as String?;
      if (detail != null && detail.trim().isNotEmpty) {
        final String normalized = detail.trim();

        if (normalized.contains('CERTIFICATE_VERIFY_FAILED')) {
          return 'Resolver hit an SSL verification issue while talking to the source platform. Restart the local resolver and try again.';
        }

        if (normalized.contains(
          'No directly downloadable progressive video stream',
        )) {
          return 'This link was resolved, but no direct downloadable video stream was available.';
        }

        if (normalized.length > 240) {
          return 'Resolver could not extract this link. Use the original Copy Link URL from the source app and try again.';
        }

        return normalized;
      }
    } catch (_) {}

    return 'Resolver backend could not process this link.';
  }
}

@pragma('vm:entry-point')
void downloadCallbackEntryPoint(String taskId, int status, int progress) {
  final SendPort? sendPort = IsolateNameServer.lookupPortByName(
    _downloadPortName,
  );
  sendPort?.send(<dynamic>[taskId, status, progress]);
}

class DownloadTaskUpdate {
  const DownloadTaskUpdate({
    required this.taskId,
    required this.status,
    required this.progress,
  });

  final String taskId;
  final DownloadTaskStatus status;
  final int progress;
}

class QueuedDownload {
  const QueuedDownload({
    required this.taskId,
    required this.fileName,
    required this.savedDir,
    required this.optionLabel,
    required this.totalBytes,
  });

  final String taskId;
  final String fileName;
  final String savedDir;
  final String optionLabel;
  final int? totalBytes;
}

class PreparedDownload {
  const PreparedDownload({
    required this.title,
    required this.sourceLabel,
    required this.options,
    this.thumbnailUrl,
  });

  final String title;
  final String sourceLabel;
  final String? thumbnailUrl;
  final List<PreparedDownloadOption> options;

  PreparedDownloadOption get defaultOption => options.first;
}

class PreparedDownloadOption {
  const PreparedDownloadOption({
    required this.id,
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.fileName,
    required this.url,
    this.headers = const <String, String>{},
    required this.totalBytes,
  });

  final String id;
  final PreparedDownloadKind kind;
  final String label;
  final String subtitle;
  final String fileName;
  final String url;
  final Map<String, String> headers;
  final int? totalBytes;
}

enum PreparedDownloadKind { video, audio }

class GallerySaveResult {
  const GallerySaveResult({
    required this.albumName,
    required this.storedInGallery,
  });

  final String albumName;
  final bool storedInGallery;
}

class DownloadServiceException implements Exception {
  const DownloadServiceException(this.message);

  final String message;
}

class _ResolvedMediaLink {
  const _ResolvedMediaLink({
    required this.url,
    required this.fileName,
    this.headers = const <String, String>{},
  });

  final String url;
  final String fileName;
  final Map<String, String> headers;
}

class _ProbeResult {
  const _ProbeResult({
    required this.finalUri,
    required this.contentType,
    required this.contentDisposition,
  });

  final Uri finalUri;
  final String contentType;
  final String contentDisposition;
}

class _PagePreview {
  const _PagePreview({this.title, this.thumbnailUrl});

  final String? title;
  final String? thumbnailUrl;
}
