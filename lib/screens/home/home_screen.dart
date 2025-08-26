import 'package:flutter/material.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/widgets/search.dart';  // Add this import
import '/widgets/hero.dart';
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
  final GlobalKey<ProductsSectionState> _productsKey = GlobalKey<ProductsSectionState>();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
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
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Check auth status first
      await _checkAuthStatus();
      
      // Refresh all data concurrently if logged in
      List<Future> futures = [_refreshProducts()];
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
            backgroundColor: Colors.green.shade600,
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
            backgroundColor: Colors.red.shade600,
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
    // Navigate to discount/offers page
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
        color: Colors.green.shade700,
        backgroundColor: Colors.white,
        strokeWidth: 3,
        displacement: 40,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // This ensures pull-to-refresh works even when content doesn't fill the screen
          child: Column(
            children: [
              // Add SearchWidget right after the header
              SearchWidget(
                onSearch: _handleSearch,
                hintText: 'Search For Product',
              ),
              const SizedBox(height: 2),
              const CategorySection(),        // Move this first
              const HeroSection(),           // Move this second  
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