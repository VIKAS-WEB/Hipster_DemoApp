import 'package:flutter/material.dart';
import 'package:hipster_videocallingapp/screens/SplashScreen.dart';
import 'screens/login_screen.dart';
import 'screens/user_list_screen.dart';

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChimeCall Pro',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen()
    );
  }
}