import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminResult {
  final bool isAdmin;
  final String? adminLevel; // admin1, admin2, admin3
  final String message;

  AdminResult({
    required this.isAdmin,
    this.adminLevel,
    this.message = '',
  });
}

class SellerResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final List<dynamic>? items;
  final Map<String, dynamic>? item;

  const SellerResult({
    required this.success,
    required this.message,
    this.data,
    this.items,
    this.item,
  });
}

class AdminService {
  // Admin credentials from environment variables
  static final Map<String, String> _adminCredentials = {
    Platform.environment['ADMIN1_EMAIL'] ?? '':
        Platform.environment['ADMIN1_PASSWORD'] ?? '',
    Platform.environment['ADMIN2_EMAIL'] ?? '':
        Platform.environment['ADMIN2_PASSWORD'] ?? '',
    Platform.environment['ADMIN3_EMAIL'] ?? '':
        Platform.environment['ADMIN3_PASSWORD'] ?? '',
  };

  // Map to identify admin levels
  static final Map<String, String> _adminLevels = {
    Platform.environment['ADMIN1_EMAIL'] ?? '': 'admin1',
    Platform.environment['ADMIN2_EMAIL'] ?? '': 'admin2',
    Platform.environment['ADMIN3_EMAIL'] ?? '': 'admin3',
  };

  static const String _baseUrl =
      'https://e-com-backend-x67v.onrender.com/api';

  static const Duration _timeout = Duration(seconds: 30);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // =============================================================================
  // ADMIN AUTHENTICATION
  // =============================================================================

  /// Check if the provided email and password match any admin credentials
  static Future<AdminResult> checkAdminLogin(
      String email, String password) async {
    try {
      // Remove empty keys that might exist due to missing env variables
      final validCredentials = Map<String, String>.from(_adminCredentials)
        ..removeWhere((key, value) => key.isEmpty || value.isEmpty);

      if (validCredentials.containsKey(email)) {
        if (validCredentials[email] == password) {
          final adminLevel = _adminLevels[email];
          return AdminResult(
            isAdmin: true,
            adminLevel: adminLevel,
            message: 'Admin authentication successful',
          );
        } else {
          return AdminResult(
            isAdmin: false,
            message: 'Invalid admin password',
          );
        }
      }

      // Not an admin email
      return AdminResult(
        isAdmin: false,
        message: 'Not an admin account',
      );
    } catch (e) {
      return AdminResult(
        isAdmin: false,
        message: 'Admin authentication error: ${e.toString()}',
      );
    }
  }

  /// Check if current user is admin (for route protection)
  static bool isCurrentUserAdmin() {
    return false;
  }

  /// Get all configured admin emails (for debugging purposes)
  static List<String> getConfiguredAdmins() {
    return _adminCredentials.keys
        .where(
            (email) => email.isNotEmpty && _adminCredentials[email]!.isNotEmpty)
        .toList();
  }

  /// Validate environment variables are properly set
  static bool validateAdminConfiguration() {
    final validAdmins = getConfiguredAdmins();
    return validAdmins.isNotEmpty;
  }

  // =============================================================================
  // ORDER MANAGEMENT
  // =============================================================================

