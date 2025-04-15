import 'package:clipboard/print_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  void toggleTheme() {
    themeMode.value =
        themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}