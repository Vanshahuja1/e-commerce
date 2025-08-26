import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/cart_service.dart';

class ProductsSection extends StatefulWidget {
  final VoidCallback? refreshCartCount;
  final bool isGuestMode;

  const ProductsSection({
    Key? key,
    this.refreshCartCount,
    this.isGuestMode = false,
  }) : super(key: key);

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
    if (!widget.isGuestMode) {
      loadCartQuantities();
    }
  }

  Future<void> loadCartQuantities() async {
    try {
      final cartItems = await CartService.getCartItems();
      setState(() {
        cartQuantities.clear();
        for (var item in cartItems) {
          String productId = item['_id']?.toString() ??
              item['productId']?.toString() ??
              item['id']?.toString() ??
              '';
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
    if (!widget.isGuestMode) {
      await loadCartQuantities();
    }
  }

  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/admin-items'),
        headers: {'Content-Type': 'application/json'},
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
    if (widget.isGuestMode) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      await fetchProducts();
      await loadCartQuantities();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item to cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Future<void> removeItemFromCart(dynamic product) async {
    try {
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      int currentQuantity = cartQuantities[productId] ?? 0;
      if (currentQuantity > 0) {
        if (currentQuantity == 1) {
          await CartService.removeFromCart(productId);
        } else {
          await CartService.updateQuantity(productId, currentQuantity - 1);
        }
        await fetchProducts();
        await loadCartQuantities();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                      childAspectRatio: _getChildAspectRatio(screenWidth),
                    ),
                    itemCount: products.length > 15 ? 15 : products.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(products[index], screenWidth);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth > 1200) {
      return 0.85;
    } else if (screenWidth > 900) {
      return 0.82;
    } else if (screenWidth > 600) {
      return 0.80;
    } else if (screenWidth > 400) {
      return 0.78;
    } else {
      return 0.75;
    }
  }

  Widget _buildProductCard(dynamic product, double screenWidth) {
    String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    int quantity = cartQuantities[productId] ?? 0;

    double originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
    double discount = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
    double tax = double.tryParse(product['tax']?.toString() ?? '0') ?? 0.0;
    bool hasVAT = product['hasVAT'] == true;
    
    double discountedPrice = originalPrice * (1 - discount / 100);
    double finalPrice = discountedPrice * (1 + tax / 100);
    bool hasDiscount = discount > 0;

    return GestureDetector(
      onTap: () {
        if (widget.isGuestMode) {
          Navigator.pushNamed(context, '/login');
        } else {
          Navigator.pushNamed(
            context,
            '/showcase',
            arguments: product,
          );
        }
      },
      child: Container(
        height: null,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: product['imageUrl'] != null &&
                              product['imageUrl'].toString().isNotEmpty
                          ? Image.network(
                              product['imageUrl'].toString(),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderImage();
                              },
                            )
                          : _buildPlaceholderImage(),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${discount.toInt()}% OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600 ? 8 : 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (hasVAT)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'VAT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600 ? 7 : 6,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Details Section
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? 10 : 8,
                    vertical: screenWidth > 600 ? 8 : 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name with Add Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product['name']?.toString() ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 12 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildAddButton(product, quantity, screenWidth),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Quantity/Weight
                    Text(
                      '${product['weight'] ?? product['quantity'] ?? '500 g'} - Approx. ${product['pieces'] ?? '4-5pcs'}',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 9 : 8,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: hasDiscount
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BHD ${originalPrice.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    fontSize: screenWidth > 600 ? 10 : 9,
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  'BHD ${finalPrice.toStringAsFixed(3)}',
                                  style: TextStyle(
                                    fontSize: screenWidth > 600 ? 13 : 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'BHD ${finalPrice.toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: screenWidth > 600 ? 13 : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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

  Widget _buildAddButton(dynamic product, int quantity, double screenWidth) {
    double buttonSize = screenWidth > 600 ? 22 : 18;
    double iconSize = screenWidth > 600 ? 13 : 11;
    double fontSize = screenWidth > 600 ? 11 : 9;
    double rowPadding = screenWidth > 600 ? 5 : 3;

    if (quantity == 0) {
      return GestureDetector(
        onTap: () => addItemToCart(product),
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
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => removeItemFromCart(product),
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
              onTap: () => addItemToCart(product),
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

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}
