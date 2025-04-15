// main.dart
import 'package:clipboard/audio_controller.dart';
import 'package:clipboard/splash_screen.dart';
import 'package:clipboard/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
Get.put(ThemeController());
  Get.put(AudioController());
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
   MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
final ThemeController themeController = Get.put(ThemeController());
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,

     

      title: 'Flutter Demo',
     theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeController.themeMode.value,
      home: MyAppWrapper(),
    );
  }
  final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.deepPurple,
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.black,
    iconTheme: IconThemeData(color: Colors.yellow), // AppBar icons
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
  ),
  iconTheme: IconThemeData(
    color: Colors.yellow, // All icons yellow
  ),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    bodySmall: TextStyle(color: Colors.white),
    titleLarge: TextStyle(color: Colors.white),
    titleMedium: TextStyle(color: Colors.white),
    titleSmall: TextStyle(color: Colors.white),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.yellow,
    foregroundColor: Colors.black,
  ),
);

}
