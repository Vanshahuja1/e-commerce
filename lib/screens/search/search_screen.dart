import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

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
  bool _hasHandledArgsAndFetched = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCartCount();
  }

 @override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_hasHandledArgsAndFetched) {
    final args = ModalRoute.of(context)?.settings.arguments;
    print('DEBUG: didChangeDependencies called. Route arguments: $args');
    
    if (args != null && args is Map<String, dynamic>) {
      // Handle category argument (existing functionality)
      if (args.containsKey('category')) {
        selectedCategory = args['category'] as String;
        print('DEBUG: selectedCategory set to: $selectedCategory');
        _searchController.text = selectedCategory!;
      }
      
      // Handle query argument (new functionality for search)
      if (args.containsKey('query')) {
        final query = args['query'] as String;
        print('DEBUG: query set to: $query');
        _searchController.text = query;
        // Don't set selectedCategory for regular queries
        selectedCategory = null;
      }
    } else {
      print('DEBUG: No arguments found.');
    }
    
    fetchProducts();
    _hasHandledArgsAndFetched = true;
  }
}
  

  Future<void> _loadUser() async {
    _currentUser = await AuthService.getCurrentUser();
    if (mounted) setState(() {});
  }

  Future<void> _loadCartCount() async {
    _cartItemCount = await CartService.getCartItemCount();
    if (mounted) setState(() {});
  }

  Future<void> loadCartQuantities() async {
    try {
      final cartItems = await CartService.getCartItems();
      setState(() {
        cartQuantities.clear();
        for (var item in cartItems) {
          String productId = item['_id']?.toString() ?? 
                           item['productId']?.toString() ?? 
                           item['id']?.toString() ?? '';
          if (productId.isNotEmpty) {
            cartQuantities[productId] = item['quantity'] ?? 1;
          }
        }
      });
    } catch (e) {
      print('Error loading cart quantities: $e');
    }
  }

  Future<void> fetchProducts() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/admin-items'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> loadedProducts = [];
        if (data is List) {
          loadedProducts = data;
        } else if (data is Map && data.containsKey('items')) {
          loadedProducts = data['items'];
        } else if (data is Map && data.containsKey('data')) {
          loadedProducts = data['data'];
        } else {
          loadedProducts = [data];
        }
        setState(() {
          products = loadedProducts;
        });
        filterProducts();
        await loadCartQuantities(); // Load cart quantities after fetching products
        setState(() {
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
    try {
      await CartService.addToCart(Map<String, dynamic>.from(product));
      String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
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
            backgroundColor: Colors.red.shade600,
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

  void _selectCategory(String category) {
    setState(() {
      if (selectedCategory == category) {
        selectedCategory = null;
        _searchController.clear();
      } else {
        selectedCategory = category;
        _searchController.text = category;
      }
      filterProducts();
    });
  }

  void _selectPriceSort(PriceSortOption option) {
    setState(() {
      selectedPriceSort = option;
      filterProducts();
    });
  }

  void _showPriceSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: Colors.green.shade700, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by Price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              ...PriceSortOption.values.map((option) {
                bool isSelected = selectedPriceSort == option;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: Colors.green.shade200) : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      _getSortIcon(option),
                      color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                    title: Text(
                      _getPriceSortLabel(option),
                      style: TextStyle(
                        color: isSelected ? Colors.green.shade700 : Colors.grey.shade800,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.green.shade700)
                        : null,
                    onTap: () {
                      _selectPriceSort(option);
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getSortIcon(PriceSortOption option) {
    switch (option) {
      case PriceSortOption.none:
        return Icons.clear_all;
      case PriceSortOption.lowToHigh:
        return Icons.arrow_upward;
      case PriceSortOption.highToLow:
        return Icons.arrow_downward;
    }
  }

  String _getPriceSortLabel(PriceSortOption option) {
    switch (option) {
      case PriceSortOption.none:
        return 'Default Sorting';
      case PriceSortOption.lowToHigh:
        return 'Price: Low to High';
      case PriceSortOption.highToLow:
        return 'Price: High to Low';
    }
  }

  Future<void> _handleRefresh() async {
    await fetchProducts();
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [
      'All',
      'Fresh Fruit',
    'Vegetables',
    'Herbs & Lettuce',
    'Dried Fruit',
    ];
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _cartItemCount,
        currentUser: _currentUser,
        onCartTap: () async {
          await Navigator.pushNamed(context, '/cart');
          _loadCartCount();
        },
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        // onSellerTap REMOVED
        onLogout: () async {
          await AuthService.logout();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.green.shade700,
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        child: Column(
          children: [
            Container(
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
                      prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  selectedCategory = null;
                                });
                                _onSearchChanged();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPriceSortBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedPriceSort != PriceSortOption.none
                                  ? Colors.green.shade50
                                  : Colors.white,
                              border: Border.all(
                                color: selectedPriceSort != PriceSortOption.none
                                    ? Colors.green.shade700
                                    : Colors.grey.shade300,
                                width: selectedPriceSort != PriceSortOption.none ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sort,
                                  color: selectedPriceSort != PriceSortOption.none
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getPriceSortLabel(selectedPriceSort),
                                    style: TextStyle(
                                      color: selectedPriceSort != PriceSortOption.none
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                      fontWeight: selectedPriceSort != PriceSortOption.none
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: selectedPriceSort != PriceSortOption.none
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (selectedCategory != null || selectedPriceSort != PriceSortOption.none)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                selectedCategory = null;
                                selectedPriceSort = PriceSortOption.none;
                                _searchController.clear();
                                filterProducts();
                              });
                            },
                            icon: Icon(
                              Icons.clear_all,
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                            tooltip: 'Clear all filters',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (_) => _selectCategory(category),
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Colors.green.shade100,
                            checkmarkColor: Colors.green.shade700,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.green.shade700 : Colors.grey.shade800,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? Colors.green.shade700 : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (selectedCategory != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Filtering by: ${selectedCategory!}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green.shade700),
            const SizedBox(height: 16),
            Text(
              'Loading products...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              onPressed: fetchProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    if (filteredProducts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedCategory != null
                      ? 'No products found in ${selectedCategory!}'
                      : 'Try a different search term',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedCategory = null;
                      selectedPriceSort = PriceSortOption.none;
                      _searchController.clear();
                      filterProducts();
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: _getChildAspectRatio(screenWidth),
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            return _buildProductCard(product, screenWidth);
          },
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

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/showcase',
          arguments: product,
        );
      },
      child: IntrinsicHeight(
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
                  child: ClipRRect(
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
                      // Price
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'BHD ${product['price']?.toString() ?? '0.225'}',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 