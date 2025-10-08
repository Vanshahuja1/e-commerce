import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/widgets/footer.dart';
import '/widgets/products.dart';

class SearchScreen extends StatefulWidget {
  final bool isGuestMode;
  
  const SearchScreen({
    Key? key, 
    this.isGuestMode = false,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum PriceSortOption { none, lowToHigh, highToLow }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  bool isLoading = true;
  String? error;
  String? selectedCategory;
  PriceSortOption selectedPriceSort = PriceSortOption.none;
  UserModel? _currentUser;
  int _cartItemCount = 0;
  Map<String, int> cartQuantities = {}; 
  bool _isLoggedIn = false; // Auth token based login status

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read category argument from navigation
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('category')) {
      final String categoryFromArgs = arguments['category'] as String;
      // Set selected category and apply filtering
      if (mounted) {
        setState(() {
          selectedCategory = categoryFromArgs;
          _searchController.text = categoryFromArgs;
        });
        // Apply filtering after products are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            filterProducts();
          }
        });
      }
      print('DEBUG: Received category argument: $categoryFromArgs');
    }
  }

  Future<void> addItemToCart(dynamic product) async {
    // Check login status before adding to cart
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      await loadCartQuantities();
      await _loadCartCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item to cart: $e'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Future<void> _initializeScreen() async {
    await _checkLoginStatus(); // Check login status first
    await _loadUser();
    await _loadCartCount();
    await fetchProducts();
    await loadCartQuantities();
  }

  // Ensure login status is set
  Future<void> _checkLoginStatus() async {
    try {
      _isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) setState(() {});
    } catch (e) {
      _isLoggedIn = false;
    }
  }

  Future<void> _loadUser() async {
    try {
      if (_isLoggedIn) {
        _currentUser = await AuthService.getCurrentUser();
      } else {
        _currentUser = null;
      }
      if (mounted) setState(() {});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadCartCount() async {
    try {
      if (_isLoggedIn) {
        _cartItemCount = await CartService.getCartItemCount();
      } else {
        _cartItemCount = 0;
      }
      if (mounted) setState(() {});
    } catch (e) {
      // ignore
    }
  }

  Future<void> loadCartQuantities() async {
    try {
      final cartItems = await CartService.getCartItems();
      setState(() {
        cartQuantities.clear();
        for (var item in cartItems) {
          String productId = item['_id']?.toString() ?? item['productId']?.toString() ?? item['id']?.toString() ?? '';
          if (productId.isNotEmpty) {
            cartQuantities[productId] = item['quantity'] ?? 1;
          }
        }
      });
    } catch (e) {
      // ignore
    }
  }

  // Fetch products with pagination and apply to products + filteredProducts
  Future<void> fetchProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      List<dynamic> allProducts = [];
      int page = 1;
      int totalPages = 1;

      do {
        final uri = Uri.parse('https://e-com-backend-x67v.onrender.com/api/admin-items?page=' + page.toString());
        final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

        if (response.statusCode != 200) {
          setState(() {
            error = 'Failed to load products: ${response.statusCode}';
            isLoading = false;
          });
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
        products = allProducts;
      });
      // apply current filters
      filterProducts();
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> removeItemFromCart(dynamic product) async {
    // Check login status before removing from cart
    if (!_isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
      int currentQuantity = cartQuantities[productId] ?? 0;
      if (currentQuantity > 0) {
        if (currentQuantity == 1) {
          await CartService.removeFromCart(productId);
        } else {
          await CartService.updateQuantity(productId, currentQuantity - 1);
        }
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
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating cart: $e'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  void filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    List<dynamic> filtered;
    if (query.isEmpty && selectedCategory == null) {
      filtered = List.from(products);
    } else {
      filtered = products.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final description = product['description']?.toString().toLowerCase() ?? '';
        final category = product['category']?.toString().toLowerCase() ?? '';

        // Debug print to see what categories are in the products
        if (selectedCategory != null) {
          print('DEBUG: Product category: "$category", Selected category: "$selectedCategory"');
        }

        bool matchesSearch = query.isEmpty ||
            name.contains(query) ||
            description.contains(query) ||
            category.contains(query);
        bool matchesCategory = selectedCategory == null;
        if (selectedCategory != null) {
          final selectedCategoryLower = selectedCategory!.toLowerCase();
          matchesCategory = category == selectedCategoryLower ||
              category.contains(selectedCategoryLower) ||
              selectedCategoryLower.contains(category);
        }
        return matchesSearch && matchesCategory;
      }).toList();
    }
    print('DEBUG: Filtering with selectedCategory="$selectedCategory", query="$query", matches: ${filtered.length}');
    switch (selectedPriceSort) {
      case PriceSortOption.lowToHigh:
        filtered.sort((a, b) {
          double priceA = _parsePrice(a['price']);
          double priceB = _parsePrice(b['price']);
          return priceA.compareTo(priceB);
        });
        break;
      case PriceSortOption.highToLow:
        filtered.sort((a, b) {
          double priceA = _parsePrice(a['price']);
          double priceB = _parsePrice(b['price']);
          return priceB.compareTo(priceA);
        });
        break;
      case PriceSortOption.none:
        break;
    }
    setState(() {
      filteredProducts = filtered;
    });
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) {
      String cleanPrice = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanPrice) ?? 0.0;
    }
    return 0.0;
  }

  void _onSearchChanged() {
    setState(() {
      if (selectedCategory != null &&
          _searchController.text.trim().toLowerCase() != selectedCategory!.toLowerCase()) {
        selectedCategory = null;
      }
      filterProducts();
    });
  }



  // Categories row helpers
  final List<String> _categories = const [
    'Savory',
    'Namkeen',
    'Sweet',
    'Travel Pack Combo',
    'Value Pack Offers',
    'Gift Packs',
  ];

  // Dynamic categories from products data
  Set<String> _availableCategories = {};

  Widget _buildCategoriesRow() {
    // Update available categories from products
    if (products.isNotEmpty && _availableCategories.isEmpty) {
      _availableCategories = products
          .map((p) => p['category']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
      print('DEBUG: Available categories from products: $_availableCategories');
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('All'),
            selected: selectedCategory == null,
            onSelected: (_) {
              print('DEBUG: Selected category: All');
              setState(() {
                selectedCategory = null;
                _searchController.clear();
                filterProducts();
              });
            },
            selectedColor: Colors.red.shade400,
            labelStyle: TextStyle(
              color: selectedCategory == null ? Colors.white : Colors.grey.shade800,
            ),
            backgroundColor: Colors.grey.shade100,
            shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          ..._categories.map((name) {
            final bool isSelected = selectedCategory != null &&
                selectedCategory!.toLowerCase() == name.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    selectedCategory = name;
                    _searchController.text = name;
                    filterProducts();
                  });
                },
                selectedColor: Colors.red.shade400,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
                backgroundColor: Colors.grey.shade100,
                shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }).toList(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }


  Future<void> _handleRefresh() async {
    await _checkLoginStatus(); // Re-check login status on refresh
    await fetchProducts();
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        showSidebarIcon: false,
        cartItemCount: _cartItemCount,
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        onCartTap: () async {
          if (!_isLoggedIn) Navigator.pushNamed(context, '/login'); else {
            await Navigator.pushNamed(context, '/cart');
            _loadCartCount();
          }
        },
        onProfileTap: () async {
          if (!_isLoggedIn) Navigator.pushNamed(context, '/login'); else Navigator.pushNamed(context, '/profile');
        },
        onLogout: () async {
          await AuthService.logout();
          await _checkLoginStatus();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.red.shade400,
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        child: CustomScrollView(
          slivers: [
            // Search box and controls as SliverToBoxAdapter
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _onSearchChanged(),
                      decoration: InputDecoration(
                        hintText: selectedCategory != null 
                            ? 'Search in ${selectedCategory!}...' 
                            : 'Search For product',
                        prefixIcon: Icon(Icons.search, color: Colors.red.shade400),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    selectedCategory = null;
                                  });
                                  _onSearchChanged();
                                })
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: Colors.red.shade400, width: 2)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCategoriesRow(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Products as SliverToBoxAdapter containing SingleChildScrollView
            SliverToBoxAdapter(
              child: ProductsSection(
                refreshCartCount: _loadCartCount,
                isGuestMode: !_isLoggedIn,
                smallAddButton: true,
                crossAxisCount: 2,
                filterCategory: selectedCategory,
                filterQuery: _searchController.text.trim(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Footer(
        currentUser: _currentUser,
        isLoggedIn: _isLoggedIn,
        currentIndex: 1,
        onHomeTap: () => Navigator.pushReplacementNamed(context, '/home'),
        onCategoriesTap: () {},
        onDiscountTap: () => Navigator.pushNamed(context, '/discount'),
        onProfileTap: () async {
          if (!_isLoggedIn) Navigator.pushNamed(context, '/login'); else Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  // Legacy product-grid helpers removed: ProductsSection now renders product lists and cards.

  // Add-to-cart UI is handled inside ProductsSection; helper removed.

  // Placeholder image helper removed; ProductsSection handles image placeholders.

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}