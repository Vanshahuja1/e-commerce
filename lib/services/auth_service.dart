

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '/models/user_model.dart';

class AuthService {
  static const String _baseUrl = 'https://backend-ecommerce-app-co1r.onrender.com/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _userIdKey = 'user_id';
  static const String _isLoggedInKey = 'is_logged_in';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '976252022553-q0l9udck9q0m18fhqcfnioe4qe20hike.apps.googleusercontent.com', // Replace with your actual Web Client ID
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Get current user from local storage
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);

    if (userString != null) {
      final userMap = jsonDecode(userString);
      return UserModel.fromJson(userMap);
    }

    return null;
  }

  /// Get current user from server
  static Future<AuthResult> getCurrentUserFromServer() async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(
          success: false,
          message: 'No authentication token found',
        );
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userModel = UserModel.fromJson(data['user']);
        await _saveUserData(userModel);

        return AuthResult(
          success: true,
          message: 'User data retrieved successfully',
          user: userModel,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Failed to get user data',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Login user
  static Future<AuthResult> login(String emailOrPhone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailOrPhone': emailOrPhone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userModel = UserModel.fromJson(data['user']);

        await _saveUserData(userModel);
        await _saveToken(data['token']);

        return AuthResult(
          success: true,
          message: data['message'],
          user: userModel,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Register new user (for OTP verification)
  static Future<AuthResult> signup(String name, String email, String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Account created! Please verify your email with the OTP sent.',
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Signup failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Verify OTP after signup
  static Future<AuthResult> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final userModel = UserModel.fromJson(data['user']);

        await _saveUserData(userModel);
        await _saveToken(data['token']);

        return AuthResult(
          success: true,
          message: data['message'] ?? 'Email verified successfully!',
          user: userModel,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Invalid OTP. Please try again.',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Resend OTP
  static Future<AuthResult> resendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return AuthResult(
          success: true,
          message: data['message'] ?? 'OTP sent successfully!',
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Failed to resend OTP. Please try again.',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Login with Google - WORKS WITHOUT FIREBASE
  static Future<AuthResult> loginWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In process...');
      
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      
      // Attempt sign in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthResult(
          success: false,
          message: 'Google Sign-In was cancelled',
        );
      }

      debugPrint('Google user obtained: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult(
          success: false,
          message: 'Failed to get Google ID token',
        );
      }

      debugPrint('Google ID token obtained, sending to YOUR Node.js backend...');

      // Send to YOUR Node.js backend (not Firebase)
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      
      final data = jsonDecode(response.body);
      
      debugPrint('Backend response: ${response.statusCode} - ${data.toString()}');
      
      if (response.statusCode == 200 && data['success']) {
        final userModel = UserModel.fromJson(data['user']);
        await _saveUserData(userModel);
        await _saveToken(data['token']);
        
        return AuthResult(
          success: true, 
          message: data['message'] ?? 'Google authentication successful!', 
          user: userModel
        );
      } else {
        return AuthResult(
          success: false, 
          message: data['message'] ?? 'Google authentication failed on server'
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      
      String errorMessage = 'Google authentication failed';
      
      if (e.toString().contains('ApiException')) {
        if (e.toString().contains('10')) {
          errorMessage = 'Google Sign-In configuration error. Please check SHA-1 fingerprints and package name.';
        } else if (e.toString().contains('7')) {
          errorMessage = 'Network error during Google Sign-In. Please check your internet connection.';
        } else if (e.toString().contains('12501')) {
          errorMessage = 'Google Sign-In was cancelled.';
        }
      }
      
      return AuthResult(
        success: false, 
        message: '$errorMessage\nError details: ${e.toString()}'
      );
    }
  }

  /// Login with Facebook
  static Future<AuthResult> loginWithFacebook(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/facebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success']) {
        final userModel = UserModel.fromJson(data['user']);
        await _saveUserData(userModel);
        await _saveToken(data['token']);
        
        return AuthResult(
          success: true, 
          message: data['message'] ?? 'Facebook authentication successful!', 
          user: userModel
        );
      } else {
        return AuthResult(
          success: false, 
          message: data['message'] ?? 'Facebook authentication failed'
        );
      }
    } catch (e) {
      return AuthResult(
        success: false, 
        message: 'Network error during Facebook authentication: ${e.toString()}'
      );
    }
  }

  /// Become a seller
  static Future<AuthResult> becomeSeller({
    required String storeName,
    required String storeAddress,
    String? businessLicense,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(
          success: false,
          message: 'Authentication required',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/become-seller'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'storeName': storeName,
          'storeAddress': storeAddress,
          'businessLicense': businessLicense,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        if (data['user'] != null) {
          final userModel = UserModel.fromJson(data['user']);
          await _saveUserData(userModel);
          
          return AuthResult(
            success: true,
            message: data['message'],
            user: userModel,
          );
        }

        return AuthResult(
          success: true,
          message: data['message'],
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] ?? 'Failed to become seller',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Save user data to local storage
  static Future<void> _saveUserData(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_userIdKey, user.id);
    await prefs.setBool(_isLoggedInKey, true);
  }

  /// Save token to local storage
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Sign out from Google
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }

    // Clear all auth data
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_userIdKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  /// Get auth token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
}

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}
