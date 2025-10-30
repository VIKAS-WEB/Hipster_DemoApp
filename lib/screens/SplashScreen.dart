// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'login_screen.dart';
import 'user_list_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    // Check persisted login state and navigate accordingly after the splash delay.
    final bool isLoggedIn = Hive.box('auth').get('isLoggedIn', defaultValue: false) as bool;
    Future.delayed(const Duration(seconds: 3), () {
      // Ensure widget is still mounted before using the BuildContext.
      if (!mounted) return;
      if (isLoggedIn) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserListScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 249, 251),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo/logo.jpg', width: 120),
              const SizedBox(height: 8),
              const Text('Secure Video Calling', style: TextStyle(fontSize: 16, color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}