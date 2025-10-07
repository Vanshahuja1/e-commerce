import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

enum ResetPasswordStep {
  enterEmail,
  enterOTP,
  enterNewPassword,
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ResetPasswordStep _currentStep = ResetPasswordStep.enterEmail;
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _userEmail = '';
  String _resetToken = '';

  // Base URL - Change this to your backend URL
  static const String baseUrl = 'https://e-com-backend-x67v.onrender.com/api';

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': _emailController.text.trim(),
        }),
      );

      if (!mounted) return;

      final data = json.decode(response.body);
      print('Send OTP Response: $data'); // Debug log

      if (response.statusCode == 200) {
        _userEmail = _emailController.text.trim();
        setState(() => _currentStep = ResetPasswordStep.enterOTP);
        _showSnackBar('OTP sent to your email!', isError: false);
      } else {
        _showSnackBar(data['error'] ?? 'Failed to send OTP. Please try again.', isError: true);
      }
    } catch (e) {
      print('Send OTP Error: $e'); // Debug log
      if (mounted) {
        _showSnackBar('Network error. Please check your connection.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': _userEmail,
          'otp': _otpController.text.trim(),
        }),
      );

      if (!mounted) return;

      final data = json.decode(response.body);
      print('Verify OTP Response: $data'); // Debug log

      if (response.statusCode == 200) {
        _resetToken = data['token'] ?? ''; // Store reset token
        setState(() => _currentStep = ResetPasswordStep.enterNewPassword);
        _showSnackBar('OTP verified successfully!', isError: false);
      } else {
        _showSnackBar(data['error'] ?? 'Invalid or expired OTP', isError: true);
      }
    } catch (e) {
      print('Verify OTP Error: $e'); // Debug log
      if (mounted) {
        _showSnackBar('Network error. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': _userEmail,
          'token': _resetToken,
          'password': _newPasswordController.text,
        }),
      );

      if (!mounted) return;

      final data = json.decode(response.body);
      print('Reset Password Response: $data'); // Debug log

      if (response.statusCode == 200) {
        _showSnackBar('Password reset successfully!', isError: false);
        
        // Show success dialog
        _showSuccessDialog();
      } else {
        _showSnackBar(data['error'] ?? 'Failed to reset password', isError: true);
      }
    } catch (e) {
      print('Reset Password Error: $e'); // Debug log
      if (mounted) {
        _showSnackBar('Network error. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Success!',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Your password has been reset successfully. You can now login with your new password.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Go to Login',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case ResetPasswordStep.enterEmail:
        return 'Reset Password';
      case ResetPasswordStep.enterOTP:
        return 'Verify OTP';
      case ResetPasswordStep.enterNewPassword:
        return 'New Password';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case ResetPasswordStep.enterEmail:
        return 'Enter your email address to receive a verification code';
      case ResetPasswordStep.enterOTP:
        return 'Enter the 6-digit code sent to\n$_userEmail';
      case ResetPasswordStep.enterNewPassword:
        return 'Create a strong new password for your account';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header Section
                _buildHeaderSection(),

                const SizedBox(height: 40),

                // Step Indicator
                _buildStepIndicator(),

                const SizedBox(height: 40),

                // Current Step Form
                _buildCurrentStepForm(),

                const SizedBox(height: 32),

                // Action Button
                _buildActionButton(),

                const SizedBox(height: 24),

                // Additional Actions
                _buildAdditionalActions(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Icon(
            _currentStep == ResetPasswordStep.enterEmail
                ? Icons.email_outlined
                : _currentStep == ResetPasswordStep.enterOTP
                    ? Icons.security_outlined
                    : Icons.lock_reset_outlined,
            size: 28,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          _getStepTitle(),
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        // Description
        Text(
          _getStepDescription(),
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, _currentStep.index >= 0),
        _buildStepLine(_currentStep.index >= 1),
        _buildStepDot(1, _currentStep.index >= 1),
        _buildStepLine(_currentStep.index >= 2),
        _buildStepDot(2, _currentStep.index >= 2),
      ],
    );
  }

  Widget _buildStepDot(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey[300],
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: isActive && step < _currentStep.index
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '${step + 1}',
                style: GoogleFonts.inter(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppColors.primary : Colors.grey[300],
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildCurrentStepForm() {
    switch (_currentStep) {
      case ResetPasswordStep.enterEmail:
        return _buildEmailForm();
      case ResetPasswordStep.enterOTP:
        return _buildOTPForm();
      case ResetPasswordStep.enterNewPassword:
        return _buildNewPasswordForm();
    }
  }

  Widget _buildEmailForm() {
    return CustomTextField(
      controller: _emailController,
      label: 'Email Address',
      hint: 'Enter your registered email',
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.email_outlined,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email address';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildOTPForm() {
    return Column(
      children: [
        CustomTextField(
          controller: _otpController,
          label: 'Verification Code',
          hint: 'Enter 6-digit code',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.security_outlined,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the verification code';
            }
            if (value.length != 6) {
              return 'Verification code must be 6 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _handleSendOTP,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Resend OTP',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPasswordForm() {
    return Column(
      children: [
        CustomTextField(
          controller: _newPasswordController,
          label: 'New Password',
          hint: 'Enter your new password',
          obscureText: _obscureNewPassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _obscureNewPassword = !_obscureNewPassword);
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a new password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
              return 'Password must contain uppercase, lowercase and number';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          hint: 'Re-enter your new password',
          obscureText: _obscureConfirmPassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your new password';
            }
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Password must be at least 8 characters with uppercase, lowercase and number',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    VoidCallback? onPressed;

    switch (_currentStep) {
      case ResetPasswordStep.enterEmail:
        buttonText = 'Send Verification Code';
        onPressed = _handleSendOTP;
        break;
      case ResetPasswordStep.enterOTP:
        buttonText = 'Verify Code';
        onPressed = _handleVerifyOTP;
        break;
      case ResetPasswordStep.enterNewPassword:
        buttonText = 'Reset Password';
        onPressed = _handleResetPassword;
        break;
    }

    return CustomButton(
      text: buttonText,
      onPressed: onPressed,
      isLoading: _isLoading,
    );
  }

  Widget _buildAdditionalActions() {
    if (_currentStep == ResetPasswordStep.enterEmail) {
      return Center(
        child: TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
          child: RichText(
            text: TextSpan(
              text: 'Remember your password? ',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: 'Back to Login',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}