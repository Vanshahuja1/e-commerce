import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/services/auth_service.dart';
import '/widgets/products.dart'; // Import ProductsSection

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({Key? key}) : super(key: key);

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  dynamic product;
  int _cartItemCount = 0;
  int _currentProductQuantityInCart = 0; // Track quantity in cart for this specific product
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      setState(() {
        product = args;
      });
      _loadCurrentProductQuantity();
    }
  }

  Future<void> _loadCartCount() async {
    _cartItemCount = await CartService.getCartItemCount();
    if (mounted) setState(() {});
  }

  Future<void> _loadCurrentProductQuantity() async {
    if (product == null) return;
    
    try {
      final cartItems = await CartService.getCartItems();
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      
      int quantity = 0;
      for (var item in cartItems) {
        String itemId = item['_id']?.toString() ?? 
                       item['productId']?.toString() ?? 
                       item['id']?.toString() ?? '';
        if (itemId == productId) {
          quantity = item['quantity'] ?? 0;
          break;
        }
      }
      
      setState(() {
        _currentProductQuantityInCart = quantity;
      });
    } catch (e) {
      print('Error loading current product quantity: $e');
    }
  }

  Future<void> _addToCart() async {
    if (product == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      await _loadCartCount();
      await _loadCurrentProductQuantity();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item to cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromCart() async {
    if (product == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      
      if (_currentProductQuantityInCart > 1) {
        await CartService.updateQuantity(productId, _currentProductQuantityInCart - 1);
      } else {
        await CartService.removeFromCart(productId);
      }
      
      await _loadCartCount();
      await _loadCurrentProductQuantity();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} ${_currentProductQuantityInCart == 1 ? 'removed from' : 'quantity decreased in'} cart'),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating cart: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No product data available'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _cartItemCount,
        onCartTap: () async {
          await Navigator.pushNamed(context, '/cart');
          _loadCartCount();
        },
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        onLogout: () async {
          await AuthService.logout();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.white,
              child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                  ? Image.network(
                      product['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.image,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.image,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),

            // Product Details
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product['name']?.toString() ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      product['category']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    children: [
                      if (product['discount'] != null && product['discount'] > 0) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BHD${product['price']?.toString() ?? '0'}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'BHD${_calculateDiscountedPrice(product['price'], product['discount'])}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${product['discount']}% OFF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'BHD${product['price']?.toString() ?? '0'}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                      Text(
                        ' /${product['unit']?.toString() ?? 'unit'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Availability Status
                  Row(
                    children: [
                      Icon(
                        product['isAvailable'] == true ? Icons.check_circle : Icons.cancel,
                        color: product['isAvailable'] == true ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product['isAvailable'] == true ? 'In Stock' : 'Out of Stock',
                        style: TextStyle(
                          fontSize: 14,
                          color: product['isAvailable'] == true ? Colors.green.shade700 : Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Qty: ${product['quantity']?.toString() ?? '0'} ${product['unit']?.toString() ?? 'units'} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['description']?.toString() ?? 'No description available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Product Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Product ID', product['_id']?.toString() ?? 'N/A'),
                        _buildDetailRow('Unit', product['unit']?.toString() ?? 'N/A'),
                        _buildDetailRow('Available Quantity', '${product['quantity']?.toString() ?? '0'} ${product['unit']?.toString() ?? 'units'}'),
                        if (product['discount'] != null && product['discount'] > 0)
                          _buildDetailRow('Discount', '${product['discount']}%'),
                        if (product['tax'] != null && product['tax'] > 0)
                          _buildDetailRow('Tax', '${product['tax']}%'),
                        if (product['hasVAT'] == true)
                          _buildDetailRow('VAT', 'Applicable'),
                        if (product['createdAt'] != null)
                          _buildDetailRow('Listed On', _formatDate(product['createdAt'].toString())),
                        if (product['updatedAt'] != null)
                          _buildDetailRow('Last Updated', _formatDate(product['updatedAt'].toString())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // More Products Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More Products',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover other products you might like',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Products Section
            ProductsSection(
              refreshCartCount: () async {
                await _loadCartCount();
                await _loadCurrentProductQuantity();
              },
              isGuestMode: false,
            ),

            const SizedBox(height: 100), // Space for bottom add button
          ],
        ),
      ),

      // Bottom Add to Cart Button - New Design
      bottomNavigationBar: product['isAvailable'] == true ? Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAddButton(_currentProductQuantityInCart),
            ],
          ),
        ),
      ) : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Out of Stock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(int quantity) {
    double buttonSize = 40; // Larger for showcase screen
    double iconSize = 20;
    double fontSize = 16;
    double rowPadding = 8;

    if (_isLoading) {
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
        ),
      );
    }

    if (quantity == 0) {
      return GestureDetector(
        onTap: _addToCart,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 6,
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _removeFromCart,
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
              onTap: _addToCart,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Helper methods for price calculations with discount and tax
  String _calculateDiscountedPrice(dynamic price, dynamic discount) {
    double originalPrice = double.tryParse(price?.toString() ?? '0') ?? 0;
    double discountPercent = double.tryParse(discount?.toString() ?? '0') ?? 0;
    double discountedPrice = originalPrice * (1 - discountPercent / 100);
    return discountedPrice.toStringAsFixed(2);
  }
}