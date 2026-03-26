import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/data/services/local_notification_service.dart';
import 'app/data/services/download_service.dart';
import 'app/data/services/share_intent_service.dart';
import 'app/core/theme/app_theme.dart';
import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);
  final shareIntentService = ShareIntentService();
  final bool isQuickShareLaunch = await shareIntentService.isQuickShareLaunch();
  await shareIntentService.warmUpInitialSharedText();
  final localNotificationService = LocalNotificationService();
  final downloadService = DownloadService();
  Get.put(localNotificationService, permanent: true);
  Get.put(downloadService, permanent: true);
  Get.put(shareIntentService, permanent: true);
  runApp(
    MyApp(
      initialRoute: isQuickShareLaunch
          ? '/quick-share'
          : (shareIntentService.hasPrimedSharedText
                ? '/home'
                : AppPages.INITIAL),
    ),
  );

  unawaited(_warmBackgroundServices(localNotificationService, downloadService));
}

Future<void> _warmBackgroundServices(
  LocalNotificationService localNotificationService,
  DownloadService downloadService,
) async {
  await localNotificationService.init();
  await _ensureNotificationPermission(localNotificationService);
  await downloadService.init();
}

Future<void> _ensureNotificationPermission(
  LocalNotificationService localNotificationService,
) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await localNotificationService.requestPermissions();
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final PermissionStatus status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
    await localNotificationService.requestPermissions();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Nexly',
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
    );
  }
}
