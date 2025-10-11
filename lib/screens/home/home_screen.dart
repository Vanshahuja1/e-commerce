import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/widgets/app_drawer.dart';
import '/widgets/search.dart';
import '/services/local_cart_service.dart'; // Added import
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
  bool _isCheckingAuth = true;
  List<dynamic> _products = [];
  final GlobalKey<ProductsSectionState> _productsKey = GlobalKey<ProductsSectionState>();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _isLoggedIn = await AuthService.isLoggedIn();

    await _loadUser(); // only sets when logged in
    await _loadCartCount();
    await _fetchProducts();

    if (mounted) {
      setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _loadUser() async {
    if (_isLoggedIn) {
      _currentUser = await AuthService.getCurrentUser();
      if (mounted) setState(() {});
    } else {
      _currentUser = null;
    }
  }

  Future<void> _loadCartCount() async {
    if (_isLoggedIn) {
      _cartItemCount = await CartService.getCartItemCount();
    } else {
      _cartItemCount = await LocalCartService.getCartItemCount();
    }
    if (mounted) setState(() {});
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
  void _refreshCartCount() async {
    await _loadCartCount();
  }

  // Handle search functionality
  void _handleSearch(String query) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {'query': query},
    );
  }

  void _handleCartNavigation() {
    Navigator.pushNamed(context, '/cart').then((_) {
      // Refresh cart count when returning from cart
      _refreshCartCount();
    });
  }

  void _handleProfileNavigation() {
    Navigator.pushNamed(context, '/profile').then((_) {
      // Refresh user data when returning from profile
      _loadUser();
    });
  }

  void _handleSearchNavigation() {
    Navigator.pushNamed(context, '/search');
  }

  void _handleCategoriesNavigation() {
    // Navigate to categories page or scroll to categories section
    Navigator.pushNamed(context, '/search');
  }

  void _handleDiscountNavigation() {
    // Navigate to discount
    Navigator.pushNamed(context, '/discount');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking authentication
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.red.shade400,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            await _loadCartCount(); // refresh to guest cart count after logout
            if (mounted) setState(() { _isLoggedIn = false; _currentUser = null; });
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.red.shade400,
        backgroundColor: Colors.grey.shade200,
        strokeWidth: 3,
        displacement: 40,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SearchWidget(
                onSearch: _handleSearch,
                hintText: 'Search For Product',
              ),
              const SizedBox(height: 2),
              const CategorySection(),
              const SizedBox(height: 8),
              ProductsSection(
                key: _productsKey,
                refreshCartCount: _refreshCartCount,
                isGuestMode: !_isLoggedIn, // allow guest cart
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
        onDiscountTap: _handleDiscountNavigation,
        onProfileTap: _handleProfileNavigation,
      ),
    );
  }
}
