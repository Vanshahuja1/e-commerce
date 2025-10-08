import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/widgets/app_drawer.dart';
import '/widgets/search.dart';

import '/widgets/category.dart';
import '/widgets/products.dart';
import '/widgets/footer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _currentUser;
  int _cartItemCount = 0;
  bool _isLoggedIn = false;
  List<dynamic> _products = [];
  final GlobalKey<ProductsSectionState> _productsKey = GlobalKey<ProductsSectionState>();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _fetchProducts();
  }

  Future<void> _checkAuthStatus() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    if (_isLoggedIn) {
      await _loadUser();
      await _loadCartCount();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadUser() async {
    _currentUser = await AuthService.getCurrentUser();
    if (mounted) setState(() {});
  }

  Future<void> _loadCartCount() async {
    if (_isLoggedIn) {
      _cartItemCount = await CartService.getCartItemCount();
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchProducts() async {
    try {
      List<dynamic> allProducts = [];
      int page = 1;
      int totalPages = 1;

      do {
        final uri = Uri.parse(
            'https://e-com-backend-x67v.onrender.com/api/admin-items?page=' + page.toString());
        final response = await http.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode != 200) {
          return;
        }

        final data = json.decode(response.body);

        if (data is List) {
          allProducts = data;
          totalPages = 1;
          break;
        }

        if (data is Map && data.containsKey('items')) {
          final items = (data['items'] as List?) ?? [];
          allProducts.addAll(items);
          final tp = data['totalPages'];
          totalPages = tp is int ? tp : int.tryParse(tp?.toString() ?? '1') ?? 1;
        } else if (data is Map && data.containsKey('data')) {
          allProducts = (data['data'] as List?) ?? [];
          totalPages = 1;
          break;
        } else {
          allProducts = [data];
          totalPages = 1;
          break;
        }

        page++;
      } while (page <= totalPages);

      setState(() {
        _products = allProducts;
      });
    } catch (e) {
      // Handle error
    }
  }

  // Refresh method that will be called when user pulls to refresh
  Future<void> _onRefresh() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Refreshing...'),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Check auth status first
      await _checkAuthStatus();
      
      // Refresh all data concurrently if logged in
      List<Future> futures = [_refreshProducts(), _fetchProducts()];
      if (_isLoggedIn) {
        futures.addAll([_loadUser(), _loadCartCount()]);
      }
      
      await Future.wait(futures);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 16),
                const Text('Refreshed successfully!'),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 16),
                Text('Refresh failed: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Method to refresh products
  Future<void> _refreshProducts() async {
    if (_productsKey.currentState != null) {
      await _productsKey.currentState!.refreshProducts();
    }
  }

  // Add this method to refresh cart count when returning from other screens
  void _refreshCartCount() {
    if (_isLoggedIn) {
      _loadCartCount();
    }
  }

  // Handle search functionality
  void _handleSearch(String query) {
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'query': query},
    );
  }

  void _handleCartNavigation() {
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(context, '/cart').then((_) {
      // Refresh cart count when returning from cart
      _refreshCartCount();
    });
  }

  void _handleProfileNavigation() {
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(context, '/profile').then((_) {
      // Refresh user data when returning from profile
      _loadUser();
    });
  }

  void _handleSearchNavigation() {
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(context, '/search');
  }

  void _handleCategoriesNavigation() {
    // Navigate to categories page or scroll to categories section
    // For now, we can scroll to the top where categories are located
    // Or navigate to a dedicated categories page if you have one
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(context, '/search');
  }

  void _handleDiscountNavigation() {
    // Navigate to discount
    // You can customize this based on your needs
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    Navigator.pushNamed(context, '/discount'); // <-- update to '/discount'
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(products: _products),
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _cartItemCount,
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        onCartTap: _handleCartNavigation,
        onProfileTap: _handleProfileNavigation,
        onSearchTap: _handleSearchNavigation,
        onLogout: () async {
          if (_isLoggedIn) {
            await AuthService.logout();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.red.shade400,
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 40,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // This ensures pull-to-refresh works even when content doesn't fill the screen
          child: Column(
            children: [
              // Add SearchWidget right after the header
              SearchWidget(
                onSearch: _handleSearch,
                hintText: 'Search For Product',
              ),
              const SizedBox(height: 2),
              const CategorySection(),        // Move this first
              // Move this second  
              const SizedBox(height: 8),
              ProductsSection(               // Keep this third
                key: _productsKey,
                refreshCartCount: _refreshCartCount,
                isGuestMode: !_isLoggedIn,
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Footer(
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        currentIndex: 0,
        onHomeTap: () {},
        onCategoriesTap: _handleCategoriesNavigation,
        onDiscountTap: _handleDiscountNavigation, // <-- this will now redirect to '/discount'
        onProfileTap: _handleProfileNavigation,
      ),
    );
  }
}