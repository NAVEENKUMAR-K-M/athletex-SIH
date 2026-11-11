import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/card.dart' as ui;
import '../widgets/custom_button.dart';

// Dashboards
import 'athlete_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final Function(String) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool _obscure = true;
  String? errorMessage;

  String selectedRole = 'athlete';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut(); // or: await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(onLogin: widget.onLogin)),
      (route) => false,
    );
  }

  // --- Fetch athlete data (adjust return type to your model if needed) ---
  Future<Map<String, dynamic>?> _getAthleteData(String uid) async {
    // Implement this in AuthService if you haven't yet.
    // It should read from Firestore or your backend.
    return await _authService.getAthleteData(uid);
  }

  // Navigate after login based on selected role
  Future<void> _goToDashboardFor(User user, String role) async {
    widget.onLogin(role);

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(onLogout: _handleLogout),
        ),
      );
      return;
    }

    // role == 'athlete' → load athlete data first
    setState(() => isLoading = true);
    try {
      final athleteData = await _getAthleteData(user.uid);
      if (!mounted) return;

      if (athleteData == null) {
        setState(() {
          errorMessage = 'Could not load athlete profile. Please try again.';
          isLoading = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AthleteDashboard(
            onLogout: _handleLogout,
            athleteData: athleteData, // <-- REQUIRED ARG PASSED
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load athlete data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _authService.logIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        await _goToDashboardFor(user, selectedRole);
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Login failed. Check credentials.';
          isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password.',
        'invalid-email' => 'Invalid email format.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Login failed: ${e.code}',
      };
      if (!mounted) return;
      setState(() {
        errorMessage = msg;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Unexpected error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        await _goToDashboardFor(user, selectedRole);
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Google login failed.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Google login error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ui.Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "SAI Performance Platform",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Login to continue",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade600),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => isLoading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade600),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),

                DropdownButton<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: isLoading ? null : (v) => setState(() => selectedRole = v!),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: Colors.grey.shade800,
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                if (isLoading)
                  const CircularProgressIndicator()
                else ...[
                  CustomButton(
                    text: "Login",
                    onPressed: _login,
                    backgroundColor: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Login with Google",
                    onPressed: _loginWithGoogle,
                    backgroundColor: Colors.blue.shade700,
                    icon: Icons.login,
                  ),
                ],

                const SizedBox(height: 12),

                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupScreen(
                                onSignupComplete: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        },
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
