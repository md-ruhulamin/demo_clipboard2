import 'package:clipboard/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});
  final ThemeController themeController = Get.find();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //   backgroundColor: themeController.isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            //color: themeController.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,

      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SettingItem(title: 'Get Premium', icon: Icons.monetization_on),

            SizedBox(height: 20),
            InkWell(
              onTap: () {
                print("Clicked Theme Button");
              themeController.toggleTheme();
              },
              child: SettingItem(
                title: 'Switch Theme',
                icon:themeController.isDarkMode? Icons.dark_mode:Icons.light,
              ),
            ),

            
          ],
        ),
      ),
    );
  }
}

class SettingItem extends StatelessWidget {
  final String title;
  final IconData icon;
  SettingItem({super.key, required this.title, required this.icon});
  final ThemeController themeController = Get.find();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        //   color: themeController.isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      padding: EdgeInsets.all(8.0),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 30),
              SizedBox(width: 10),
              Text(
                title,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  //     color: themeController.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
