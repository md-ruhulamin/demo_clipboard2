import 'package:clipboard/print_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class ThemeController extends GetxController {
  Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    PrintHelper.debugPrintWithLocation( "ThemeController toggleTheme ${isDark}");
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(themeMode.value);
  }
}
