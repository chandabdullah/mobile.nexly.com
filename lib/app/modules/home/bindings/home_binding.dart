import 'package:get/get.dart';

import '../../../data/services/download_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../../data/services/share_intent_service.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        Get.find<DownloadService>(),
        Get.find<ShareIntentService>(),
        Get.find<LocalNotificationService>(),
      ),
    );
  }
}
