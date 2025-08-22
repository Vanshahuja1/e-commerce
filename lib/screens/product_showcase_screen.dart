import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cart_service.dart';

class ProductsSection extends StatefulWidget {
  final VoidCallback? refreshCartCount;

  const ProductsSection({Key? key, this.refreshCartCount}) : super(key: key);

  @override
  ProductsSectionState createState() => ProductsSectionState();
}

class ProductsSectionState extends State<ProductsSection> {
  List<dynamic> products = [];
  bool isLoading = true;
  String? error;
  Map<String, int> cartQuantities = {};

  @override
  void initState() {
    super.initState();
    fetchProducts();
    loadCartQuantities();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadCartQuantities() async {
    try {
      final cartItems = await CartService.getCartItems();
      setState(() {
        cartQuantities.clear();
        for (var item in cartItems) {
          String productId = item['_id']?.toString() ?? 
                           item['productId']?.toString() ?? 
                           item['id']?.toString() ?? '';
          if (productId.isNotEmpty) {
            cartQuantities[productId] = item['quantity'] ?? 1;
          }
        }
      });
    } catch (e) {
      print('Error loading cart quantities: $e');
    }
  }

  Future<void> refreshProducts() async {
    await fetchProducts();
    await loadCartQuantities();
  }

  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/items'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data is List) {
            products = data;
          } else if (data is Map && data.containsKey('items')) {
            products = data['items'];
          } else if (data is Map && data.containsKey('data')) {
            products = data['data'];
          } else {
            products = [data];
          }
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load products: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> addItemToCart(dynamic product) async {
    try {
      final token = await _getToken();
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please login to add items to cart'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(milliseconds: 1500),
              action: SnackBarAction(
                label: 'Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ),
          );
        }
        return;
      }

      await CartService.addToCart(Map<String, dynamic>.from(product));
      await fetchProducts(); // Auto-refresh products
      await loadCartQuantities(); // Auto-refresh cart quantities

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }

      if (widget.refreshCartCount != null) {
        widget.refreshCartCount!();
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'Error adding item to cart';
        if (e.toString().contains('User not authenticated')) {
          errorMessage = 'Please login to add items to cart';
        } else if (e.toString().contains('Network')) {
          errorMessage = 'Network error. Please check your connection';
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 1500),
            action: e.toString().contains('User not authenticated') 
                ? SnackBarAction(
                    label: 'Login',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> removeItemFromCart(dynamic product) async {
    try {
      final token = await _getToken();
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please login to modify cart'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(milliseconds: 1500),
              action: SnackBarAction(
                label: 'Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ),
          );
        }
        return;
      }

      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      int currentQuantity = cartQuantities[productId] ?? 0;
      
      if (currentQuantity > 0) {
        if (currentQuantity == 1) {
          await CartService.removeFromCart(productId);
        } else {
          await CartService.updateQuantity(productId, currentQuantity - 1);
        }
        await fetchProducts(); // Auto-refresh products
        await loadCartQuantities(); // Auto-refresh cart quantities

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product['name']} ${currentQuantity == 1 ? 'removed from' : 'quantity decreased in'} cart'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }

        if (widget.refreshCartCount != null) {
          widget.refreshCartCount!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'Error updating cart';
        if (e.toString().contains('User not authenticated')) {
          errorMessage = 'Please login to modify cart';
        } else if (e.toString().contains('Network')) {
          errorMessage = 'Network error. Please check your connection';
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 1500),
            action: e.toString().contains('User not authenticated') 
                ? SnackBarAction(
                    label: 'Login',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getResponsiveDimensions(double screenWidth) {
    int crossAxisCount;
    double cardWidth;
    double imageHeight;
    
    if (screenWidth > 1200) {
      crossAxisCount = 5;
      cardWidth = (screenWidth - 64) / 5;
      imageHeight = 120;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
      cardWidth = (screenWidth - 64) / 4;
      imageHeight = 110;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
      cardWidth = (screenWidth - 48) / 3;
      imageHeight = 100;
    } else if (screenWidth > 400) {
      crossAxisCount = 2;
      cardWidth = (screenWidth - 32) / 2;
      imageHeight = 90;
    } else {
      crossAxisCount = 2;
      cardWidth = (screenWidth - 32) / 2;
      imageHeight = 80;
    }
    
    return {
      'crossAxisCount': crossAxisCount,
      'cardWidth': cardWidth,
      'imageHeight': imageHeight,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final responsiveDimensions = _getResponsiveDimensions(screenWidth);
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // REMOVED: Row with "Fresh Products", Refresh Button, View All
              const SizedBox(height: 12),
              if (isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading products...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => refreshProducts(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (products.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No products available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => refreshProducts(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: products
                      .take(10)
                      .map((product) => _buildProductCard(
                            product, 
                            responsiveDimensions['cardWidth'],
                            responsiveDimensions['imageHeight'],
                            screenWidth,
                          ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(dynamic product, double cardWidth, double imageHeight, double screenWidth) {
    String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    int quantity = cartQuantities[productId] ?? 0;

    return Container(
      width: cardWidth - 6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: imageHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      product['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage(imageHeight);
                      },
                    ),
                  )
                : _buildPlaceholderImage(imageHeight),
          ),
          Padding(
            padding: EdgeInsets.all(screenWidth > 600 ? 12 : 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    minHeight: screenWidth > 600 ? 36 : 32,
                  ),
                  child: Text(
                    product['name']?.toString() ?? 'Unknown Product',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 14 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product['category']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: screenWidth > 600 ? 12 : 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'BHD${product['price']?.toString() ?? '0'}',
                        style: TextStyle(
                          fontSize: screenWidth > 600 ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    Text(
                      '/${product['unit']?.toString() ?? 'unit'}',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 10 : 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenWidth > 600 ? 12 : 10),
                _buildCartControls(product, quantity, screenWidth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartControls(dynamic product, int quantity, double screenWidth) {
    if (quantity == 0) {
      return SizedBox(
        width: double.infinity,
        height: screenWidth > 600 ? 36 : 32,
        child: ElevatedButton.icon(
          onPressed: () => addItemToCart(product),
          icon: Icon(Icons.add_shopping_cart, size: screenWidth > 600 ? 16 : 14),
          label: Text(
            'Add to Cart', 
            style: TextStyle(fontSize: screenWidth > 600 ? 12 : 11),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      return Container(
        height: screenWidth > 600 ? 36 : 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade700, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => removeItemFromCart(product),
              child: Container(
                width: screenWidth > 600 ? 36 : 32,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomLeft: Radius.circular(7),
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: screenWidth > 600 ? 16 : 14,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    quantity.toString(),
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => addItemToCart(product),
              child: Container(
                width: screenWidth > 600 ? 36 : 32,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: screenWidth > 600 ? 16 : 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPlaceholderImage(double height) {
    return Container(
      width: double.infinity,
      height: height,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image,
        size: height * 0.4,
        color: Colors.grey.shade400,
         ),
    );
  }
}