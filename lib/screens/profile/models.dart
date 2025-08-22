import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    if (token == null) throw Exception('No authentication token found');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<Map<String, dynamic>?> loadUserInfo() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/me'), 
        headers: headers
      );
      
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['user'] ?? body;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load user info: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadMyItems() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/items/my-items'), 
        headers: headers
      );
      
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        List<Map<String, dynamic>> items = [];
        
        if (responseBody is List) {
          items = List<Map<String, dynamic>>.from(responseBody);
        } else if (responseBody is Map) {
          if (responseBody.containsKey('items')) {
            items = List<Map<String, dynamic>>.from(responseBody['items'] ?? []);
          } else if (responseBody.containsKey('data')) {
            items = List<Map<String, dynamic>>.from(responseBody['data'] ?? []);
          } else {
            for (var key in responseBody.keys) {
              if (responseBody[key] is List) {
                items = List<Map<String, dynamic>>.from(responseBody[key]);
                break;
              }
            }
          }
        }
        return items;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load items: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> publishItem(Map<String, dynamic> itemData, {String? itemId}) async {
    try {
      final headers = await getHeaders();
      final response = itemId != null 
        ? await http.put(
            Uri.parse('${AppConstants.baseUrl}/items/$itemId'), 
            headers: headers, 
            body: json.encode(itemData)
          )
        : await http.post(
            Uri.parse('${AppConstants.baseUrl}/items'), 
            headers: headers, 
            body: json.encode(itemData)
          );
      
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> updateItem(String itemId, Map<String, dynamic> updates) async {
    try {
      final headers = await getHeaders();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/items/$itemId'),
        headers: headers,
        body: json.encode(updates),
      );
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteItem(String itemId) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/items/$itemId'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      rethrow;
    }
  }
}

class ItemModel {
  final String? id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final int quantity;
  final String unit;

  ItemModel({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? 'Unknown Item',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? 'Unknown',
      imageUrl: json['imageUrl'],
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? 'unit',
    );
  }
}
