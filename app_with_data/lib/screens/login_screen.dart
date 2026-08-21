import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../core/database_helper.dart';
import '../main.dart'; // To navigate to MainNavigation

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  
  bool _isLoading = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricPreference();
  }

  // 1. Check if the user turned on the switch in Settings
  Future<void> _checkBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('use_biometrics') ?? false;
    });

    // If enabled, automatically prompt for Face/FingerdebugPrint right away!
    if (_biometricsEnabled) {
      _authenticateWithBiometrics();
    }
  }

  // 2. Trigger the Native Android Biometric Scanner
  // 2. Trigger the Native Android Biometric Scanner
  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        // Stripped down to the universally accepted syntax
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Scan your fingerdebugPrint or face to login',
        );

        if (didAuthenticate && mounted) {
          _navigateToHome();
        }
      }
    } catch (e) {
      debugPrint("Biometric Error: $e");
    }
  }

  // 3. Traditional Username & Password Login
  Future<void> _loginWithPassword() async {
    setState(() => _isLoading = true);
    
    String user = _userCtrl.text.trim();
    String pass = _passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter credentials')));
      setState(() => _isLoading = false);
      return;
    }

    // Hash the entered password to check against database
    final bytes = utf8.encode(pass);
    final hashedPassword = sha256.convert(bytes).toString();

    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users', 
      where: 'username = ? AND password_hash = ? AND is_deleted = 0',
      whereArgs: [user, hashedPassword]
    );

    if (result.isNotEmpty && mounted) {
      _navigateToHome();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Username or Password', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    }
    setState(() => _isLoading = false);
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Futuristic Logo Placeholder
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2AA2B8).withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.lock_outline, size: 80, color: Color(0xFF2AA2B8)),
              ),
              const SizedBox(height: 30),
              
              const Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text("Sign in to continue to Billing System", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // Login Form
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person)),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.password)),
                onSubmitted: (_) => _loginWithPassword(), // Hit enter on keyboard to login
              ),
              const SizedBox(height: 30),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA2B8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _loginWithPassword,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),

              // Biometric Manual Button (Appears if enabled)
              if (_biometricsEnabled)
                TextButton.icon(
                  icon: const Icon(Icons.fingerprint, size: 30, color: Colors.white70),
                  label: const Text("Use Biometrics", style: TextStyle(color: Colors.white70)),
                  onPressed: _authenticateWithBiometrics,
                )
            ],
          ),
        ),
      ),
    );
  }
}