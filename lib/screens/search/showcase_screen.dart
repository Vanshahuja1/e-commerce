import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/services/auth_service.dart';
import '/widgets/products.dart'; // Import the ProductsSection

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({Key? key}) : super(key: key);

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  Map<String, dynamic>? product;
  int _cartItemCount = 0;
  int _quantity = 1;
  bool _isLoading = false;
  bool _argumentsProcessed = false;
  bool _isAuthenticated = false; // Add authentication state

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoadData();
  }

  // Get auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Check if user is authenticated by verifying token exists and is valid
  Future<bool> _isUserAuthenticated() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return false;
      }
      
      // Optional: Verify token with server (recommended)
      // You can add a simple API call here to validate the token
      // For now, just check if token exists
      return true;
      
      // Uncomment below if you want to verify token with server
      /*
      final response = await http.get(
        Uri.parse('YOUR_API_BASE_URL/verify-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      return response.statusCode == 200;
      */
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }

  // Check authentication and load initial data
  Future<void> _checkAuthenticationAndLoadData() async {
    try {
      // Check if user is authenticated using token
      _isAuthenticated = await _isUserAuthenticated();
      
      print('Authentication status: $_isAuthenticated'); // Debug log
      
      if (_isAuthenticated) {
        await _loadCartCount();
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error checking authentication: $e');
      _isAuthenticated = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_argumentsProcessed) {
      final args = ModalRoute.of(context)?.settings.arguments;
      print('ShowcaseScreen - Received args: $args');
      print('ShowcaseScreen - Args type: ${args.runtimeType}');
      
      if (args != null) {
        try {
          // Ensure we have a proper Map<String, dynamic>
          Map<String, dynamic> productData;
          if (args is Map<String, dynamic>) {
            productData = args;
          } else if (args is Map) {
            productData = Map<String, dynamic>.from(args);
          } else {
            print('ShowcaseScreen - Invalid argument type: ${args.runtimeType}');
            return;
          }

          setState(() {
            product = productData;
            _argumentsProcessed = true;
          });
          
          print('ShowcaseScreen - Product set successfully');
          print('ShowcaseScreen - Product name: ${product?['name']}');
          print('ShowcaseScreen - Product ID: ${product?['_id']}');
        } catch (e) {
          print('ShowcaseScreen - Error processing arguments: $e');
        }
      } else {
        print('ShowcaseScreen - No arguments received');
      }
    }
  }

  Future<void> _loadCartCount() async {
    if (!_isAuthenticated) return;
    
    try {
      _cartItemCount = await CartService.getCartItemCount();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading cart count: $e');
      // If cart service fails due to auth, user might not be logged in
      if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        _isAuthenticated = false;
        // Clear the token if it's invalid
        await _clearAuthToken();
        if (mounted) setState(() {});
      }
    }
  }

  // Clear auth token
  Future<void> _clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Handle cart navigation with auth check
  Future<void> _handleCartNavigation() async {
    try {
      // Re-check authentication before navigating
      bool isLoggedIn = await _isUserAuthenticated();
      
      print('Cart navigation - Auth check: $isLoggedIn'); // Debug log
      
      if (!isLoggedIn) {
        _showAuthRequiredDialog('cart');
        return;
      }

      await Navigator.pushNamed(context, '/cart');
      // Reload cart count after returning from cart screen
      await _loadCartCount();
    } catch (e) {
      print('Error navigating to cart: $e');
      _showAuthRequiredDialog('cart');
    }
  }

  // Handle profile navigation with auth check
  Future<void> _handleProfileNavigation() async {
    try {
      // Re-check authentication before navigating
      bool isLoggedIn = await _isUserAuthenticated();
      
      print('Profile navigation - Auth check: $isLoggedIn'); // Debug log
      
      if (!isLoggedIn) {
        _showAuthRequiredDialog('profile');
        return;
      }

      await Navigator.pushNamed(context, '/profile');
    } catch (e) {
      print('Error navigating to profile: $e');
      _showAuthRequiredDialog('profile');
    }
  }

  // Show dialog when authentication is required
  void _showAuthRequiredDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Authentication Required'),
          content: Text('Please log in to access your $feature.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Log In'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToCart() async {
    if (product == null) {
      print('Cannot add to cart - product is null');
      return;
    }

    // Check authentication before adding to cart
    try {
      bool isLoggedIn = await _isUserAuthenticated();
      if (!isLoggedIn) {
        _showAuthRequiredDialog('cart');
        return;
      }
    } catch (e) {
      print('Error checking auth for add to cart: $e');
      _showAuthRequiredDialog('cart');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      for (int i = 0; i < _quantity; i++) {
        await CartService.addToCart(Map<String, dynamic>.from(product!));
      }

      await _loadCartCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product!['name']} added to cart ($_quantity items)'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        String errorMessage = 'Error adding item to cart';
        
        // Check if it's an authentication error
        if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
          errorMessage = 'Please log in to add items to cart';
          _isAuthenticated = false;
          await _clearAuthToken();
          setState(() {});
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle logout with proper navigation
  Future<void> _handleLogout() async {
    try {
      await AuthService.logout();
      await _clearAuthToken(); // Ensure token is cleared
      _isAuthenticated = false;
      _cartItemCount = 0;
      
      if (mounted) {
        setState(() {});
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      // Force logout even if there's an error
      await _clearAuthToken();
      _isAuthenticated = false;
      _cartItemCount = 0;
      
      if (mounted) {
        setState(() {});
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ShowcaseScreen - Build called, product: ${product != null ? "exists" : "null"}');
    print('ShowcaseScreen - Auth status: $_isAuthenticated'); // Debug log
    
    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No product data available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _isAuthenticated ? _cartItemCount : 0,
        onCartTap: _handleCartNavigation, // Use auth-aware navigation
        onProfileTap: _handleProfileNavigation, // Use auth-aware navigation
        onLogout: _handleLogout, // Use proper logout handler
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
              child: _buildProductImage(),
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
                    product!['name']?.toString() ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category
                  if (product!['category'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        product!['category'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Price Section
                  _buildPriceSection(),
                  const SizedBox(height: 16),

                  // Availability Status
                  _buildAvailabilitySection(),
                  const SizedBox(height: 20),

                  // Description
                  _buildDescriptionSection(),
                  const SizedBox(height: 20),

                  // Product Details
                  _buildProductDetailsSection(),
                  const SizedBox(height: 20),

                  // Quantity Selector and Total Price (only if available)
                  if (product!['isAvailable'] == true) ...[
                    _buildQuantitySelector(),
                    const SizedBox(height: 16),
                    _buildTotalPriceSection(),
                  ],
                ],
              ),
            ),
            
            // Divider before related products
            Container(
              height: 8,
              color: Colors.grey.shade100,
            ),
            
            // Related Products Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_basket,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'More Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover more items you might like',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Products Section Widget
            ProductsSection(
              refreshCartCount: _loadCartCount,
              isGuestMode: !_isAuthenticated, // Pass authentication state
            ),
            
            const SizedBox(height: 100), // Space for bottom navigation bar
          ],
        ),
      ),

      // Bottom Add to Cart Button
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildProductImage() {
    if (product!['imageUrl'] != null && product!['imageUrl'].toString().isNotEmpty) {
      return Image.network(
        product!['imageUrl'].toString(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image,
        size: 80,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildPriceSection() {
    double originalPrice = double.tryParse(product!['price']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(product!['discount']?.toString() ?? '0') ?? 0;
    bool hasDiscount = discount > 0;

    return Row(
      children: [
        if (hasDiscount) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BHD${originalPrice.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Row(
                children: [
                  Text(
                    'BHD${_calculateDiscountedPrice(originalPrice, discount)}',
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
                      '${discount.toInt()}% OFF',
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
            'BHD${originalPrice.toStringAsFixed(3)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
        Text(
          ' /${product!['unit']?.toString() ?? 'unit'}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    bool isAvailable = product!['isAvailable'] == true;
    return Row(
      children: [
        Icon(
          isAvailable ? Icons.check_circle : Icons.cancel,
          color: isAvailable ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isAvailable ? 'In Stock' : 'Out of Stock',
          style: TextStyle(
            fontSize: 14,
            color: isAvailable ? Colors.green.shade700 : Colors.red.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Qty: ${product!['quantity']?.toString() ?? '0'} ${product!['unit']?.toString() ?? 'units'} available',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          product!['description']?.toString() ?? 'No description available',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetailsSection() {
    return Container(
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
          _buildDetailRow('Product ID', product!['_id']?.toString() ?? 'N/A'),
          _buildDetailRow('Unit', product!['unit']?.toString() ?? 'N/A'),
          _buildDetailRow('Available Quantity', '${product!['quantity']?.toString() ?? '0'} ${product!['unit']?.toString() ?? 'units'}'),
          if (product!['discount'] != null && (double.tryParse(product!['discount'].toString()) ?? 0) > 0)
            _buildDetailRow('Discount', '${product!['discount']}%'),
          if (product!['tax'] != null && (double.tryParse(product!['tax'].toString()) ?? 0) > 0)
            _buildDetailRow('Tax', '${product!['tax']}%'),
          if (product!['hasVAT'] == true)
            _buildDetailRow('VAT', 'Applicable'),
          if (product!['createdAt'] != null)
            _buildDetailRow('Listed On', _formatDate(product!['createdAt'].toString())),
          if (product!['updatedAt'] != null)
            _buildDetailRow('Last Updated', _formatDate(product!['updatedAt'].toString())),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    int maxQuantity = int.tryParse(product!['quantity']?.toString() ?? '1') ?? 1;
    
    return Row(
      children: [
        Text(
          'Quantity: ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _quantity > 1 ? () {
                  setState(() {
                    _quantity--;
                  });
                } : null,
                icon: const Icon(Icons.remove),
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _quantity.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _quantity < maxQuantity ? () {
                  setState(() {
                    _quantity++;
                  });
                } : null,
                icon: const Icon(Icons.add),
                iconSize: 20,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Max: $maxQuantity',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalPriceSection() {
    double discount = double.tryParse(product!['discount']?.toString() ?? '0') ?? 0;
    double tax = double.tryParse(product!['tax']?.toString() ?? '0') ?? 0;
    bool hasDiscount = discount > 0;
    bool hasTax = tax > 0;
    bool hasVAT = product!['hasVAT'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                'BHD${_calculateSubtotal()}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount (${discount.toInt()}%):',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade600,
                  ),
                ),
                Text(
                  '-BHD${_calculateDiscountAmount()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ],
          if (hasTax) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tax (${tax.toInt()}%):',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'BHD${_calculateTaxAmount()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
          if (hasVAT) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VAT:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Included',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'BHD${_calculateTotalPrice()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    bool isAvailable = product!['isAvailable'] == true;
    
    if (!_isAuthenticated) {
      // Show login prompt for unauthenticated users
      return Container(
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
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login),
              label: const Text(
                'Login to Add to Cart',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
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
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: isAvailable 
            ? ElevatedButton.icon(
                onPressed: _isLoading ? null : _addToCart,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: Text(
                  _isLoading ? 'Adding...' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : Container(
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

  // Helper methods for price calculations
  String _calculateDiscountedPrice(double price, double discount) {
    double discountedPrice = price * (1 - discount / 100);
    return discountedPrice.toStringAsFixed(3);
  }

  String _calculateSubtotal() {
    double price = double.tryParse(product!['price']?.toString() ?? '0') ?? 0;
    return (price * _quantity).toStringAsFixed(3);
  }

  String _calculateDiscountAmount() {
    double price = double.tryParse(product!['price']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(product!['discount']?.toString() ?? '0') ?? 0;
    double discountAmount = (price * _quantity) * (discount / 100);
    return discountAmount.toStringAsFixed(3);
  }

  String _calculateTaxAmount() {
    double price = double.tryParse(product!['price']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(product!['discount']?.toString() ?? '0') ?? 0;
    double tax = double.tryParse(product!['tax']?.toString() ?? '0') ?? 0;

    // Calculate price after discount
    double discountedPrice = price * (1 - discount / 100);
    double taxAmount = (discountedPrice * _quantity) * (tax / 100);
    return taxAmount.toStringAsFixed(3);
  }

  String _calculateTotalPrice() {
    double price = double.tryParse(product!['price']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(product!['discount']?.toString() ?? '0') ?? 0;
    double tax = double.tryParse(product!['tax']?.toString() ?? '0') ?? 0;

    // Calculate price after discount
    double discountedPrice = price * (1 - discount / 100);
    // Add tax to discounted price
    double finalPrice = discountedPrice * (1 + tax / 100);
    return (finalPrice * _quantity).toStringAsFixed(3);
  }
}