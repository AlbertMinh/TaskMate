  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:task_mate/screens/home_screen.dart';
  import '../services/auth_service.dart';
  import 'login_screen.dart';
  import 'WelcomeScreen.dart';

  class RegisterScreen extends StatefulWidget {
    const RegisterScreen({Key? key}) : super(key: key);

    @override
    State<RegisterScreen> createState() => _RegisterScreenState();
  }

  class _RegisterScreenState extends State<RegisterScreen> {
    final _email = TextEditingController();
    final _password = TextEditingController();
    final _confirm = TextEditingController();

    bool _loading = false;
    bool _obscurePassword = true;
    bool _obscureConfirm = true;

    String? _errorMessage;

    @override
    void initState() {
      super.initState();
      _email.addListener(_clearError);
      _password.addListener(_clearError);
      _confirm.addListener(_clearError);
    }

    void _clearError() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    }

    @override
    void dispose() {
      _email.dispose();
      _password.dispose();
      _confirm.dispose();
      super.dispose();
    }


    String _classifyErrorMessage(String raw) {
      final m = raw.toLowerCase();

      if (m.contains("already") || m.contains("exists"))
        return "Email already registered";

      if (m.contains("weak"))
        return "Password is too weak — try a stronger one";

      if (m.contains("invalid-email") || m.contains("email"))
        return "Invalid email format";

      return "Registration failed — please try again";
    }

    Future<void> _submit() async {
      final email = _email.text.trim();
      final pass = _password.text.trim();
      final confirm = _confirm.text.trim();

      if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
        setState(() => _errorMessage = "Please fill all fields");
        return;
      }
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        setState(() => _errorMessage = "Enter a valid email");
        return;
      }
      if (pass.length < 6) {
        setState(() => _errorMessage = "Password must be at least 6 characters");
        return;
      }
      if (pass != confirm) {
        setState(() => _errorMessage = "Passwords do not match");
        return;
      }

      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      try {
        final auth = context.read<AuthService>();
        final ok = await auth.register(email, pass);

        if (ok) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (r) => false,
          );
          return;
        }

        setState(() => _errorMessage = "Registration failed — try different email/password");

      } catch (e) {
        setState(() => _errorMessage = _classifyErrorMessage(e.toString()));

      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    InputDecoration _inputDecoration({
      required String hint,
      required IconData icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF262628),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      );
    }

    Widget _errorBanner() {
      if (_errorMessage == null) return const SizedBox.shrink();

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.redAccent.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                )),
            InkWell(
              onTap: () => setState(() => _errorMessage = null),
              child: const Icon(Icons.close, color: Colors.white70),
            )
          ],
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final bg = const Color(0xFF151516);
      final screenWidth = MediaQuery.of(context).size.width;

      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        );
                      },
                    )
                  ],
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Let's get",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          )),
                      Text("started",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 18),


                AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _errorBanner()),

                const SizedBox(height: 6),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(hint: "Email id", icon: Icons.email_outlined),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            hint: "Password",
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility, color: Colors.white54),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _confirm,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            hint: "Confirm Password",
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility, color: Colors.white54),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        SizedBox(
                          width: screenWidth,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                                : const Text("Sign up",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? ",
                          style: TextStyle(color: Colors.white70)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()));
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }
  }
