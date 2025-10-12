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

  // Fixed categories list
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

        // Organize products by category
        Map<String, List<dynamic>> categorized = {};
        for (String category in categories) {
          List<dynamic> categoryItems = products.where((product) {
            String productCategory = product['category']?.toString().toLowerCase() ?? '';
            return productCategory.contains(category.toLowerCase()) ||
                   category.toLowerCase().contains(productCategory);
          }).take(4).toList();

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

      if (widget.refreshCartCount != null) {
        widget.refreshCartCount!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
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
            height: 200,
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
    double originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    double discount = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
    double discountedPrice = originalPrice * (1 - discount / 100);

    return GestureDetector(
      onTap: () {
        // Navigate to showcase screen with product details
        Navigator.pushNamed(
          context,
          '/showcase',
          arguments: product,
        );
      },
      child: Container(
        width: 140,
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
                  children: [
                    Text(
                      product['name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (discount > 0) ...[
                      Text(
                        '₹${originalPrice.toStringAsFixed(3)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '₹${discountedPrice.toStringAsFixed(3)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ] else
                      Text(
                        '₹${originalPrice.toStringAsFixed(3)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
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
}
