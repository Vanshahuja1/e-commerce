import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

// ----------- MODELS -----------

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final int stock;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      stock: json['stock'] ?? 0,
      isActive: json['isActive'] ?? json['isAvailable'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    int? stock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ----------- MAIN DASHBOARD WIDGET -----------

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  static const String _baseUrl =
      "https://backend-ecommerce-app-co1r.onrender.com/api";

  // Dashboard stats
  int _totalUsers = 0;
  int _totalProducts = 0;
  int _activeProducts = 0;
  int _inactiveProducts = 0;

  // Users
  List<UserModel> _users = [];
  String _userSearchQuery = '';

  // Products
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _productSearchQuery = '';
  String _productFilter = 'all';

  // Product Management
  bool _isAddingProduct = false;
  final _productFormKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productStockController = TextEditingController();
  String _selectedProductCategory = 'Fruits';
  String? _productImageUrl;
  bool _isEditProductMode = false;
  String? _editingProductId;

  // UI State
  bool _isLoading = true;
  int _tabIndex = 0;
  bool _isSidebarExpanded = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productStockController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProducts(),
      _fetchUsers(),
    ]);
    setState(() => _isLoading = false);
  }

  void _calculateStats() {
    setState(() {
      _totalProducts = _products.length;
      _activeProducts = _products.where((p) => p.isActive).length;
      _inactiveProducts = _products.where((p) => !p.isActive).length;
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
        final data = jsonDecode(res.body);
        setState(() {
          _users = (data['users'] as List)
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        _calculateStats();
      }
    } catch (e) {}
  }

  Future<void> _fetchProducts() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/items?limit=1000'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic> itemsList = [];
        if (data is Map<String, dynamic>) {
          itemsList = data['items'] ?? data['products'] ?? data['data'] ?? [];
        } else if (data is List) {
          itemsList = data;
        }
        setState(() {
          _products = itemsList
              .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _calculateStats();
          _filterProducts();
        });
      }
    } catch (e) {}
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
                .contains(_productSearchQuery.toLowerCase());
        bool matchesFilter = _productFilter == 'all' ||
            (_productFilter == 'active' && product.isActive) ||
            (_productFilter == 'inactive' && !product.isActive);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

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
      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'images': _productImageUrl != null ? [_productImageUrl] : [],
        'stock': int.parse(_productStockController.text),
        'isActive': true,
      };
      final res = await http.post(
        Uri.parse('$_baseUrl/items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );
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
        await _fetchProducts();
        setState(() => _tabIndex = 2);
      } else {
        throw Exception(data['message'] ??
            'Failed to add product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
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
      final productData = {
        'name': _productNameController.text,
        'description': _productDescriptionController.text,
        'price': double.parse(_productPriceController.text),
        'category': _selectedProductCategory,
        'images': _productImageUrl != null ? [_productImageUrl] : [],
        'stock': int.parse(_productStockController.text),
      };
      final res = await http.put(
        Uri.parse('$_baseUrl/items/$_editingProductId'),
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
        await _fetchProducts();
        setState(() => _tabIndex = 2);
      } else {
        throw Exception(data['message'] ??
            'Failed to update product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
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
      final res = await http.delete(
        Uri.parse('$_baseUrl/items/$productId'),
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
        await _fetchProducts();
      } else {
        throw Exception(data['message'] ??
            'Failed to delete product: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editProduct(ProductModel product) {
    _productNameController.text = product.name;
    _productDescriptionController.text = product.description;
    _productPriceController.text = product.price.toString();
    _productStockController.text = product.stock.toString();
    _selectedProductCategory = product.category;
    _productImageUrl = product.images.isNotEmpty ? product.images[0] : null;
    setState(() {
      _isEditProductMode = true;
      _editingProductId = product.id;
      _tabIndex = 3;
    });
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    _productStockController.clear();
    _selectedProductCategory = 'Fruits';
    _productImageUrl = null;
    _isEditProductMode = false;
    _editingProductId = null;
  }

  void _showDeleteProductConfirmation(ProductModel product) {
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadAllData();
            },
            tooltip: "Refresh Data",
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
                    "AdminPanel",
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
          _sidebarNavItem(Icons.add_shopping_cart, "Add Products", 3, showExpanded),
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

  // --- TABS ---

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
                              "Active Products",
                              _activeProducts.toString(),
                              Icons.visibility,
                              Colors.green)),
                      const SizedBox(width: 20),
                      Expanded(
                          child: _statCard(
                              "Inactive Products",
                              _inactiveProducts.toString(),
                              Icons.visibility_off,
                              Colors.orange)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, [Color? iconColor]) {
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

  Widget _userCard(UserModel user) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue,
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
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.phone,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
                  fontSize: 28,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  _clearProductForm();
                  setState(() => _tabIndex = 3);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Showing ${_filteredProducts.length} of ${_totalProducts}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
                  'Active', 'active', _activeProducts, Colors.green),
              const SizedBox(width: 8),
              _filterChip('Inactive', 'inactive', _inactiveProducts, Colors.orange),
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
                              : _productFilter == 'active'
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _productFilter == 'all'
                              ? "No products found."
                              : _productFilter == 'active'
                                  ? "No active products found."
                                  : "No inactive products found.",
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
        icon: const Icon(Icons.filter_list, color: Colors.grey, size: 20),
        items: [
          DropdownMenuItem(
              value: 'all',
              child: Text('All Products ($_totalProducts)',
                  style: const TextStyle(color: Colors.white))),
          DropdownMenuItem(
              value: 'active',
              child: Text('Active ($_activeProducts)',
                  style: const TextStyle(color: Colors.green))),
          DropdownMenuItem(
              value: 'inactive',
              child: Text('Inactive ($_inactiveProducts)',
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
        hintText: 'Search products by name or category...',
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

  Widget _productCard(ProductModel product) {
    return Card(
      color: const Color(0xFF23293A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: product.isActive
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: product.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.images[0],
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: product.isActive
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: product.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: product.isActive
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
                          '\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: product.isActive
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stock: ${product.stock}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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
                    product.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: product.isActive ? Colors.green : Colors.orange,
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
                        onPressed: () => _showDeleteProductConfirmation(product),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Product',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixText: '\$ ',
                                  prefixStyle:
                                      const TextStyle(color: Colors.grey),
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
                                "Stock *",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _productStockController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF151A24),
                                  hintText: '0',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
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
                                    return 'Stock is required';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Please enter a valid stock';
                                  }
                                  if (int.parse(value) < 0) {
                                    return 'Stock cannot be negative';
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: [
                          'Fruits',
                          'Vegetables',
                          'Dairy',
                          'Bakery',
                          'Meat',
                          'Grains',
                          'Beverages',
                          'Snacks',
                          'Household',
                          'Other'
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
                    const SizedBox(height: 20),
                    const Text(
                      "Image URL (Optional)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      initialValue: _productImageUrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF151A24),
                        hintText: 'Enter image URL',
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
                      onChanged: (value) {
                        setState(() {
                          _productImageUrl = value.isEmpty ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAddingProduct
                            ? null
                            : (_isEditProductMode
                                ? _updateProduct
                                : _addProduct),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...'),
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
}