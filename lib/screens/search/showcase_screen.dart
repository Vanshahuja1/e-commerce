import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/services/auth_service.dart';
import '/widgets/products.dart';
import '/services/local_cart_service.dart';

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
  bool _isAuthenticated = false;
  
  // Media carousel state
  final PageController _pageController = PageController();
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;
  Timer? _autoPageTimer;
  
  // Expansion states for accordions
  bool _expProductDetails = false;
  bool _expShipping = false;
  bool _expHelp = false;
  bool _expFaq = false;
  
  // Sub-expansion states for FAQs
  bool _faqReturn = false;
  bool _faqMade = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoadData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> _isUserAuthenticated() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideo();
    _stopAutoSlide();
    super.dispose();
  }

  Future<void> _checkAuthenticationAndLoadData() async {
    try {
      _isAuthenticated = await _isUserAuthenticated();
      print('Authentication status: $_isAuthenticated');
      
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
      
      if (args != null) {
        try {
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
          
          _currentPage = 0;
          _disposeVideo();
          _startAutoSlide();
          
          print('ShowcaseScreen - Product set successfully');
       
        } catch (e) {
          print('ShowcaseScreen - Error processing arguments: $e');
        }
      }
    }
  }

  Future<void> _loadCartCount() async {
    if (!_isAuthenticated) {
      _cartItemCount = await LocalCartService.getCartItemCount();
      if (mounted) setState(() {});
      return;
    }
    try {
      _cartItemCount = await CartService.getCartItemCount();
      if (mounted) setState(() {});
    } catch (e) {
      _cartItemCount = await LocalCartService.getCartItemCount();
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> _handleCartNavigation() async {
    await Navigator.pushNamed(context, '/cart');
    await _loadCartCount();
  }

  Future<void> _handleProfileNavigation() async {
    try {
      bool isLoggedIn = await _isUserAuthenticated();
      
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
                backgroundColor: Colors.red.shade400,
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
    if (product == null) return;

    setState(() { _isLoading = true; });

    try {
      if (_isAuthenticated) {
        for (int i = 0; i < _quantity; i++) {
          await CartService.addToCart(Map<String, dynamic>.from(product!));
        }
      } else {
        await LocalCartService.addToCart(Map<String, dynamic>.from(product!), quantity: _quantity);
      }

      await _loadCartCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product!['name']} added to cart ($_quantity items)'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.logout();
      await _clearAuthToken();
      _isAuthenticated = false;
      _cartItemCount = 0;
      
      if (mounted) {
        setState(() {});
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error during logout: $e');
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
    if (product == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.red.shade400,
          ),
        ),
      );
    }

    bool isAvailable = product!['isAvailable'] == true;
    if (product!['isAvailable'] == null) {
      isAvailable = true;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: Header(
        cartItemCount: _cartItemCount,
        isLoggedIn: _isAuthenticated,  
        onCartTap: _handleCartNavigation,
        onProfileTap: _handleProfileNavigation,
        onLogout: _handleLogout,
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
              child: _buildMediaCarousel(),
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
                          color: Colors.green.shade400,
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

                  // Quantity Selector (only if available)
                  if (isAvailable) ...[
                    _buildQuantitySelector(),
                    const SizedBox(height: 16),
                    // Info Accordions (after quantity)
                    _buildInfoAccordions(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
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
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shop more for less',
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
              isGuestMode: !_isAuthenticated,
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),

      // Bottom Add to Cart Button
      bottomNavigationBar: _buildBottomButton(),
    );
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
                '₹${originalPrice.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Row(
                children: [
                  Text(
                    '₹${_calculateDiscountedPrice(originalPrice, discount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 7, 7, 7),
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
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ] else ...[
          Text(
            '₹${originalPrice.toStringAsFixed(3)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 20, 20, 20),
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

  List<Map<String, String>> _getMediaItems() {
    final List<Map<String, String>> items = [];
    final p = product;
    if (p == null) return items;

    final imgs = p['images'];
    if (imgs is List) {
      for (final it in imgs) {
        final url = it?.toString();
        if (url != null && url.isNotEmpty) {
          items.add({'type': 'image', 'url': url});
        }
      }
    }

    if (items.isEmpty) {
      final imgUrls = p['imageUrls'];
      if (imgUrls is List) {
        for (final it in imgUrls) {
          final url = it?.toString();
          if (url != null && url.isNotEmpty) {
            items.add({'type': 'image', 'url': url});
          }
        }
      }
    }

    if (items.isEmpty) {
      final single = p['imageUrl']?.toString();
      if (single != null && single.isNotEmpty) {
        items.add({'type': 'image', 'url': single});
      }
    }

    final video = p['videoUrl']?.toString();
    if (video != null && video.isNotEmpty) {
      items.add({'type': 'video', 'url': video});
    }

    print('Showcase media items count: ${items.length}');
    if (items.isNotEmpty) {
      print('First media item type: ${items.first['type']} url: ${items.first['url']}');
    }

    return items;
  }

  void _disposeVideo() {
    try {
      _videoController?.pause();
      _videoController?.dispose();
    } catch (_) {}
    _videoController = null;
    _initializeVideoFuture = null;
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    final media = _getMediaItems();
    if (media.length <= 1) return;
    if (media[_currentPage]['type'] == 'video') return;
    _autoPageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final m = _getMediaItems();
      if (m.isEmpty) return;
      if (m[_currentPage]['type'] == 'video') return;
      final next = (_currentPage + 1) % m.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoSlide() {
    _autoPageTimer?.cancel();
    _autoPageTimer = null;
  }

  void _initVideo(String url) {
    _disposeVideo();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _initializeVideoFuture = controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _videoController = controller;
    });
  }

  Widget _buildMediaCarousel() {
    final media = _getMediaItems();
    if (media.isEmpty) return _buildPlaceholderImage();

    if (media[_currentPage]['type'] == 'video' && _videoController == null) {
      _initVideo(media[_currentPage]['url']!);
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: media.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
            if (media[index]['type'] == 'video') {
              _initVideo(media[index]['url']!);
              _stopAutoSlide();
            } else {
              _disposeVideo();
              _startAutoSlide();
            }
          },
          itemBuilder: (context, index) {
            final item = media[index];
            if (item['type'] == 'video') {
              return _buildVideoPlayer(item['url']!);
            }
            return _buildNetworkImage(item['url']!);
          },
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(media.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 10 : 6,
                height: isActive ? 10 : 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.red.shade400 : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
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
  }

  Widget _buildVideoPlayer(String url) {
    if (_videoController == null) {
      _initVideo(url);
    }
    final controller = _videoController;
    final initFuture = _initializeVideoFuture;
    if (controller == null || initFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: IconButton(
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 36,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvailabilitySection() {
    bool isAvailable = product!['isAvailable'] == true;
    if (product!['isAvailable'] == null) {
      isAvailable = true;
    }

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
            color: isAvailable ? Colors.green.shade400 : Colors.red.shade400,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
 
  Widget _buildThinDivider() {
    return Container(
      height: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildInfoAccordions() {
    TextStyle headerStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade800,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThinDivider(),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            title: Text('Product Details', style: headerStyle),
            initiallyExpanded: _expProductDetails,
            trailing: Icon(
              _expProductDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
            ),
            onExpansionChanged: (v) => setState(() {
              _expProductDetails = v;
              if (v) {
                _expShipping = false;
                _expHelp = false;
                _expFaq = false;
              }
            }),
            childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Text(
                  _getProductDetailsText(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        _buildThinDivider(),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            initiallyExpanded: _expShipping,
            title: Text('Shipping & Returns', style: headerStyle),
            trailing: Icon(
              _expShipping ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
            ),
            onExpansionChanged: (v) => setState(() {
              _expShipping = v;
              if (v) {
                _expProductDetails = false;
                _expHelp = false;
                _expFaq = false;
              }
            }),
            childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Shipping: It takes 2-3 days for deliveries in Bangalore, whereas it takes 6-8 days for Nation and worldwide deliveries. Returns: We do not accept returns. Refunds are provided in certain cases. Please email us at info@kanwarjis.in with relevant information and images for assistance.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        _buildThinDivider(),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            title: Text('May We Help?', style: headerStyle),
            trailing: Icon(
              _expHelp ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
            ),
            onExpansionChanged: (v) => setState(() {
              _expHelp = v;
              if (v) {
                _expProductDetails = false;
                _expShipping = false;
                _expFaq = false;
              }
            }),
            childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'You can reach out to us for product related information, bulk inquiries or special requests at info@kanwarjis.in',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        _buildThinDivider(),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            title: Text('Have A Question? Read Our FAQs', style: headerStyle),
            trailing: Icon(
              _expFaq ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
            ),
            onExpansionChanged: (v) => setState(() {
              _expFaq = v;
              if (v) {
                _expProductDetails = false;
                _expShipping = false;
                _expHelp = false;
              }
            }),
            childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 12),
            children: [
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: const Text('Do you have a return or refund policy?'),
                  trailing: Icon(
                    _faqReturn ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 18,
                  ),
                  onExpansionChanged: (v) => setState(() {
                    _faqReturn = v;
                    if (v) {
                      _faqMade = false;
                    }
                  }),
                  childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'We do not accept returns. Refunds are provided in certain cases. Please email us at info@kanwarjis.in with relevant information and images for assistance.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              _buildThinDivider(),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: const Text('How are the products made? What you use in all your products?'),
                  trailing: Icon(
                    _faqMade ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 18,
                  ),
                  onExpansionChanged: (v) => setState(() {
                    _faqMade = v;
                    if (v) {
                      _faqReturn = false;
                    }
                  }),
                  childrenPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'All the ingredients used are single sourced origins and of premium quality.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildThinDivider(),
      ],
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
                onPressed: _quantity > 1
                    ? () {
                        setState(() {
                          _quantity--;
                        });
                      }
                    : null,
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
                onPressed: _quantity < maxQuantity
                    ? () {
                        setState(() {
                          _quantity++;
                        });
                      }
                    : null,
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

  Widget _buildBottomButton() {
    bool isAvailable = product!['isAvailable'] == true;
    if (product!['isAvailable'] == null) {
      isAvailable = true;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                  backgroundColor: Colors.red.shade400,
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

  String _calculateDiscountedPrice(double price, double discount) {
    double discountedPrice = price * (1 - discount / 100);
    return discountedPrice.toStringAsFixed(3);
  }

  String _getProductDetailsText() {
    final p = product;
    if (p == null) return 'No details available';

    final candidateKeys = [
      'productDetails',
      'product details',
      'description',
      'Product Details',
      'product_description',
    ];

    for (final key in candidateKeys) {
      if (p.containsKey(key)) {
        final v = p[key];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
        }
      }
    }

    final name = p['name']?.toString();
    final cat = p['category']?.toString();
    final unit = p['unit']?.toString();
    final qty = p['quantity']?.toString();
    final parts = <String>[];
    if (name != null && name.isNotEmpty) parts.add(name);
    if (cat != null && cat.isNotEmpty) parts.add('Category: $cat');
    if (qty != null && unit != null && qty.isNotEmpty && unit.isNotEmpty) {
      parts.add('Pack: $qty $unit');
    }
    return parts.isNotEmpty ? parts.join(' • ') : 'No details available';
  }
}