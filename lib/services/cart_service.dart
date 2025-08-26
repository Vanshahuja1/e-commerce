import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  static const String baseUrl = 'https://backend-ecommerce-app-co1r.onrender.com/api';
  
  // Get user token from shared preferences
  static Future<String?> _getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('CartService: Fetched token: ${token != null ? token.substring(0, 10) + '...' : 'null'}');
    return token;
  }
  
  // Get user ID from shared preferences - FIXED
  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    if (userId == null) {
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        try {
          final userData = json.decode(userDataString);
          userId = userData['id']?.toString();
        } catch (e) {
          print('Error parsing user data: $e');
        }
      }
    }
    print('CartService: Fetched User ID: $userId');
    return userId;
  }
  
  // Get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getUserToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Add item to user's cart - IMPROVED error handling
  static Future<void> addToCart(Map<String, dynamic> product) async {
    try {
      final userId = await _getUserId();
      final token = await _getUserToken();
      
      if (userId == null) {
        throw Exception('User ID not found. Please log in again.');
      }
      
      if (token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }
      
      final headers = await _getHeaders();
      final requestBody = json.encode({
        'userId': userId,
        'productId': product['_id'] ?? product['id'],
        'name': product['name'],
        'price': product['price'],
        'imageUrl': product['imageUrl'],
        'category': product['category'],
        'unit': product['unit'],
        'quantity': 1,
        'discount': product['discount'] ?? 0,
        'tax': product['tax'] ?? 0,
        'hasVAT': product['hasVAT'] ?? false,
      });
      
      print('CartService: Adding to cart request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/cart/add'),
        headers: headers,
        body: requestBody,
      );

      print('CartService: Cart add response status: ${response.statusCode}');
      print('CartService: Cart add response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to add item to cart: ${response.statusCode}');
      }
    } catch (e) {
      print('Cart service error: $e');
      throw Exception('Error adding to cart: $e');
    }
  }

  // Remove item from user's cart
  static Future<void> removeFromCart(String productId) async {
    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/remove'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'productId': productId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to remove item from cart: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error removing from cart: $e');
    }
  }

  // Update item quantity in user's cart
  static Future<void> updateQuantity(String productId, int quantity) async {
    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse('$baseUrl/cart/update'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update cart item: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating cart: $e');
    }
  }

  // Get user's cart items
  static Future<List<Map<String, dynamic>>> getCartItems() async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];
      
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/cart/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['cartItems'] is List) {
          return List<Map<String, dynamic>>.from(data['cartItems']);
        }
        return [];
      } else if (response.statusCode == 404) {
        // No cart found for user, return empty list
        return [];
      } else {
        throw Exception('Failed to load cart: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading cart: $e');
      return [];
    }
  }

  // Get total cart item count for user
  static Future<int> getCartItemCount() async {
    try {
      final cartItems = await getCartItems();
      return cartItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
    } catch (e) {
      print('Error getting cart count: $e');
      return 0;
    }
  }

  // FIXED: Get total price of user's cart with proper discount and tax calculation
  static Future<double> getTotalPrice() async {
    try {
      final cartItems = await getCartItems();
      return cartItems.fold<double>(0.0, (sum, item) {
        final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = item['quantity'] as int? ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;
        
        // Calculate discounted price
        final discountedPrice = originalPrice * (1 - discount / 100);
        
        // Calculate tax on discounted price
        final finalPrice = discountedPrice * (1 + tax / 100);
        
        return sum + (finalPrice * quantity);
      });
    } catch (e) {
      print('Error calculating total price: $e');
      return 0.0;
    }
  }

  // Clear user's entire cart
  static Future<void> clearCart() async {
    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/clear/$userId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to clear cart: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error clearing cart: $e');
    }
  }

  // Get cart item quantity for a specific product
  static Future<int> getProductQuantityInCart(String productId) async {
    try {
      final cartItems = await getCartItems();
      final item = cartItems.firstWhere(
        (item) => (item['_id']?.toString() ?? item['productId']?.toString()) == productId,
        orElse: () => <String, dynamic>{},
      );
      return item['quantity'] as int? ?? 0;
    } catch (e) {
      print('Error getting product quantity: $e');
      return 0;
    }
  }

  // Debug method to check authentication status
  static Future<Map<String, dynamic>> getAuthStatus() async {
    final userId = await _getUserId();
    final token = await _getUserToken();
    
    return {
      'hasUserId': userId != null,
      'hasToken': token != null,
      'userId': userId,
      'tokenPreview': token != null ? '${token.substring(0, 10)}...' : null,
    };
  }

  // FIXED: Calculate total savings correctly
  static Future<double> getTotalSavings() async {
    try {
      final cartItems = await getCartItems();
      return cartItems.fold<double>(0.0, (sum, item) {
        final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = item['quantity'] as int? ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        
        final savings = originalPrice * (discount / 100) * quantity;
        return sum + savings;
      });
    } catch (e) {
      print('Error calculating total savings: $e');
      return 0.0;
    }
  }

  // FIXED: Calculate total tax correctly
  static Future<double> getTotalTax() async {
    try {
      final cartItems = await getCartItems();
      return cartItems.fold<double>(0.0, (sum, item) {
        final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = item['quantity'] as int? ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;
        
        // Calculate tax on discounted price
        final discountedPrice = originalPrice * (1 - discount / 100);
        final taxAmount = discountedPrice * (tax / 100) * quantity;
        
        return sum + taxAmount;
      });
    } catch (e) {
      print('Error calculating total tax: $e');
      return 0.0;
    }
  }

  // FIXED: Calculate subtotal correctly (discounted price before tax)
  static Future<double> getSubtotal() async {
    try {
      final cartItems = await getCartItems();
      return cartItems.fold<double>(0.0, (sum, item) {
        final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = item['quantity'] as int? ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        
        // Calculate discounted price (before tax)
        final discountedPrice = originalPrice * (1 - discount / 100);
        
        return sum + (discountedPrice * quantity);
      });
    } catch (e) {
      print('Error calculating subtotal: $e');
      return 0.0;
    }
  }

  // COMPLETELY REWRITTEN: Fixed cart summary calculation
  static Future<Map<String, double>> getCartSummary() async {
    try {
      final cartItems = await getCartItems();
      double originalTotal = 0.0;
      double subtotal = 0.0;
      double totalSavings = 0.0;
      double totalTax = 0.0;
      double finalTotal = 0.0;
      
      print('CartService: Calculating cart summary for ${cartItems.length} items');
      
      for (var item in cartItems) {
        final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = item['quantity'] as int? ?? 0;
        final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
        final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;
        
        print('CartService: Item ${item['name']} - Price: $originalPrice, Qty: $quantity, Discount: $discount%, Tax: $tax%');
        
        // Original total (without any discounts)
        final itemOriginalTotal = originalPrice * quantity;
        originalTotal += itemOriginalTotal;
        
        // Discounted price per item
        final discountedPrice = originalPrice * (1 - discount / 100);
        
        // Subtotal (discounted price before tax)
        final itemSubtotal = discountedPrice * quantity;
        subtotal += itemSubtotal;
        
        // Savings (difference between original and discounted)
        final itemSavings = (originalPrice - discountedPrice) * quantity;
        totalSavings += itemSavings;
        
        // Tax on discounted price
        final itemTaxAmount = discountedPrice * (tax / 100) * quantity;
        totalTax += itemTaxAmount;
        
        // Final price for this item (discounted + tax)
        final itemFinalPrice = (discountedPrice * (1 + tax / 100)) * quantity;
        finalTotal += itemFinalPrice;
        
        print('CartService: Item calculations - Original: $itemOriginalTotal, Discounted: $itemSubtotal, Savings: $itemSavings, Tax: $itemTaxAmount, Final: $itemFinalPrice');
      }
      
      final summary = {
        'originalTotal': originalTotal,
        'subtotal': subtotal,
        'totalSavings': totalSavings,
        'totalTax': totalTax,
        'finalTotal': finalTotal,
      };
      
      print('CartService: Final summary - ${summary.toString()}');
      
      return summary;
    } catch (e) {
      print('Error calculating cart summary: $e');
      return {
        'originalTotal': 0.0,
        'subtotal': 0.0,
        'totalSavings': 0.0,
        'totalTax': 0.0,
        'finalTotal': 0.0,
      };
    }
  }
}