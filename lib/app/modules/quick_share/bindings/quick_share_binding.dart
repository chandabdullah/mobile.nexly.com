import 'package:get/get.dart';

import '../../../data/services/download_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/share_intent_service.dart';
import '../controllers/quick_share_controller.dart';

class QuickShareBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QuickShareController>(
      () => QuickShareController(
        Get.find<DownloadService>(),
        Get.find<ShareIntentService>(),
        Get.find<LocalNotificationService>(),
      ),
    );
  }
}
