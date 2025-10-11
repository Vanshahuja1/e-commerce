import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCartService {
  static const String _cartKey = 'guest_cart_v1';

  // Normalize product to a consistent schema for storage
  static Map<String, dynamic> _normalizeProduct(Map<String, dynamic> p, {int quantity = 1}) {
    final String id = p['_id']?.toString() ?? p['productId']?.toString() ?? p['id']?.toString() ?? '';
    return {
      'productId': id,
      '_id': id,
      'name': p['name'],
      'price': (p['price'] is num) ? (p['price'] as num).toDouble() : double.tryParse(p['price']?.toString() ?? '0') ?? 0.0,
      'imageUrl': p['imageUrl'],
      'category': p['category'],
      'unit': p['unit'],
      'quantity': quantity,
      'discount': (p['discount'] is num) ? (p['discount'] as num).toDouble() : double.tryParse(p['discount']?.toString() ?? '0') ?? 0.0,
      'tax': (p['tax'] is num) ? (p['tax'] as num).toDouble() : double.tryParse(p['tax']?.toString() ?? '0') ?? 0.0,
      'hasVAT': p['hasVAT'] == true,
    };
  }

  static Future<List<Map<String, dynamic>>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw);
    if (list is List) {
      return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
    }
    return [];
  }

  static Future<void> _saveCartItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(items));
  }

  static Future<int> getCartItemCount() async {
    final items = await getCartItems();
    return items.fold<int>(0, (sum, it) => sum + (it['quantity'] as int? ?? 1));
  }

  static Future<Map<String, double>> getCartSummary() async {
    final items = await getCartItems();
    double originalTotal = 0;
    double subtotal = 0;
    double totalSavings = 0;
    double totalTax = 0;
    double finalTotal = 0;

    for (final item in items) {
      final q = (item['quantity'] as int?) ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
      final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;
      final discounted = price * (1 - discount / 100);
      final withTax = discounted * (1 + tax / 100);

      originalTotal += price * q;
      subtotal += discounted * q;
      totalSavings += (price - discounted) * q;
      totalTax += (withTax - discounted) * q;
      finalTotal += withTax * q;
    }

    return {
      'originalTotal': originalTotal,
      'subtotal': subtotal,
      'totalSavings': totalSavings,
      'totalTax': totalTax,
      'finalTotal': finalTotal,
    };
  }

  static Future<void> clearCart() async {
    await _saveCartItems([]);
  }

  static Future<void> addToCart(Map<String, dynamic> product, {int quantity = 1}) async {
    final items = await getCartItems();
    final normalized = _normalizeProduct(product, quantity: quantity);
    final id = normalized['productId'] as String;
    final idx = items.indexWhere((it) => (it['productId']?.toString() ?? it['_id']?.toString()) == id);
    if (idx >= 0) {
      items[idx]['quantity'] = (items[idx]['quantity'] as int? ?? 1) + quantity;
      // update pricing flags in case product changed
      items[idx]['discount'] = normalized['discount'];
      items[idx]['tax'] = normalized['tax'];
      items[idx]['hasVAT'] = normalized['hasVAT'];
      items[idx]['price'] = normalized['price'];
    } else {
      items.add(normalized);
    }
    await _saveCartItems(items);
  }

  static Future<void> updateQuantity(String productId, int newQuantity) async {
    final items = await getCartItems();
    final idx = items.indexWhere((it) => (it['productId']?.toString() ?? it['_id']?.toString()) == productId);
    if (idx >= 0) {
      if (newQuantity < 1) {
        items.removeAt(idx);
      } else {
        items[idx]['quantity'] = newQuantity;
      }
      await _saveCartItems(items);
    }
  }

  static Future<void> removeFromCart(String productId) async {
    final items = await getCartItems();
    items.removeWhere((it) => (it['productId']?.toString() ?? it['_id']?.toString()) == productId);
    await _saveCartItems(items);
  }
}
