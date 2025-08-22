import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../models/user_model.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        _showSnackBar(result.message, isError: false);

        // DEBUG: Print user information
        print('Login successful!');
        print('User: ${result.user}');
        print('User type: ${result.user?.userType}');
        print('Is admin: ${result.user?.userType == UserType.admin}');

        // Check user type and redirect accordingly
        if (result.user != null) {
          if (result.user!.userType == UserType.admin) {
            print('Redirecting to admin panel...');
            // Redirect to admin panel
            Navigator.pushReplacementNamed(context, '/admin');
          } else {
            print('Redirecting to home...');
            // Redirect to home for buyers and sellers
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        } else {
          print('User data is null, redirecting to home...');
          // Fallback: redirect to home if user data is null
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // GOOGLE SIGN-IN - FIXED METHOD CALL
  Future<void> _handleGoogleLogin() async {
    try {
      final result = await AuthService.loginWithGoogle(); // No parameters needed
      if (!mounted) return;
      if (result.success) {
        _showSnackBar('Google login successful!');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Google login failed: $e', isError: true);
    }
  }

  // FACEBOOK SIGN-IN
  Future<void> _handleFacebookLogin() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final accessToken = result.accessToken!.token;
        // Send accessToken to your backend for verification & login/signup
        final authResult = await AuthService.loginWithFacebook(accessToken);
        if (!mounted) return;
        if (authResult.success) {
          _showSnackBar('Facebook login successful!');
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else {
          _showSnackBar(authResult.message, isError: true);
        }
      } else {
        _showSnackBar('Facebook login cancelled or failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Facebook login failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Welcome Back Section
                _buildWelcomeSection(),

                const SizedBox(height: 48),

                // Login Form
                _buildLoginForm(),

                const SizedBox(height: 24),

                // Login Button
                CustomButton(
                  text: 'Login',
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Divider
                _buildDivider(),

                const SizedBox(height: 24),

                // OAuth Buttons
                _buildOAuthButtons(),

                const SizedBox(height: 24),

                // Sign Up Link
                _buildSignUpLink(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // App Logo
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset(
              'images/logo.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Removed the duplicate child: Icon - Container can only have one child
      ),

      const SizedBox(height: 24),

      // Welcome Text
      Text(
        'Welcome Back!',
        style: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        'Sign in to your account to continue shopping',
        style: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    ],
  );
}

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Email/Phone Field
        CustomTextField(
          controller: _emailController,
          label: 'Email or Phone',
          hint: 'Enter your email or phone number',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email or phone number';
            }
            return null;
          },
        ),

        const SizedBox(height: 20),

        // Password Field
        CustomTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Forgot Password Button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/reset_password');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildOAuthButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Image.asset('images/google.png', height: 24), // Add google_logo.png to your images
            label: const Text('Continue with Google'),
            onPressed: _handleGoogleLogin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Image.asset('images/facebook.jpeg', height: 24), // Add facebook_logo.png to your images
            label: const Text('Continue with Facebook'),
            onPressed: _handleFacebookLogin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.signup);
                },
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