  // Get all orders for admin
  static Future<List<Order>> getAllOrders() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      // Use the regular orders endpoint with a high limit to get all orders
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/orders?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final orders = (data['orders'] as List)
              .map((order) => Order.fromJson(order))
              .toList();
          return orders;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch orders');
        }
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user order history
  static Future<List<Order>> getUserOrderHistory(String userId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/users/$userId/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = (data['orders'] as List)
            .map((order) => Order.fromJson(order))
            .toList();
        return orders;
      } else {
        throw Exception('Failed to fetch user orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get user details
  static Future<UserDetails> getUserDetails(String userId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserDetails.fromJson(data['user']);
      } else {
        throw Exception('Failed to fetch user details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generate invoice for an order
  static Future<String> generateInvoice(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/orders/$orderId/invoice'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['invoiceUrl'] ?? data['pdfUrl'] ?? '';
      } else {
        throw Exception('Failed to generate invoice: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Download invoice
  static Future<List<int>> downloadInvoice(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/orders/$orderId/invoice/download'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download invoice: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // =============================================================================
  // PRODUCT MANAGEMENT (INTEGRATED FROM SELLER SERVICE)
  // =============================================================================

  // Get all products
  static Future<List<Product>> getAllProducts() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final itemsList =
            data['items'] ?? data['products'] ?? data['data'] ?? [];
        return itemsList.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Add new product (integrated from seller service)
  static Future<SellerResult> addProduct(
      Map<String, dynamic> productData) async {
    final token = await _getToken();
    if (token == null) {
      return const SellerResult(
        success: false,
        message: 'Authentication required',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/items'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(productData),
          )
          .timeout(_timeout);

      return _handleResponse(response, 'Product added successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  // Update product (integrated from seller service)
  static Future<SellerResult> updateProduct(
      String productId, Map<String, dynamic> productData) async {
    final token = await _getToken();
    if (token == null) {
      return const SellerResult(
        success: false,
        message: 'Authentication required',
      );
    }

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/items/$productId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(productData),
          )
          .timeout(_timeout);

      return _handleResponse(response, 'Product updated successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  // Delete product (integrated from seller service)
  static Future<SellerResult> deleteProduct(String productId) async {
    final token = await _getToken();
    if (token == null) {
      return const SellerResult(
        success: false,
        message: 'Authentication required',
      );
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/items/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      return _handleResponse(response, 'Product deleted successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  // Toggle product availability
  static Future<bool> toggleProductAvailability(
      String productId, bool isAvailable) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/items/$productId/status'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'isAvailable': isAvailable}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // =============================================================================
  // SELLER MANAGEMENT (INTEGRATED FROM SELLER SERVICE)
  // =============================================================================

  /// Submit seller request (integrated from seller service)
  static Future<SellerResult> submitSellerRequest(
      Map<String, String> sellerData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const SellerResult(
          success: false,
          message: 'Authentication required. Please login first.',
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/become-seller'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'storeName': sellerData['storeName'],
              'storeAddress': sellerData['storeAddress'],
              'businessLicense': sellerData['businessLicense'],
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response, 'Seller request submitted successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get all seller requests
  static Future<List<SellerRequest>> getSellerRequests({String? status}) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      String url = '$_baseUrl/admin/seller-requests?limit=100';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final requests = (data['requests'] as List)
            .map((request) => SellerRequest.fromJson(request))
            .toList();
        return requests;
      } else {
        throw Exception(
            'Failed to fetch seller requests: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Approve seller request
  static Future<bool> approveSellerRequest(String requestId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/admin/seller-requests/$requestId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Reject seller request
  static Future<bool> rejectSellerRequest(
      String requestId, String reason) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/seller-requests/$requestId/reject'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'rejectionReason': reason}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get all sellers
  static Future<List<Seller>> getAllSellers() async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/sellers?limit=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sellers = (data['sellers'] as List)
            .map((seller) => Seller.fromJson(seller))
            .toList();
        return sellers;
      } else {
        throw Exception('Failed to fetch sellers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get seller items by seller ID
  static Future<List<Product>> getSellerItems(String sellerId) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/sellers/$sellerId/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List)
            .map((item) => Product.fromJson(item))
            .toList();
        return items;
      } else {
        throw Exception('Failed to fetch seller items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get current user seller items (integrated from seller service)
  static Future<SellerResult> getMySellerItems() async {
    final token = await _getToken();
    if (token == null) {
      return const SellerResult(
        success: false,
        message: 'Authentication required',
      );
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/items/my-items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      return _handleResponse(response, 'Items retrieved successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Add item for a seller (admin can add items for any seller)
  static Future<SellerResult> addSellerItem(
      String sellerId, Map<String, dynamic> itemData) async {
    final token = await _getToken();
    if (token == null) {
      return const SellerResult(
        success: false,
        message: 'Authentication required',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/admin/sellers/$sellerId/items'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(itemData),
          )
          .timeout(_timeout);

      return _handleResponse(response, 'Item added successfully');
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Deactivate/activate seller
  static Future<bool> toggleSellerStatus(String sellerId, bool isActive) async {
    final token = await _getToken();
    if (token == null) throw Exception('No authentication token found');

    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/admin/sellers/$sellerId/status'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'isActive': isActive}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Check if current user can become a seller (integrated from seller service)
  static Future<SellerResult> checkSellerEligibility() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return const SellerResult(
          success: false,
          message: 'Please login first',
        );
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        // Check if user is already a seller
        if (user['userType'] == 'seller') {
          return const SellerResult(
            success: false,
            message: 'You are already a seller',
          );
        }

        // Check if user has a pending request
        if (user['sellerRequestStatus'] == 'pending') {
          return const SellerResult(
            success: false,
            message: 'You already have a pending seller request',
          );
        }

        // Check if user's previous request was rejected
        if (user['sellerRequestStatus'] == 'rejected') {
          return const SellerResult(
            success: true,
            message: 'You can reapply to become a seller',
          );
        }

        return const SellerResult(
          success: true,
          message: 'You are eligible to become a seller',
        );
      } else {
        return const SellerResult(
          success: false,
          message: 'Failed to check eligibility',
        );
      }
    } catch (e) {
      return SellerResult(
        success: false,
        message: 'Error checking eligibility: ${e.toString()}',
      );
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Helper method to handle HTTP responses consistently
  static SellerResult _handleResponse(
      http.Response response, String successMessage) {
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    // Check if response is empty
    if (response.body.isEmpty) {
      return const SellerResult(
        success: false,
        message: 'Server returned empty response',
      );
    }

    // Check if response is HTML (error page)
    if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
        response.body.trim().toLowerCase().startsWith('<html')) {
      return const SellerResult(
        success: false,
        message: 'Server error occurred. Please try again later.',
      );
    }

    // Try to parse JSON
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      print('JSON parsing error: $e');
      return const SellerResult(
        success: false,
        message: 'Invalid response format from server',
      );
    }

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data['success'] == true) {
      return SellerResult(
        success: true,
        message: data['message'] ?? successMessage,
        data: data,
        items: data['items'],
        item: data['item'],
      );
    } else {
      return SellerResult(
        success: false,
        message: data['message'] ?? 'Operation failed',
      );
    }
  }

  /// Helper method to handle errors consistently
  static SellerResult _handleError(dynamic error) {
    print('Error occurred: $error');

    if (error is http.ClientException) {
      return const SellerResult(
        success: false,
        message:
            'Network connection error. Please check your internet connection.',
      );
    } else if (error is FormatException) {
      return const SellerResult(
        success: false,
        message: 'Invalid response from server. Please try again.',
      );
    } else {
      return SellerResult(
        success: false,
        message: 'An error occurred: ${error.toString()}',
      );
    }
  }
}

// =============================================================================
// MODEL CLASSES (SAME AS BEFORE)
// =============================================================================

// Order Model
class Order {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? shippingAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.shippingAddress,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? json['user']?['_id'] ?? '',
      userName: json['userName'] ?? json['user']?['name'] ?? '',
      userEmail: json['userEmail'] ?? json['user']?['email'] ?? '',
      userPhone: json['userPhone'] ?? json['user']?['phone'] ?? '',
      items: (json['items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'pending',
      shippingAddress: json['shippingAddress'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'paymentStatus': paymentStatus,
      'shippingAddress': shippingAddress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// Order Item Model
class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] ?? json['product']?['_id'] ?? '',
      productName: json['productName'] ?? json['product']?['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      imageUrl: json['imageUrl'] ?? json['product']?['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  double get totalPrice => price * quantity;
}

// User Details Model
class UserDetails {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final int totalOrders;
  final double totalSpent;
  final String? profileImage;

  UserDetails({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.totalOrders,
    required this.totalSpent,
    this.profileImage,
  });

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      totalOrders: json['totalOrders'] ?? 0,
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'profileImage': profileImage,
    };
  }
}

// Product Model
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final String sellerId;
  final String? sellerName;
  final int discount; // Discount percentage (0-100)
  final int tax; // Tax percentage (0-100)
  final bool hasVAT; // Whether VAT is applicable
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    required this.isAvailable,
    required this.sellerId,
    this.sellerName,
    this.discount = 0,
    this.tax = 0,
    this.hasVAT = false,
    required this.createdAt,
  });

  // Calculate discounted price
  double get discountedPrice {
    if (discount > 0) {
      return price - (price * discount / 100);
    }
    return price;
  }

  // Calculate price with tax
  double get priceWithTax {
    if (tax > 0) {
      return discountedPrice + (discountedPrice * tax / 100);
    }
    return discountedPrice;
  }

  // Calculate final price (with discount, tax, and VAT if applicable)
  double get finalPrice {
    double basePrice = priceWithTax;
    if (hasVAT) {
      // Assuming standard VAT rate of 18% - you can modify this as needed
      const double vatRate = 18.0;
      basePrice += (basePrice * vatRate / 100);
    }
    return basePrice;
  }

  // Calculate discount amount
  double get discountAmount {
    if (discount > 0) {
      return price * discount / 100;
    }
    return 0.0;
  }

  // Calculate tax amount
  double get taxAmount {
    if (tax > 0) {
      return discountedPrice * tax / 100;
    }
    return 0.0;
  }

  // Calculate VAT amount
  double get vatAmount {
    if (hasVAT) {
      const double vatRate = 18.0;
      return priceWithTax * vatRate / 100;
    }
    return 0.0;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'],
      isAvailable: json['isAvailable'] ?? true,
      sellerId: json['sellerId'] ?? '',
      sellerName: json['sellerName'],
      discount: json['discount'] ?? 0,
      tax: json['tax'] ?? 0,
      hasVAT: json['hasVAT'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'discount': discount,
      'tax': tax,
      'hasVAT': hasVAT,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Copy Product with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    String? sellerId,
    String? sellerName,
    int? discount,
    int? tax,
    bool? hasVAT,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      hasVAT: hasVAT ?? this.hasVAT,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, discount: $discount%, tax: $tax%, hasVAT: $hasVAT, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Seller Request Model
class SellerRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String storeName;
  final String storeAddress;
  final String? businessLicense;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? rejectionReason;

  SellerRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.storeName,
    required this.storeAddress,
    this.businessLicense,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.rejectionReason,
  });

  factory SellerRequest.fromJson(Map<String, dynamic> json) {
    return SellerRequest(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      businessLicense: json['businessLicense'],
      status: json['status'] ?? 'pending',
      requestedAt:
          DateTime.tryParse(json['requestedAt'] ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'])
          : null,
      rejectionReason: json['rejectionReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'businessLicense': businessLicense,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }
}

// Seller Model
class Seller {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String storeName;
  final String storeAddress;
  final String? businessLicense;
  final bool isActive;
  final DateTime createdAt;

  Seller({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.storeName,
    required this.storeAddress,
    this.businessLicense,
    required this.isActive,
    required this.createdAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      businessLicense: json['businessLicense'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'businessLicense': businessLicense,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}