import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import 'order_invoice_generator.dart';
import '../../items/items.dart'; // Import for GroceryItems

// ----------- MODELS -----------

class SellerRequest {
  final String id;
  final String userName;
  final String userEmail;
  final String storeName;
  final String storeAddress;
  final String? businessLicense;
  final String status;
  final DateTime requestedAt;

  SellerRequest({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.storeName,
    required this.storeAddress,
    this.businessLicense,
    required this.status,
    required this.requestedAt,
  });

  factory SellerRequest.fromJson(Map<String, dynamic> json) {
    return SellerRequest(
      id: json['_id'] ?? '',
      userName: json['userName'] ?? json['userId']?['name'] ?? '',
      userEmail: json['userEmail'] ?? json['userId']?['email'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      businessLicense: json['businessLicense'],
      status: json['status'] ?? 'pending',
      requestedAt:
          DateTime.tryParse(json['requestedAt'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Seller {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String storeName;
  final String storeAddress;
  final bool isActive;
  final DateTime createdAt;

  Seller({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.storeName,
    required this.storeAddress,
    required this.isActive,
    required this.createdAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['_id'] ?? '',
      name: json['name'] ?? json['userId']?['name'] ?? '',
      email: json['email'] ?? json['userId']?['email'] ?? '',
      phone: json['phone'] ?? json['userId']?['phone'] ?? '',
      storeName: json['storeName'] ?? '',
      storeAddress: json['storeAddress'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final String sellerId;
  final String? sellerName;
  final DateTime createdAt;
  final int discount; // <-- Add this
  final int tax;      // <-- Add this
  final bool hasVAT;  // <-- Add this

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    required this.isAvailable,
    required this.sellerId,
    this.sellerName,
    required this.createdAt,
    this.discount = 0, // <-- Add this, default 0
    this.tax = 0,      // <-- Add this, default 0
    this.hasVAT = false, // <-- Add this, default false
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['images']?[0],
      isAvailable: json['isAvailable'] ?? true,
      sellerId: json['sellerId'] ?? json['seller']?['_id'] ?? '',
      sellerName: json['seller']?['storeName'] ?? json['sellerName'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      discount: json['discount'] ?? 0, // <-- Add this
      tax: json['tax'] ?? 0,           // <-- Add this
      hasVAT: json['hasVAT'] ?? false, // <-- Add this
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    String? sellerId,
    String? sellerName,
    DateTime? createdAt,
    int? discount,   // <-- Add this
    int? tax,        // <-- Add this
    bool? hasVAT,    // <-- Add this
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      createdAt: createdAt ?? this.createdAt,
      discount: discount ?? this.discount, // <-- Add this
      tax: tax ?? this.tax,                // <-- Add this
      hasVAT: hasVAT ?? this.hasVAT,       // <-- Add this
    );
  }
}

// ----------- MAIN DASHBOARD WIDGET -----------

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  // API BASE URL
  static const String _baseUrl =
      "https://e-com-backend-x67v.onrender.com/api";

  // Dashboard stats
  int _totalUsers = 0;
 int _totalProducts = 0;
 int _availableProducts = 0;
 int _hiddenProducts = 0;
// Add this:
 int _totalOrders = 0;
  // Seller Requests
  

  // Users
  List<User> _users = [];
  String _userSearchQuery = '';

  
  // Products
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _productSearchQuery = '';
  String _productFilter = 'all';

  // Orders
  List<Orders> _orders = [];
  List<Order> _order = [];
  List<Orders> _filteredOrders = [];
  String _orderSearchQuery = '';
  String _orderFilter = 'all';
  bool _isLoadingOrders = false;

  // Product Management
  bool _isAddingProduct = false;
  final _productFormKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productQuantityController = TextEditingController();
  final TextEditingController _productDiscountController = TextEditingController();
  final TextEditingController _productTaxController = TextEditingController();
  bool _productHasVAT = false;
  String _selectedProductCategory = 'Savory';
  String _selectedProductUnit = 'kg';
  String? _selectedProductImageUrl;
  String? _selectedPredefinedItem;
  bool _isEditProductMode = false;
  String? _editingProductId;
  
  // Image selection state
  bool _showImageSelector = false;

  // UI State
  bool _isLoading = true;
  int _tabIndex = 0;
  bool _isSidebarExpanded = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _sellerSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _orderSearchController = TextEditingController();

  // --- INIT ---
  @override
  void initState() {
    super.initState();
    _loadAllData();
    // Poll orders periodically to simulate real-time updates
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return false;
      await _fetchOrders();
      return true; // keep polling while widget is mounted
    });
    _userSearchController.addListener(() {
      setState(() {
        _userSearchQuery = _userSearchController.text;
        _fetchUsers();
      });
    });
    

    _productSearchController.addListener(() {
      setState(() {
        _productSearchQuery = _productSearchController.text;
        _filterProducts();
      });
    });

    _orderSearchController.addListener(() {
      setState(() {
        _orderSearchQuery = _orderSearchController.text;
        _filterOrders();
      });
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    _productDiscountController.dispose();
    _productTaxController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // --- FIXED API CALLS ---

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
   await Future.wait([
      _fetchStats(),
  _fetchProducts(),
  _fetchUsers(),
  _fetchOrders(),
]);
    setState(() => _isLoading = false);
  }

  // FIXED: Calculate stats from actual data instead of separate API call
  void _calculateStats() {
    setState(() {
      _totalProducts = _products.length;
      _availableProducts = _products.where((p) => p.isAvailable).length;
      _hiddenProducts = _products.where((p) => !p.isAvailable).length;
      _totalUsers = _users.length;
   
    });
  }

  
    
  Future<void> _fetchUsers() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      String url = '$_baseUrl/admin/users?limit=100';
      if (_userSearchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_userSearchQuery)}';
      }
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (res.statusCode == 200) {
          print('Order fetch response: ${res.body}'); 
        final data = jsonDecode(res.body);
        setState(() {
          _users = (data['users'] as List)
              .map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _calculateStats();
      }
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  // --- PASTE HERE ---
Future<void> _fetchStats() async {
  final token = await _getToken();
  if (token == null) return;
  try {
    final res = await http.get(
      Uri.parse('$_baseUrl/admin/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('Stats API status: ${res.statusCode}');
    print('Stats API response: ${res.body}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _totalUsers = data['stats']?['totalUsers'] ?? _totalUsers;
        _totalProducts = data['stats']?['totalProducts'] ?? _totalProducts;
        _totalOrders = data['stats']?['totalOrders'] ?? _totalOrders;
        // If stats API doesn't return product counts, calculate from products list
        if (_totalProducts == 0 && _products.isNotEmpty) {
          _totalProducts = _products.length;
          _availableProducts = _products.where((p) => p.isAvailable).length;
          _hiddenProducts = _products.where((p) => !p.isAvailable).length;
        }
      });
    }
  } catch (e) {
    print('Failed to fetch stats: $e');
    // If stats API fails, calculate from products list
    if (_products.isNotEmpty) {
      setState(() {
        _totalProducts = _products.length;
        _availableProducts = _products.where((p) => p.isAvailable).length;
        _hiddenProducts = _products.where((p) => !p.isAvailable).length;
      });
    }
  }
}
     
  // FIXED: Use correct API endpoint and better error handling
  Future<void> _fetchProducts() async {
    final token = await _getToken();
    if (token == null) {
      print('No auth token found');
      return;
    }

    try {
      print('Fetching products from admin API...');

      // Use the admin-specific endpoint
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/items?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Admin Products API Response Status: ${res.statusCode}');
      print('Admin Products API Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Handle different possible response structures
        List<dynamic> itemsList = [];
        if (data is Map<String, dynamic>) {
          itemsList = data['items'] ?? data['products'] ?? data['data'] ?? [];
        } else if (data is List) {
          itemsList = data;
        }

        print('Found ${itemsList.length} products');

        setState(() {
          _products = itemsList
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();

          print('Parsed ${_products.length} products successfully');

          // Calculate stats immediately after fetching
          _totalProducts = _products.length;
          _availableProducts = _products.where((p) => p.isAvailable).length;
          _hiddenProducts = _products.where((p) => !p.isAvailable).length;

          print(
              'Stats - Total: $_totalProducts, Available: $_availableProducts, Hidden: $_hiddenProducts');

          _filterProducts();
        });
      } else if (res.statusCode == 401) {
        print('Unauthorized - token may be invalid');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('Failed to fetch products: ${res.statusCode} - ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${res.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _products.where((product) {
        bool matchesSearch = _productSearchQuery.isEmpty ||
            product.name
                .toLowerCase()
                .contains(_productSearchQuery.toLowerCase()) ||
            product.category
                .toLowerCase()
                .contains(_productSearchQuery.toLowerCase()) ||
            (product.sellerName
                    ?.toLowerCase()
                    .contains(_productSearchQuery.toLowerCase()) ??
                false);

        bool matchesFilter = _productFilter == 'all' ||
            (_productFilter == 'available' && product.isAvailable) ||
            (_productFilter == 'hidden' && !product.isAvailable);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  // --- ORDER METHODS ---

 Future<void> _fetchOrders() async {
  setState(() => _isLoadingOrders = true);
  final token = await _getToken();
  if (token == null) return;
  try {
    final res = await http.get(
      Uri.parse('$_baseUrl/orders?limit=100'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _orders = (data['orders'] as List)
            .map((e) => Orders.fromJson(e as Map<String, dynamic>))
            .toList();
        _filterOrders();
      });
    }
  } catch (e) {
    print('Failed to fetch orders: $e');
  } finally {
    setState(() => _isLoadingOrders = false);
  }
}
  // Dummy data for testing

  void _filterOrders() {
    setState(() {
      _filteredOrders = _orders.where((order) {
        bool matchesSearch = _orderSearchQuery.isEmpty ||
            order.userName
                .toLowerCase()
                .contains(_orderSearchQuery.toLowerCase()) ||
            order.userEmail
                .toLowerCase()
                .contains(_orderSearchQuery.toLowerCase()) ||
            order.id.toLowerCase().contains(_orderSearchQuery.toLowerCase());

        bool matchesFilter = _orderFilter == 'all' ||
            (_orderFilter == 'pending' && order.status == 'pending') ||
            (_orderFilter == 'completed' && order.status == 'completed') ||
            (_orderFilter == 'cancelled' && order.status == 'cancelled');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

 Future<void> _downloadInvoice(String orderId) async {
  final token = await _getToken();
  if (token == null) return;
  try {
    // 1. Generate invoice if required
    final genRes = await http.post(
      Uri.parse('$_baseUrl/admin/orders/$orderId/invoice'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (genRes.statusCode != 200) throw Exception('Failed to generate invoice');
    // 2. Download invoice
    final url = '$_baseUrl/admin/orders/$orderId/invoice/download';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw Exception('Could not launch invoice URL');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to download invoice: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _viewUserDetails(String userId) async {
    try {
      // Try to fetch from API first
      final userDetails = await AdminService.getUserDetails(userId);
      final userOrders = await AdminService.getUserOrderHistory(userId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _UserDetailsDialog(
            userDetails: userDetails,
            orders: userOrders,
          ),
        );
      }
    } catch (e) {
      // If API fails, use dummy data for testing
      print('API failed');
    }
  }

  // Dummy user details for testing

  Future<void> _approveSellerRequest(String requestId) async {
    final token = await _getToken();
    if (token == null) return;
    final res = await http.post(
      Uri.parse('$_baseUrl/admin/seller-requests/$requestId/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      await _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller request approved')),
      );
    }
  }

  Future<void> _rejectSellerRequest(String requestId, String reason) async {
    final token = await _getToken();
    if (token == null) return;
    final res = await http.post(
      Uri.parse('$_baseUrl/admin/seller-requests/$requestId/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode == 200) {
      await _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller request rejected')),
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/users/$userId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isActive': isActive}),
      );
      if (res.statusCode == 200) {
        await _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'User ${isActive ? 'activated' : 'deactivated'} successfully')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update user status')),
      );
    }
  }

 
  // Toggle product availability
  Future<void> _toggleProductAvailability(Product product) async {
    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/items/${product.id}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isAvailable': !product.isAvailable}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product ${!product.isAvailable ? 'activated' : 'hidden'} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchProducts(); // Refresh products list
      } else {
        throw Exception(data['message'] ?? 'Failed to update product status');
      }
    } catch (e) {
      print('Error toggling product availability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- PRODUCT MANAGEMENT METHODS ---

  Future<void> _addProduct() async {
    if (!_productFormKey.currentState!.validate()) return;

    setState(() => _isAddingProduct = true);

    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      String? imageUrl = _selectedProductImageUrl;

      if (_selectedPredefinedItem != null) {
        // Get image URL from predefined items
        imageUrl = _getPredefinedItemImageUrl(_selectedPredefinedItem!) ?? _selectedProductImageUrl;
      }

      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'imageUrl': imageUrl,
        'quantity': int.parse(_productQuantityController.text),
        'unit': _selectedProductUnit,
        'isAvailable': true,
        'discount': int.tryParse(_productDiscountController.text) ?? 0,
        'tax': int.tryParse(_productTaxController.text) ?? 0,
        'hasVAT': _productHasVAT,
      };

      // Use admin-specific endpoint
      final res = await http.post(
        Uri.parse('$_baseUrl/admin/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );
        print('Request body: $productData');
       print('Add product status: ${res.statusCode}');
       print('Add product response: ${res.body}');
      final data = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) &&
          data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearProductForm();
        await _fetchProducts(); // Refresh products list
        setState(() => _tabIndex = 2); // Switch to products tab
      } else {
        throw Exception(data['message'] ??
            'Failed to add product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error adding product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isAddingProduct = false);
    }
  }

  Future<void> _updateProduct() async {
    if (!_productFormKey.currentState!.validate() || _editingProductId == null)
      return;

    setState(() => _isAddingProduct = true);

    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      String? imageUrl = _selectedProductImageUrl;

      if (_selectedPredefinedItem != null) {
        imageUrl = _getPredefinedItemImageUrl(_selectedPredefinedItem!) ?? _selectedProductImageUrl;
      }

      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'imageUrl': imageUrl,
        'quantity': int.parse(_productQuantityController.text),
        'unit': _selectedProductUnit,
        'discount': int.tryParse(_productDiscountController.text) ?? 0,
        'tax': int.tryParse(_productTaxController.text) ?? 0,
        'hasVAT': _productHasVAT,
      };

      // Use admin-specific endpoint
      final res = await http.put(
        Uri.parse('$_baseUrl/admin/items/$_editingProductId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearProductForm();
        await _fetchProducts(); // Refresh products list
        setState(() => _tabIndex = 2); // Switch to products tab
      } else {
        throw Exception(data['message'] ??
            'Failed to update product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isAddingProduct = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found')),
        );
        return;
      }

      // Use admin-specific endpoint
      final res = await http.delete(
        Uri.parse('$_baseUrl/admin/items/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Product deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchProducts(); // Refresh products list
      } else {
        throw Exception(data['message'] ??
            'Failed to delete product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editProduct(Product product) {
    _productNameController.text = product.name;
    _productDescriptionController.clear();
    _productDescriptionController.text = product.description;
    _productPriceController.text = product.price.toString();
    _productQuantityController.text = '1'; // Default quantity
    _selectedProductCategory = product.category;
    _selectedProductUnit = 'kg'; // Default unit
    _selectedProductImageUrl = product.imageUrl;
    _selectedPredefinedItem = null;
    _showImageSelector = false;
    _productDiscountController.text = product.discount.toString();
    _productTaxController.text = product.tax.toString();
    _productHasVAT = product.hasVAT;

    setState(() {
      _isEditProductMode = true;
      _editingProductId = product.id;
      _tabIndex = 4; // Switch to add product tab
    });
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    _productQuantityController.clear();
    _selectedProductCategory = 'savory';
    _selectedProductUnit = 'kg';
    _selectedProductImageUrl = null;
    _selectedPredefinedItem = null;
    _isEditProductMode = false;
    _editingProductId = null;
    _showImageSelector = false;
    _productDiscountController.clear();
    _productTaxController.clear();
    _productHasVAT = false;
  }

  String? _getPredefinedItemImageUrl(String itemName) {
    // Use the GroceryItems class from the items module
    return GroceryItems.getImageUrl(itemName);
  }

  void _showDeleteProductConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23293A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Product',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${product.name}"?',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProduct(product.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILD (keeping the same UI code) ---

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF151A24),
        cardColor: const Color(0xFF23293A),
        dividerColor: Colors.grey[700],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.greenAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23293A),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        key: _scaffoldKey,
        body: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebarWidth = constraints.maxWidth < 768
                  ? 60.0
                  : (_isSidebarExpanded ? 250.0 : 70.0);

              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: sidebarWidth,
                    child: _buildSidebar(constraints.maxWidth < 768),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : IndexedStack(
                                  index: _tabIndex,
                                  children: [
                                    _buildOverviewTab(),
                                    _buildUsersTab(),
                                    _buildProductsTab(),
                                    _buildOrdersTab(),
                                    _buildAddProductTab(),
                                    
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF23293A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF151A24), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarExpanded ? Icons.menu_open : Icons.menu,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSidebarExpanded = !_isSidebarExpanded;
              });
            },
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Admin Dashboard",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Add refresh button for debugging
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadAllData();
            },
            tooltip: "Refresh Data",
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, "/home");
            },
            tooltip: "Go to Home",
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isSmallScreen) {
    final bool showExpanded = !isSmallScreen && _isSidebarExpanded;

    return Container(
      color: const Color(0xFF23293A),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showExpanded) ...[
            const Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blueAccent, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "GroceryAdmin",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ] else ...[
            const Center(
              child:
                  Icon(Icons.shopping_cart, color: Colors.blueAccent, size: 28),
            ),
            const SizedBox(height: 40),
          ],
          _sidebarNavItem(Icons.dashboard, "Dashboard", 0, showExpanded),
          _sidebarNavItem(Icons.people, "Users", 1, showExpanded),
          _sidebarNavItem(Icons.inventory, "Products", 2, showExpanded),
          _sidebarNavItem(Icons.receipt, "Orders", 3, showExpanded),
          _sidebarNavItem(
              Icons.add_shopping_cart, "Add Products", 4, showExpanded),
        ],
      ),
    );
  }

  Widget _sidebarNavItem(IconData icon, String text, int index, bool showText) {
    final bool selected = _tabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _tabIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.blueAccent : Colors.grey[400],
            ),
            if (showText) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: selected ? Colors.blueAccent : Colors.grey[300],
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TABS (keeping the same UI code for brevity) ---

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              // Debug info
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Text(
                  'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1200) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                                            const SizedBox(width: 20),
                        Expanded(
                            child: _statCard("Total Products",
                                _totalProducts.toString(), Icons.inventory)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                "Available Products",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Hidden Products",
                                _hiddenProducts.toString(),
                                Icons.visibility_off,
                                Colors.orange)),
                        const SizedBox(width: 20),
                        Expanded(child: Container()),
                      ],
                    ),
                  ],
                );
              } else if (constraints.maxWidth > 900) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                                       ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("Total Products",
                                _totalProducts.toString(), Icons.inventory)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Available Products",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _statCard("Hidden Products", _hiddenProducts.toString(),
                        Icons.visibility_off, Colors.orange),
                  ],
                );
              } else if (constraints.maxWidth > 600) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _statCard("No. of Users",
                                _totalUsers.toString(), Icons.people)),
                                          ],
                    ),
                    const SizedBox(height: 20),
                    _statCard("Total Products", _totalProducts.toString(),
                        Icons.inventory),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _statCard(
                                "Available",
                                _availableProducts.toString(),
                                Icons.visibility,
                                Colors.green)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: _statCard(
                                "Hidden",
                                _hiddenProducts.toString(),
                                Icons.visibility_off,
                                Colors.orange)),
                      ],
                    ),
                  ],
                );
              } else
                return Column(
                  children: [
                    _statCard(
                        "No. of Users", _totalUsers.toString(), Icons.people),
                    const SizedBox(height: 20),    
                   
                    _statCard("Total Products", _totalProducts.toString(),
                        Icons.inventory),
                    const SizedBox(height: 20),
                    _statCard(
                        "Available Products",
                        _availableProducts.toString(),
                        Icons.visibility,
                        Colors.green),
                    const SizedBox(height: 20),
                    _statCard("Hidden Products", _hiddenProducts.toString(),
                        Icons.visibility_off, Colors.orange),
                  ],
                );
              }
            
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      [Color? iconColor]) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: const Color(0xFF23293A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: iconColor ?? Colors.blueAccent),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- ADD PRODUCT TAB ---
Widget _buildAddProductTab() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isEditProductMode ? "Edit Product" : "Add New Product",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              if (_isEditProductMode)
                TextButton.icon(
                  onPressed: _clearProductForm,
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  label: const Text(
                    "Clear Form",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _productFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  const Text(
                    "Product Name *",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF151A24),
                      hintText: 'Enter product name',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Product name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Product Description
                  const Text(
                    "Description *",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productDescriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF151A24),
                      hintText: 'Enter product description',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Product description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Price and Quantity Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Price *",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _productPriceController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF151A24),
                                hintText: '0.00',
                                hintStyle: const TextStyle(color: Colors.grey),
                                prefixText: '\₹',
                                prefixStyle: const TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Price is required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid price';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Price must be greater than 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quantity *",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _productQuantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF151A24),
                                hintText: '1',
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Quantity is required';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Please enter a valid quantity';
                                }
                                if (int.parse(value) <= 0) {
                                  return 'Quantity must be greater than 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Category and Unit Row
                  Row(
  children: [
    Flexible(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Category *",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF151A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedProductCategory,
              dropdownColor: const Color(0xFF23293A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
              ),
              items: [
                'Savory',
                'Namkeen',
                'Sweets',
                'Travel Pack Combo',
                'Value Pack Offers',
                'Gift Packs',
              ].map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProductCategory = newValue!;
                });
              },
            ),
          ),
        ],
      ),
    ),
    const SizedBox(width: 12), // Reduced from 20 to 12
    Flexible(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Unit *",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF151A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedProductUnit,
              dropdownColor: const Color(0xFF23293A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              items: [
                'kg',
                'g',
                'lb',
                'oz',
                'piece',
                'pack',
                'bottle',
                'box',
                'bag',
                'unit'
              ].map((String unit) {
                return DropdownMenuItem<String>(
                  value: unit,
                  child: Text(unit),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProductUnit = newValue!;
                });
              },
            ),
          ),
        ],
      ),
    ),
  ],
    ),
                  const SizedBox(height: 20),

                  // ------ Discount, Tax, VAT ------
                  const Text(
                    "Discount (%)",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productDiscountController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF151A24),
                      hintText: '0',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final val = int.tryParse(value);
                        if (val == null || val < 0 || val > 100) {
                          return 'Enter 0-100';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Tax (%)",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productTaxController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF151A24),
                      hintText: '0',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final val = int.tryParse(value);
                        if (val == null || val < 0 || val > 100) {
                          return 'Enter 0-100';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Checkbox(
                        value: _productHasVAT,
                        onChanged: (val) {
                          setState(() {
                            _productHasVAT = val ?? false;
                          });
                        },
                        checkColor: Colors.white,
                        activeColor: Colors.blueAccent,
                      ),
                      const Text(
                        "Apply VAT (18%)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ------ End Discount, Tax, VAT ------

                  // Predefined Items
                  const Text(
                    "Choose Product Image *",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select an image from our predefined collection. This is required to add a product.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Image Preview
                  if (_selectedProductImageUrl != null)
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _selectedProductImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Image Selector Button
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showImageSelector = !_showImageSelector;
                      });
                    },
                    icon: Icon(_showImageSelector
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down),
                    label: Text(_showImageSelector
                        ? 'Hide Image Selector'
                        : 'Show Image Selector'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Image Selector Grid
                  if (_showImageSelector) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Select an image:",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedPredefinedItem = null;
                                    _selectedProductImageUrl = null;
                                    _productNameController.clear();
                                  });
                                },
                                child: const Text(
                                  "Clear Selection",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Category Filter
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _categoryFilterChip('Savory', 'Savory'),
                                _categoryFilterChip('Namkeen', 'Namkeen'),
                                _categoryFilterChip('Sweets', 'Sweets'),
                                _categoryFilterChip(
                                    'Travel Pack Combo', 'Travel Pack Combo'),
                                _categoryFilterChip(
                                    'Value Pack Offers', 'Value Pack Offers'),
                                _categoryFilterChip(
                                    'Gift Packs', 'Gift Packs'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Image Grid
                          SizedBox(
                            height: 300,
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _getFilteredItems().length,
                              itemBuilder: (context, index) {
                                final itemName = _getFilteredItems()[index];
                                final imageUrl =
                                    GroceryItems.getImageUrl(itemName);
                                final isSelected =
                                    _selectedPredefinedItem == itemName;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedPredefinedItem = itemName;
                                      _selectedProductImageUrl = imageUrl;
                                      _productNameController.text = itemName;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blueAccent
                                            : Colors.grey.withOpacity(0.3),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      color: isSelected
                                          ? Colors.blueAccent.withOpacity(0.1)
                                          : Colors.transparent,
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(6)),
                                            child: imageUrl != null
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        color: Colors.grey[800],
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                          size: 24,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Container(
                                                    color: Colors.grey[800],
                                                    child: const Icon(
                                                      Icons
                                                          .image_not_supported,
                                                      color: Colors.grey,
                                                      size: 24,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          child: Text(
                                            itemName,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.white,
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAddingProduct
                          ? null
                          : (_selectedProductImageUrl == null
                              ? null
                              : (_isEditProductMode
                                  ? _updateProduct
                                  : _addProduct)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedProductImageUrl == null
                            ? Colors.grey
                            : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAddingProduct
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Processing...'),
                              ],
                            )
                          : _selectedProductImageUrl == null
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported, size: 20),
                                    SizedBox(width: 8),
                                    Text('Please select an image first'),
                                  ],
                                )
                              : Text(_isEditProductMode
                                  ? 'Update Product'
                                  : 'Add Product'),
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

  // Keep all other UI methods the same...
 

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Users",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 20),
          _userSearchBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _users.isEmpty
                ? const Center(
                    child: Text(
                      "No users found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _userCard(_users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _userSearchBar() {
    return TextField(
      controller: _userSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search users...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _userCard(User user) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: user.isActive ? Colors.green : Colors.red,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.phone,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Role: ${user.role}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: user.isActive,
                    onChanged: (value) => _toggleUserStatus(user.id, value),
                    activeColor: Colors.green,
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            user.isActive ? Colors.green : Colors.red,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: user.isActive,
                        onChanged: (value) => _toggleUserStatus(user.id, value),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.phone,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Role: ${user.role}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Products",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
             
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _productSearchBar()),
              const SizedBox(width: 16),
              _productFilterDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _filterChip('All', 'all', _totalProducts),
              const SizedBox(width: 8),
              _filterChip(
                  'Available', 'available', _availableProducts, Colors.green),
              const SizedBox(width: 8),
              _filterChip('Hidden', 'hidden', _hiddenProducts, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _productFilter == 'all'
                              ? Icons.inventory_2_outlined
                              : _productFilter == 'available'
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _productFilter == 'all'
                              ? "No products found."
                              : _productFilter == 'available'
                                  ? "No available products found."
                                  : "No hidden products found.",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total products in database: $_totalProducts',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      return _productCard(_filteredProducts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, int count, [Color? color]) {
    final isSelected = _productFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _productFilter = value;
          _filterProducts();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.blueAccent).withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? (color ?? Colors.blueAccent) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? (color ?? Colors.blueAccent) : Colors.grey[300],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

Widget _productFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _productFilter,
        dropdownColor: const Color(0xFF23293A),
        underline: Container(),
        icon: const Icon(Icons.filter_list, color: Colors.grey, size: 15),
        items: [
          DropdownMenuItem(
              value: 'all',
              child: Text('All Products ($_totalProducts)',
                  style: const TextStyle(color: Colors.white))),
          DropdownMenuItem(
              value: 'available',
              child: Text('Available ($_availableProducts)',
                  style: const TextStyle(color: Colors.green))),
          DropdownMenuItem(
              value: 'hidden',
              child: Text('Hidden ($_hiddenProducts)',
                  style: const TextStyle(color: Colors.orange))),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _productFilter = value;
              _filterProducts();
            });
          }
        },
      ),
    );
  }

  Widget _productSearchBar() {
    return TextField(
      controller: _productSearchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF151A24),
        hintText: 'Search product',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _productCard(Product product) {
  return Card(
    color: const Color(0xFF23293A),
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.isAvailable
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[800],
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.inventory,
                                      color: Colors.grey[400],
                                      size: 40,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.inventory,
                                color: Colors.grey[400],
                                size: 40,
                              ),
                      ),
                      if (!product.isAvailable)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withOpacity(0.7),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.visibility_off,
                                color: Colors.orange,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: TextStyle(
                                  color: product.isAvailable
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: product.isAvailable
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: product.isAvailable
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product.isAvailable
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 12,
                                    color: product.isAvailable
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.isAvailable
                                        ? 'VISIBLE'
                                        : 'HIDDEN',
                                    style: TextStyle(
                                      color: product.isAvailable
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: TextStyle(
                            color: product.isAvailable
                                ? Colors.grey
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '\₹${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.green
                                    : Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category,
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // --- Added: Tax, Discount, VAT badges ---
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (product.discount > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Discount: ${product.discount}%',
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                            if (product.tax > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Tax: ${product.tax}%',
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              ),
                            if (product.hasVAT)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VAT Applied',
                                  style: TextStyle(color: Colors.purple, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        product.isAvailable
                            ? 'Customers can see this'
                            : 'Hidden from customers',
                        style: TextStyle(
                          color: product.isAvailable
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Switch(
                        value: product.isAvailable,
                        onChanged: (value) =>
                            _toggleProductAvailability(product),
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.orange,
                        inactiveTrackColor: Colors.orange.withOpacity(0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.isAvailable ? 'VISIBLE' : 'HIDDEN',
                        style: TextStyle(
                          color: product.isAvailable
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editProduct(product),
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit Product',
                          ),
                          IconButton(
                            onPressed: () =>
                                _showDeleteProductConfirmation(product),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Product',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[800],
                            ),
                            child: product.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      product.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.inventory,
                                          color: Colors.grey[400],
                                          size: 30,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.inventory,
                                    color: Colors.grey[400],
                                    size: 30,
                                  ),
                          ),
                          if (!product.isAvailable)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withOpacity(0.7),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.visibility_off,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: product.isAvailable
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\₹${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: product.isAvailable
                                    ? Colors.green
                                    : Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            // --- Added: Tax, Discount, VAT badges (mobile) ---
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (product.discount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Discount: ${product.discount}%',
                                      style: const TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                                if (product.tax > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Tax: ${product.tax}%',
                                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                                    ),
                                  ),
                                if (product.hasVAT)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'VAT Applied',
                                      style: TextStyle(color: Colors.purple, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.isAvailable
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  product.isAvailable
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 10,
                                  color: product.isAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  product.isAvailable ? 'VISIBLE' : 'HIDDEN',
                                  style: TextStyle(
                                    color: product.isAvailable
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: product.isAvailable,
                            onChanged: (value) =>
                                _toggleProductAvailability(product),
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.orange,
                            inactiveTrackColor:
                                Colors.orange.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: product.isAvailable
                          ? Colors.grey
                          : Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (product.sellerName != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Seller: ${product.sellerName}',
                            style: TextStyle(
                              color: product.isAvailable
                                  ? Colors.grey
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: product.isAvailable
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: product.isAvailable
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          product.isAvailable
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 16,
                          color: product.isAvailable
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.isAvailable
                                ? 'This product is visible to customers and can be purchased'
                                : 'This product is hidden from customers and cannot be purchased',
                            style: TextStyle(
                              color: product.isAvailable
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    ),
    );
  }

  // --- ORDERS TAB ---
  Widget _buildOrdersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Orders & Invoices",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No orders found.",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total orders: ${_orders.length}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          return _orderCard(_orders[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Orders order) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: ${order.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Customer Name: ${order.userName}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        'Customer Email: ${order.userEmail}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\₹${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${order.items.length} items • ${order.items.fold(0, (sum, item) => sum + item.quantity)} total quantity',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(order.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            // Buttons removed as requested
          ],
        ),
      ),
    );
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Refresh the image URL field
  void _refreshImageUrlField() {
    setState(() {});
  }
  
  // Get filtered items based on selected category
  List<String> _getFilteredItems() {
    if (_selectedProductCategory == 'Savory') {
      return GroceryItems.getItemsByCategory('savory');
    } else if (_selectedProductCategory == 'Namkeen') {
      return GroceryItems.getItemsByCategory('namkeen');
    } else if (_selectedProductCategory == 'Sweets') {
      return GroceryItems.getItemsByCategory('sweets');
    } else if (_selectedProductCategory == 'Travel Pack Combo') {
      return GroceryItems.getItemsByCategory('travel pack combo');
    } else if (_selectedProductCategory == 'Value Pack Offers') {
      return GroceryItems.getItemsByCategory('value pack offers');
    } else if (_selectedProductCategory == 'Gift Packs') {
      return GroceryItems.getItemsByCategory('gift packs');
    } else {
      return GroceryItems.getAllItems();
    }
  }
  
  // Category filter chip widget
  Widget _categoryFilterChip(String label, String? category) {
    final isSelected = _selectedProductCategory == (category ?? 'all');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (category != null) {
              _selectedProductCategory = category;
            }
            _showImageSelector = true;
          });
        },
        selectedColor: Colors.blueAccent.withOpacity(0.3),
        checkmarkColor: Colors.blueAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey.withOpacity(0.1),
      ),
    );
  }
}

// User Details Dialog Widget
class _UserDetailsDialog extends StatelessWidget {
  final UserDetails userDetails;
  final List<Order> orders;

  const _UserDetailsDialog({
    required this.userDetails,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF23293A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      userDetails.isActive ? Colors.green : Colors.red,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDetails.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        userDetails.email,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        userDetails.phone,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User Stats
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Orders',
                    userDetails.totalOrders.toString(),
                    Icons.shopping_bag,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statCard(
                    'Total Spent',
                    '\₹${userDetails.totalSpent.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Order History',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders found for this user.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          color: const Color(0xFF151A24),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order #${order.id.substring(0, 8)}...',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${order.items.length} items',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\₹${order.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(order.status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        order.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(order.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
