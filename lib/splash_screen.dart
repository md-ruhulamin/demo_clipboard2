import 'package:clipboard/audio_list_page.dart';
import 'package:flutter/material.dart';
class MyAppWrapper extends StatelessWidget {
  Future<void> _initializeApp() async {
    await Future.delayed(Duration(seconds: 3));
    // your init logic
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AudioListPage();
        } else {
          return const SplashLoadingScreen();
        }
      },
    );
  }
}
class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Please wait...", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
