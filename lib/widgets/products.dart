import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/cart_service.dart';

class ProductsSection extends StatefulWidget {
  final VoidCallback? refreshCartCount;
  final bool isGuestMode;
  final bool smallAddButton; // whether to render smaller add buttons
  final int crossAxisCount; // number of columns in grid
  final String? filterCategory; // optional category filter
  final String? filterQuery; // optional text query filter

  const ProductsSection({
    Key? key,
    this.refreshCartCount,
    this.isGuestMode = false,
    this.smallAddButton = true,
    this.crossAxisCount = 2,
    this.filterCategory,
    this.filterQuery,
  }) : super(key: key);

  @override
  ProductsSectionState createState() => ProductsSectionState();
}

class ProductsSectionState extends State<ProductsSection> {
  List<dynamic> products = [];
  bool isLoading = true;
  String? error;
  Map<String, int> cartQuantities = {};
  // track current page index for product image carousels
  final Map<String, int> _imagePageIndex = {};
  
  @override
  void initState() {
    super.initState();
    fetchProducts();
    if (!widget.isGuestMode) {
      loadCartQuantities();
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
            backgroundColor: Colors.red.shade400,
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
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
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
          setState(() {
            error = 'Failed to load products: ${response.statusCode}';
            isLoading = false;
          });
          return;
        }

        final data = json.decode(response.body);

        // If backend returns a raw list (no pagination), use it directly
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
        // Apply optional filters from widget
        var displayed = allProducts;
        if (widget.filterCategory != null && widget.filterCategory!.isNotEmpty) {
          displayed = displayed.where((p) {
            final cat = (p['category'] ?? '').toString().toLowerCase();
            return cat.contains(widget.filterCategory!.toLowerCase());
          }).toList();
        }
        if (widget.filterQuery != null && widget.filterQuery!.isNotEmpty) {
          final q = widget.filterQuery!.toLowerCase();
          displayed = displayed.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(q);
          }).toList();
        }
        products = displayed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
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
            backgroundColor: Colors.red.shade400,
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
                          color: Colors.red.shade400,
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
                          style: TextStyle(color: Colors.red.shade400),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => refreshProducts(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
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
                            backgroundColor: Colors.red.shade400,
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
                      physics: const ClampingScrollPhysics(),

                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.crossAxisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                      childAspectRatio: _getChildAspectRatio(screenWidth),
                    ),
                    itemCount: products.length,
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
    // Slightly reduced aspect ratios to just fix the 15px overflow
    if (screenWidth > 1200) {
      return 0.85; // Just enough to fix overflow
    } else if (screenWidth > 900) {
      return 0.82; // Just enough to fix overflow
    } else if (screenWidth > 600) {
      return 0.80; // Just enough to fix overflow
    } else if (screenWidth > 400) {
      return 0.78; // Just enough to fix overflow
    } else {
      return 0.75; // Just enough to fix overflow
    }
  }

  Widget _buildProductCard(dynamic product, double screenWidth) {
    String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    int quantity = cartQuantities[productId] ?? 0;

  double originalPrice = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
  double discount = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
    
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
            // Image Section with Horizontal PageView for multiple images
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
                child: _buildImageCarousel(product, screenWidth),
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
                  children: [
                    // Product Name with Add Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product['name']?.toString() ?? 'Unknown Product',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildAddButton(product, quantity, screenWidth),
                      ],
                    ),
                    const SizedBox(height: 1),
                    // Quantity/Weight - Made more compact
                    Text(
                    '${product['quantity']} ${product['unit']}'
,
                      style: TextStyle(
                        fontSize: screenWidth > 700 ? 9 : 8,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Price Section - Made more compact
                    hasDiscount
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹ ${originalPrice.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 9 : 8,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                '₹ ${discountedPrice.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(255, 23, 23, 23),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '₹ ${discountedPrice.toStringAsFixed(3)}',
                            style: TextStyle(
                              fontSize: screenWidth > 600 ? 12 : 10,
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
    // Allow a smaller add button for compact displays across app
    final useSmall = widget.smallAddButton;
    double buttonSize = useSmall ? (screenWidth > 600 ? 24 : 28) : (screenWidth > 600 ? 28 : 36);
    double iconSize = useSmall ? (screenWidth > 600 ? 12 : 14) : (screenWidth > 600 ? 14 : 18);
    double fontSize = useSmall ? (screenWidth > 600 ? 11 : 12) : (screenWidth > 600 ? 12 : 14);
    double rowPadding = screenWidth > 600 ? 6 : 8;

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
                blurRadius: 3,
                offset: const Offset(0, 1),
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
    }

    return Container(
      height: buttonSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 3,
            offset: const Offset(0, 1),
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

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image,
        size: 28, // Slightly reduced
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildImageCarousel(dynamic product, double screenWidth) {
    // Determine image list: prefer 'images' array, fallback to single 'imageUrl'
    List<String> images = [];
    if (product['images'] is List) {
      images = List<String>.from(product['images'].where((e) => e != null).map((e) => e.toString()));
    }
    if (images.isEmpty && product['imageUrl'] != null) {
      final s = product['imageUrl'].toString();
      // If comma-separated, split, else single
      if (s.contains(',')) {
        images = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (s.isNotEmpty) {
        images = [s];
      }
    }

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        child: _buildPlaceholderImage(),
      );
    }

    String productId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
    int initialPage = _imagePageIndex[productId] ?? 0;

    return Stack(
      children: [
        PageView.builder(
          key: ValueKey('pv-$productId'),
          itemCount: images.length,
          controller: PageController(initialPage: initialPage),
          onPageChanged: (idx) {
            setState(() {
              _imagePageIndex[productId] = idx;
            });
          },
          itemBuilder: (context, idx) {
            final img = images[idx];
            return ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: img.isNotEmpty
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            );
          },
        ),
        // Discount and VAT badges (compute locally)
        Builder(builder: (context) {
          double localDiscount = double.tryParse(product['discount']?.toString() ?? '0') ?? 0.0;
          bool localHasDiscount = localDiscount > 0;
          bool localHasVAT = product['hasVAT'] == true;
          return Stack(
            children: [
              if (localHasDiscount)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${localDiscount.toInt()}% OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth > 600 ? 10 : 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (localHasVAT)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'VAT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth > 600 ? 10 : 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        // Indicator intentionally hidden per user request
      ],
    );
  }
}