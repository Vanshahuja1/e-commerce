import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/cart_service.dart';
import '../../widgets/header.dart';
import '../../widgets/footer.dart';
import '/models/user_model.dart';

class DiscountScreen extends StatefulWidget {
  final VoidCallback? refreshCartCount;
  final bool isGuestMode;
  final UserModel? currentUser;
  final bool isLoggedIn;
  final VoidCallback? onLogout;

  const DiscountScreen({
    Key? key,
    this.refreshCartCount,
    this.isGuestMode = false,
    this.currentUser,
    this.isLoggedIn = false,
    this.onLogout,
  }) : super(key: key);

  @override
  DiscountScreenState createState() => DiscountScreenState();
}

class DiscountScreenState extends State<DiscountScreen> {
  List<dynamic> products = [];
  bool isLoading = true;
  String? error;
  Map<String, int> cartQuantities = {};
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    fetchDiscountProducts();
    if (!widget.isGuestMode) {
      loadCartQuantities();
      _loadCartCount();
    }
  }

  Future<void> _loadCartCount() async {
    if (!widget.isLoggedIn) {
      setState(() => _cartItemCount = 0);
      return;
    }
    
    try {
      final count = await CartService.getCartItemCount();
      if (mounted) {
        setState(() => _cartItemCount = count);
      }
    } catch (e) {
      print('Error loading cart count: $e');
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
    await fetchDiscountProducts();
    if (!widget.isGuestMode) {
      await loadCartQuantities();
      await _loadCartCount();
    }
  }

  Future<void> fetchDiscountProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/admin-products/with-discount'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Response: $data'); // Debug print
        setState(() {
          if (data is List) {
            products = data;
          } else if (data is Map && data.containsKey('products')) {
            // This matches your API response structure
            products = data['products'];
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
    if (widget.isGuestMode || !widget.isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      await fetchDiscountProducts();
      await loadCartQuantities();
      await _loadCartCount();
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
        await fetchDiscountProducts();
        await loadCartQuantities();
        await _loadCartCount();
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

  void _handleCartTap() {
    if (widget.isLoggedIn) {
      Navigator.pushNamed(context, '/cart');
    } else {
      Navigator.pushNamed(context, '/login');
    }
  }

  void _handleProfileTap() {
    if (widget.isLoggedIn) {
      if (widget.currentUser?.userType == 'admin') {
        Navigator.pushNamed(context, '/admin');
      } else {
        Navigator.pushNamed(context, '/profile');
      }
    } else {
      Navigator.pushNamed(context, '/login');
    }
  }

  void _handleHomeTap() {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _handleCategoriesTap() {
    Navigator.pushNamed(context, '/search');
  }

  void _handleDiscountTap() {
    // Already on discount screen, just refresh
    refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _cartItemCount,
        currentUser: widget.currentUser,
        isLoggedIn: widget.isLoggedIn,
        onCartTap: _handleCartTap,
        onProfileTap: _handleProfileTap,
        onLogout: widget.onLogout ?? () {},
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshProducts,
              color: Colors.green.shade700,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildDiscountContent(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Footer(
        currentUser: widget.currentUser,
        isLoggedIn: widget.isLoggedIn,
        onHomeTap: _handleHomeTap,
        onCategoriesTap: _handleCategoriesTap,
        onDiscountTap: _handleDiscountTap,
        onProfileTap: _handleProfileTap,
        currentIndex: 2, // Discount tab is index 2
      ),
    );
  }

  Widget _buildDiscountContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
               Center(
                child: Text(
                  'AMAZING DISCOUNTS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: screenWidth > 600 ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
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
                          'Loading discounts...',
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
                          'No discounts available',
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
                GridView.builder(
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
              const SizedBox(height: 100),
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
    
    // Calculate discounted price (this is what should be shown on cards)
    double discountedPrice = originalPrice * (1 - discount / 100);
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
              flex: 5, // Back to original
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
                        top: 4, // Reduced padding
                        left: 4, // Reduced padding
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6), // Reduced radius
                          ),
                          child: Text(
                            '${discount.toInt()}% OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600 ? 7 : 6, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (hasVAT)
                      Positioned(
                        top: 4, // Reduced padding
                        right: 4, // Reduced padding
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(4), // Reduced radius
                          ),
                          child: Text(
                            'VAT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600 ? 6 : 5, // Reduced font size
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
              flex: 4, // Back to original
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? 10 : 8, // Back to original
                    vertical: screenWidth > 600 ? 8 : 6), // Back to original
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name with Add Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product['name']?.toString() ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 11 : 9, // Slightly reduced
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.1, // Reduced line height
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4), // Reduced spacing
                        _buildAddButton(product, quantity, screenWidth),
                      ],
                    ),
                    const SizedBox(height: 1), // Reduced spacing
                    // Quantity/Weight - Made more compact
                    Text(
                      '${product['weight'] ?? product['quantity'] ?? '500 g'} - Approx. ${product['pieces'] ?? '4-5pcs'}',
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 8 : 7, // Reduced font size
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    // Price Section - Made more compact
                    hasDiscount
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BHD ${originalPrice.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 9 : 8, // Reduced font size
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                'BHD ${discountedPrice.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 12 : 10, // Reduced font size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'BHD ${discountedPrice.toStringAsFixed(3)}',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 12 : 10, // Reduced font size
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
