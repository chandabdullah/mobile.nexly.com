import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();

    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (Get.currentRoute != Routes.SPLASH) {
        return;
      }
      Get.offNamed(Routes.HOME);
    });
  }
}
