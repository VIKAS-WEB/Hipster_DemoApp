import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hipster_videocallingapp/providers/auth_provider.dart';
import 'user_list_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the auth state for changes (isLoading, error)
    final authState = ref.watch(authProvider);
    // Get the device screen size for responsive design
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      // Use a Container with a gradient for a modern background
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)], // A "hipster" tech gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // Use SingleChildScrollView to prevent overflow when keyboard appears
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenSize.height),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. Logo/Icon
                       Image.asset(
                       'assets/logo/logo.jpg',
                        width: 100,
                        //color: Colors.white,
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.5),

                      const SizedBox(height: 16),

                      // 2. Title
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.5),

                      const SizedBox(height: 8),

                      // 3. Subtitle
                      Text(
                        'Log in to connect with your crew',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.5),

                      const SizedBox(height: 40),

                      // 4. Email Field
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icons.email_outlined,
                        ),
                        style: const TextStyle(color: Colors.black87),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email required';
                          if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Invalid email';
                          return null;
                        },
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.5),

                      const SizedBox(height: 16),

                      // 5. Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _buildInputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                        ),
                         style: const TextStyle(color: Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password required';
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.5),

                      const SizedBox(height: 24),

                      // 6. Error Message (fades in)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: authState.error != null ? 1.0 : 0.0,
                        child: Text(
                          authState.error ?? '',
                          style: const TextStyle(color: Colors.yellowAccent, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 8),

                      // 7. Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2E3192),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: authState.isLoading ? null : () { // Disable button when loading
                            if (_formKey.currentState!.validate()) {
                              ref.read(authProvider.notifier).login(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                                () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UserListScreen()),
                                ),
                              );
                            }
                          },
                          // Show loading indicator inside button
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF2E3192),
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 1.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent InputDecoration
  InputDecoration _buildInputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF2E3192)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // No border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E3192), width: 2), // Highlight on focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}