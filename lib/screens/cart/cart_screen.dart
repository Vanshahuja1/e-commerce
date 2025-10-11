import 'package:flutter/material.dart';
import '/services/cart_service.dart';
import '/widgets/header.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/local_cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  UserModel? _currentUser;
  int _cartItemCount = 0;
  Map<String, double> _cartSummary = {
    'originalTotal': 0.0,
    'subtotal': 0.0,
    'totalSavings': 0.0,
    'totalTax': 0.0,
    'finalTotal': 0.0,
  };
  bool _isProcessing = false;
  bool _isLoggedIn = false; // 
  final TextEditingController _specialRequestsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    await _loadUser();
    await _loadCart();
  }

  Future<void> _loadUser() async {
    if (_isLoggedIn) {
      _currentUser = await AuthService.getCurrentUser();
    } else {
      _currentUser = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadCart() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (_isLoggedIn) {
        final items = await CartService.getCartItems();
        final count = await CartService.getCartItemCount();
        final summary = await CartService.getCartSummary();

        if (mounted) {
          setState(() {
            cartItems = List<Map<String, dynamic>>.from(items);
            _cartItemCount = count;
            _cartSummary = summary;
            isLoading = false;
          });
        }
      } else {
        final items = await LocalCartService.getCartItems();
        final count = await LocalCartService.getCartItemCount();
        final summary = await LocalCartService.getCartSummary();
        if (mounted) {
          setState(() {
            cartItems = items;
            _cartItemCount = count;
            _cartSummary = summary;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cart: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(int index, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(index);
      return;
    }

    final item = cartItems[index];
    final productId = (item['_id'] ?? item['productId']).toString();

    try {
      setState(() {
        _isProcessing = true;
      });

      if (_isLoggedIn) {
        await CartService.updateQuantity(productId, newQuantity);
      } else {
        await LocalCartService.updateQuantity(productId, newQuantity);
      }
      await _loadCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quantity updated to $newQuantity'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quantity: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _removeItem(int index) async {
    final item = cartItems[index];
    final productId = (item['_id'] ?? item['productId']).toString();
    final productName = item['name'];

    try {
      setState(() {
        _isProcessing = true;
      });

      if (_isLoggedIn) {
        await CartService.removeFromCart(productId);
      } else {
        await LocalCartService.removeFromCart(productId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName removed from cart'),
            backgroundColor: Colors.red.shade400,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                if (_isLoggedIn) {
                  await CartService.addToCart(item);
                } else {
                  await LocalCartService.addToCart(item);
                }
                await _loadCart();
              },
            ),
          ),
        );
      }

      await _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing item: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _clearCart() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                _isProcessing = true;
              });

              try {
                if (_isLoggedIn) {
                  await CartService.clearCart();
                } else {
                  await LocalCartService.clearCart();
                }
                await _loadCart();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Cart cleared successfully'),
                      backgroundColor: Colors.red.shade400,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing cart: ${e.toString()}'),
                      backgroundColor: Colors.red.shade400,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() {
                  _isProcessing = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isLoggedIn) {
      await Navigator.pushNamed(context, '/login');
      _isLoggedIn = await AuthService.isLoggedIn();
      if (!_isLoggedIn) return;

      try {
        final localItems = await LocalCartService.getCartItems();
        for (final it in localItems) {
          final times = it['quantity'] as int? ?? 1;
          for (int i = 0; i < times; i++) {
            await CartService.addToCart(Map<String, dynamic>.from(it));
          }
        }
        await LocalCartService.clearCart();
        await _loadCart();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync cart after login. Please try again.'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
        return;
      }
    }

    Navigator.pushNamed(
      context,
      '/payment',
      arguments: {
        'amount': _cartSummary['finalTotal'],
        'cartItems': cartItems,
        'specialRequests': _specialRequestsController.text.trim(),
        'cartSummary': _cartSummary,
      },
    );
  }

  Map<String, double> _calculateItemPrices(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int? ?? 1;
    final originalPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
    final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
    final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;

    final discountedPrice = originalPrice * (1 - discount / 100);
    final finalPriceWithTax = discountedPrice * (1 + tax / 100);

    final itemOriginalTotal = originalPrice * quantity;
    final itemDiscountedTotal = discountedPrice * quantity;
    final itemFinalTotal = finalPriceWithTax * quantity;
    final itemSavings = (originalPrice - discountedPrice) * quantity;
    final itemTaxAmount = (finalPriceWithTax - discountedPrice) * quantity;

    return {
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'finalPriceWithTax': finalPriceWithTax,
      'itemOriginalTotal': itemOriginalTotal,
      'itemDiscountedTotal': itemDiscountedTotal,
      'itemFinalTotal': itemFinalTotal,
      'itemSavings': itemSavings,
      'itemTaxAmount': itemTaxAmount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "My Cart",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Kanwarji's",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your cart...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _buildCartContent(),
      bottomNavigationBar: _buildBottomSection(),
    );
  }

  Widget _buildCartContent() {
    if (cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to your cart to see them here',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/search'),
              icon: const Icon(Icons.search),
              label: const Text('Browse Products'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Cart (${cartItems.length} ${cartItems.length == 1 ? 'item' : 'items'})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              TextButton.icon(
                onPressed: _isProcessing ? null : _clearCart,
                icon: Icon(
                  Icons.delete_outline,
                  color: _isProcessing ? Colors.grey : Colors.red.shade400,
                  size: 18,
                ),
                label: Text(
                  'Clear Cart',
                  style: TextStyle(
                    color: _isProcessing ? Colors.grey : Colors.red.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCart,
            color: Colors.red.shade400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _buildCartItem(item, index);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Special requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _specialRequestsController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Any Special requests ?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final quantity = item['quantity'] as int? ?? 1;

    final prices = _calculateItemPrices(item);
    final originalPrice = prices['originalPrice']!;
    final discountedPrice = prices['discountedPrice']!;
    final finalPriceWithTax = prices['finalPriceWithTax']!;
    final itemFinalTotal = prices['itemFinalTotal']!;
    final itemSavings = prices['itemSavings']!;

    final discount = (item['discount'] as num?)?.toDouble() ?? 0.0;
    final tax = (item['tax'] as num?)?.toDouble() ?? 0.0;

    return Dismissible(
      key: Key(item['_id']?.toString() ?? item['productId']?.toString() ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) => _removeItem(index),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['imageUrl'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image,
                              size: 30,
                              color: Colors.grey.shade400,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.image,
                        size: 30,
                        color: Colors.grey.shade400,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? 'Unknown Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '₹${finalPriceWithTax.toStringAsFixed(3)} / ${item['unit']?.toString() ?? 'unit'}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color.fromARGB(255, 26, 26, 26),
                              ),
                            ),
                            if (discount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${originalPrice.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (discount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${discount.toStringAsFixed(0)}% OFF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (tax > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${tax.toStringAsFixed(0)}% Tax',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: _isProcessing ? null : () => _updateQuantity(index, quantity - 1),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: _isProcessing ? Colors.grey.shade200 : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: _isProcessing ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  quantity.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _isProcessing ? null : () => _updateQuantity(index, quantity + 1),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: _isProcessing ? Colors.grey.shade200 : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: _isProcessing ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${itemFinalTotal.toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(255, 6, 6, 6),
                              ),
                            ),
                            if (itemSavings > 0) ...[
                              Text(
                                'Save ₹${itemSavings.toStringAsFixed(3)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cartItems.isNotEmpty && _cartSummary['finalTotal']! > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal (after discount):',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${_cartSummary['subtotal']!.toStringAsFixed(3)}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (_cartSummary['totalSavings']! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Savings:',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${_cartSummary['totalSavings']!.toStringAsFixed(3)}',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_cartSummary['totalTax']! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Tax:',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${_cartSummary['totalTax']!.toStringAsFixed(3)}',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Final Price:',
                            style: TextStyle(
                              color: const Color.fromARGB(255, 14, 14, 14),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${_cartSummary['finalTotal']!.toStringAsFixed(3)}',
                            style: TextStyle(
                              color: const Color.fromARGB(255, 5, 5, 5),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cartSummary['totalSavings']! > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'You Save',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${_cartSummary['totalSavings']!.toStringAsFixed(3)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total (incl. tax)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '₹${_cartSummary['finalTotal']!.toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isProcessing || cartItems.isEmpty ? null : _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: _isProcessing
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Processing...'),
                                ],
                              )
                            : const Text('Checkout'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
