import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/cart_service.dart';
import '/services/local_cart_service.dart';
import '/widgets/header.dart';
import '/widgets/app_drawer.dart';
import '/widgets/search.dart';
import '/widgets/category.dart';
import '/widgets/products.dart';
import '/widgets/footer.dart';
import '/widgets/hero.dart';
import '/widgets/best_selling_products.dart';
import '/widgets/categories_showcase.dart';
import '/widgets/trust_row.dart';

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
    try {
      _isLoggedIn = await AuthService.isLoggedIn().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      await _loadUser();
      await _loadCartCount();
      await _fetchProducts();
    } catch (e) {
      print('Error in _checkAuthStatus: $e');
      _isLoggedIn = false;
      _currentUser = null;
      _cartItemCount = 0;
    } finally {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
      }
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

  // Add the missing _refreshCartCount method
  Future<void> _refreshCartCount() async {
    await _loadCartCount();
  }

  Future<void> _fetchProducts() async {
    try {
      int page = 1;
      int totalPages = 1;
      List<dynamic> allProducts = [];
      do {
        final uri = Uri.parse(
            'https://e-com-backend-x67v.onrender.com/api/admin-items?page=' + page.toString());
        final response = await http.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode != 200) {
          print('Failed to load products page $page: ${response.statusCode}');
          break;
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

      if (mounted) {
        setState(() {
          _products = allProducts;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        setState(() {
          _products = [];
        });
      }
    }
  }

  // Refresh method that will be called when user pulls to refresh
  Future<void> _onRefresh() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Refreshing...'),
              ],
            ),
          ),
        );
      }

      await _checkAuthStatus();

      List<Future> futures = [_fetchProducts()];
      if (_isLoggedIn) {
        futures.addAll([_loadUser(), _loadCartCount()]);
      }

      await Future.wait(futures);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Refresh completed successfully'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Refresh failed. Please try again.'),
              ],
            ),
          ),
        );
      }
    }
  }

  // Add this method to scroll to top when home is tapped in footer
  void _scrollToTop() {
    // Find the ScrollController and scroll to top
    // For now, we'll just trigger a refresh
    _onRefresh();
  }

  void _handleCartNavigation() {
    Navigator.pushNamed(context, '/cart').then((_) {
      _refreshCartCount();
    });
  }

  void _handleProfileNavigation() {
    Navigator.pushNamed(context, '/profile').then((_) {
      _loadUser();
    });
  }

  void _handleSearchNavigation() {
    Navigator.pushNamed(context, '/search');
  }

  void _handleCategoriesNavigation() {
    Navigator.pushNamed(context, '/search');
  }

  void _handleDiscountNavigation() {
    Navigator.pushNamed(context, '/discount');
  }

  Future<void> _handleLogout() async {
    if (_isLoggedIn) {
      await AuthService.logout();
      await _loadCartCount();
      if (mounted) setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: Header(
        cartItemCount: _cartItemCount,
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        onCartTap: _handleCartNavigation,
        onProfileTap: _handleProfileNavigation,
        onSearchTap: _handleSearchNavigation,
        onLogout: _handleLogout,
        showSidebarIcon: true,
      ),
      drawer: AppDrawer(products: _products),
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
              // Search Widget with scrolling banner (moved to top)
              const SearchWidget(),

              const SizedBox(height: 16),

              // Hero Carousel - 4 sliding images
              const HeroCarousel(),

              const SizedBox(height: 16),

              // Best Selling Products Section
              BestSellingProductsSection(
                refreshCartCount: _refreshCartCount,
                isGuestMode: !_isLoggedIn,
              ),

              const SizedBox(height: 8),

              // Categories Showcase - 6 categories with 4 products each
              CategoriesShowcase(
                refreshCartCount: _refreshCartCount,
                isGuestMode: !_isLoggedIn,
              ),

              const SizedBox(height: 16),

              // Trust/Credibility Section
              const TrustRow(),

              const SizedBox(height: 16),

              // About Us Section
              _buildAboutUsSection(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Footer(
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        onHomeTap: () {
          // Already on home screen, just scroll to top
          _scrollToTop();
        },
        onCategoriesTap: _handleCategoriesNavigation,
        onDiscountTap: _handleDiscountNavigation,
        onProfileTap: _handleProfileNavigation,
        currentIndex: 0, // Home is active
      ),
    );
  }

  Widget _buildAboutUsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Kanwarji',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kanwarji is your trusted partner for authentic, handcrafted food products that celebrate the rich taste of Indian tradition. We bring you the finest quality snacks and sweets, lovingly prepared using time-honored recipes and the purest ingredients. Every bite reflects our passion for excellence, freshness, and genuine flavor. With decades of dedication to quality and customer satisfaction, Kanwarji has become a beloved name across India — a symbol of trust, taste, and tradition that continues to delight families everywhere.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
          
        ],
      ),
    );
  }
}