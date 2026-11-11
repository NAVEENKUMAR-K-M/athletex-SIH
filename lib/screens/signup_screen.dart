import 'package:flutter/material.dart';
import '../widgets/card.dart' as ui;
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onSignupComplete;

  const SignupScreen({super.key, required this.onSignupComplete});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'athlete'; // Default role
  bool isLoading = false;
  String? errorMessage;

  final AuthService _authService = AuthService();

  Future<void> _signup() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _authService.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
        selectedRole,
      );

      setState(() {
        isLoading = false;
      });

      if (user != null) {
        setState(() {
          errorMessage = 'Signup successful! Redirecting...'; // Success message
        });
        await Future.delayed(const Duration(seconds: 2)); // Show for 2 seconds
        widget.onSignupComplete(); // Navigate
      } else {
        setState(() {
          errorMessage = 'Signup failed. Please try again.';
        });
      }
    } on FirebaseAuthException catch (e) {
      // Show specific Firebase errors
      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'This email is already registered. Try logging in or use a different email.';
          break;
        case 'weak-password':
          errorMsg = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'invalid-email':
          errorMsg = 'Invalid email format.';
          break;
        case 'operation-not-allowed':
          errorMsg = 'Email/password signup is not enabled. Contact support.';
          break;
        default:
          errorMsg = e.message ?? 'Signup failed: ${e.code}';
      }
      setState(() {
        errorMessage = errorMsg;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Unexpected error: $e';
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
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Create a new account",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
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
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
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
                DropdownButton<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value!;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: Colors.grey.shade800,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                if (isLoading)
                  const CircularProgressIndicator()
                else ...[
                  CustomButton(
                    text: "Sign Up",
                    onPressed: _signup,
                    backgroundColor: Colors.green.shade600,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Sign Up with Google",
                    onPressed: () async {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });
                      final user = await _authService.signInWithGoogle();
                      setState(() {
                        isLoading = false;
                      });
                      if (user != null) {
                        final role = await _authService.getUserRole(user.uid);
                        if (role != null) {
                          setState(() {
                            errorMessage = 'Signup successful! Redirecting...';
                          });
                          await Future.delayed(const Duration(seconds: 2));
                          widget.onSignupComplete(); // Navigate on success
                        } else {
                          setState(() {
                            errorMessage = 'Role not set for Google account. Contact support.';
                          });
                        }
                      } else {
                        setState(() {
                          errorMessage = 'Google signup failed.';
                        });
                      }
                    },
                    backgroundColor: Colors.blue.shade700,
                    icon: Icons.login, // Fixed: Valid IconData (sign-in arrow)
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Log in",
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