import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/services/cart_service.dart';
import '/services/local_cart_service.dart';

class CategoriesShowcase extends StatefulWidget {
  final VoidCallback? refreshCartCount;
  final bool isGuestMode;

  const CategoriesShowcase({
    Key? key,
    this.refreshCartCount,
    this.isGuestMode = false,
  }) : super(key: key);

  @override
  State<CategoriesShowcase> createState() => _CategoriesShowcaseState();
}

class _CategoriesShowcaseState extends State<CategoriesShowcase> {
  List<dynamic> allProducts = [];
  Map<String, List<dynamic>> categoryProducts = {};
  bool isLoading = true;
  String? error;
  Map<String, int> cartQuantities = {}; // Added cart quantities tracking

  final List<String> categories = [
    'Savory',
    'Namkeen',
    'Sweet',
    'Travel Pack Combo',
    'Value Pack Offers',
    'Gift Packs',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProductsAndOrganize();
    _loadCartQuantities(); // Load cart quantities on init
  }

  // Added method to load cart quantities
  Future<void> _loadCartQuantities() async {
    try {
      final cartItems = widget.isGuestMode
          ? await LocalCartService.getCartItems()
          : await CartService.getCartItems();
      
      if (mounted) {
        setState(() {
          cartQuantities.clear();
          for (var item in cartItems) {
            final id = item['_id']?.toString() ?? item['productId']?.toString() ?? item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              cartQuantities[id] = item['quantity'] ?? 1;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading cart quantities: $e');
    }
  }

  Future<void> _fetchProductsAndOrganize() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await http.get(
        Uri.parse('https://e-com-backend-x67v.onrender.com/api/admin-items'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> products = [];

        if (data is List) {
          products = data;
        } else if (data is Map && data.containsKey('items')) {
          products = (data['items'] as List?) ?? [];
        } else if (data is Map && data.containsKey('data')) {
          products = (data['data'] as List?) ?? [];
        } else {
          products = [data];
        }

        Map<String, List<dynamic>> categorized = {};
        for (String category in categories) {
          List<dynamic> categoryItems = products.where((product) {
            String productCategory = product['category']?.toString().toLowerCase().trim() ?? '';
            String targetCategory = category.toLowerCase().trim();
            // Exact match or category contains the target
            return productCategory == targetCategory || 
                   productCategory.split(',').any((cat) => cat.trim() == targetCategory);
          }).take(3).toList();

          if (categoryItems.isNotEmpty) {
            categorized[category] = categoryItems;
          }
        }

        setState(() {
          allProducts = products;
          categoryProducts = categorized;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load products';
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

  Future<void> _addToCart(dynamic product) async {
    try {
      if (widget.isGuestMode) {
        await LocalCartService.addToCart(Map<String, dynamic>.from(product));
      } else {
        await CartService.addToCart(Map<String, dynamic>.from(product));
      }

      await _loadCartQuantities(); // Reload quantities after adding

      if (widget.refreshCartCount != null) {
        widget.refreshCartCount!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.green.shade400,
            duration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _removeFromCart(dynamic product) async {
    try {
      final productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      int currentQuantity = cartQuantities[productId] ?? 0;
      
      if (currentQuantity <= 0) return;

      if (widget.isGuestMode) {
        if (currentQuantity == 1) {
          await LocalCartService.removeFromCart(productId);
        } else {
          await LocalCartService.updateQuantity(productId, currentQuantity - 1);
        }
      } else {
        if (currentQuantity == 1) {
          await CartService.removeFromCart(productId);
        } else {
          await CartService.updateQuantity(productId, currentQuantity - 1);
        }
      }

      await _loadCartQuantities(); // Reload quantities after removing

      if (widget.refreshCartCount != null) {
        widget.refreshCartCount!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} ${currentQuantity == 1 ? 'removed from' : 'quantity decreased in'} cart'),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing from cart: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop by Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (error != null)
            Center(
              child: Column(
                children: [
                  Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchProductsAndOrganize,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                String category = categories[index];
                List<dynamic> products = categoryProducts[category] ?? [];

                if (products.isEmpty) return const SizedBox.shrink();

                return _buildCategorySection(category, products);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<dynamic> products) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/search',
                    arguments: {'category': category},
                  );
                },
                child: Text(
                  'Explore More',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    final quantity = cartQuantities[productId] ?? 0; // Get actual quantity from cart
    
    double originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    double discount = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
    double discountedPrice = originalPrice * (1 - discount / 100);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/showcase',
          arguments: product,
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: product['imageUrl'] != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          product['imageUrl'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, color: Colors.grey),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product['name'] ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildAddButton(product, quantity, screenWidth),
                      ],
                    ),
                    Text(
                      '${product['quantity']} ${product['unit']}',
                      style: TextStyle(
                        fontSize: screenWidth > 700 ? 9 : 8,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (discount > 0) ...[
                      Text(
                        '₹${originalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '₹${discountedPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ] else
                      Text(
                        '₹${originalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(dynamic product, int quantity, double screenWidth) {
    double buttonSize = screenWidth > 600 ? 24 : 20;
    double iconSize = screenWidth > 600 ? 14 : 12;
    double fontSize = screenWidth > 600 ? 12 : 10;
    double rowPadding = screenWidth > 600 ? 5 : 3;

    if (quantity == 0) {
      return GestureDetector(
        onTap: () => _addToCart(product),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            size: iconSize,
            color: Colors.red,
          ),
        ),
      );
    } else {
      return Container(
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade500,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _removeFromCart(product),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rowPadding),
              child: Text(
                quantity.toString(),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _addToCart(product),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}