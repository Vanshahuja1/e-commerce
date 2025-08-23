import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Backend API configuration
  static const String baseUrl = 'https://backend-ecommerce-app-co1r.onrender.com';
  static const String addressEndpoint = '/api/addresses';
  static const String orderEndpoint = '/api/orders';
  
  // Razorpay instance
  late Razorpay _razorpay;
  
  // State variables
  List<Address> savedAddresses = [];
  int selectedAddressIndex = -1;
  String selectedPaymentMethod = 'cod';
  bool isAddingNewAddress = false;
  bool isLoading = true;
  bool isSavingAddress = false;
  bool isProcessingPayment = false;
  String? _token; // This will hold the authentication token
  
  // Cart data from arguments
  double totalAmount = 0.0;
  List<dynamic> cartItems = [];
  double deliveryFee = 0.0;
  double taxRate = 0.0; // 5% tax

  // Controllers for new address form
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get arguments first, then initialize everything else
    _getCartArguments();
    // Only fetch addresses if token hasn't been fetched yet
    if (_token == null) {
      _initializeAndFetchAddresses();
    }
  }

  // Get cart arguments passed from previous screen
  void _getCartArguments() {
    print('Getting cart arguments...');
    
    final arguments = ModalRoute.of(context)?.settings.arguments;
    print('Raw arguments: $arguments');
    print('Arguments type: ${arguments.runtimeType}');
    
    if (arguments != null && arguments is Map<String, dynamic>) {
      print('Arguments keys: ${arguments.keys}');
      
      // Handle amount
      final amountValue = arguments['amount'];
      print('Amount value: $amountValue, type: ${amountValue.runtimeType}');
      
      double parsedAmount = 0.0;
      if (amountValue is double) {
        parsedAmount = amountValue;
      } else if (amountValue is int) {
        parsedAmount = amountValue.toDouble();
      } else if (amountValue is String) {
        parsedAmount = double.tryParse(amountValue) ?? 0.0;
      } else if (amountValue is num) {
        parsedAmount = amountValue.toDouble();
      }
      
      // Handle cart items
      final itemsValue = arguments['cartItems'];
      print('CartItems value: $itemsValue, type: ${itemsValue.runtimeType}');
      
      List<dynamic> parsedItems = [];
      if (itemsValue is List) {
        parsedItems = itemsValue;
      } else if (itemsValue != null) {
        // If it's not a list but not null, try to wrap it
        parsedItems = [itemsValue];
      }
      
      setState(() {
        totalAmount = parsedAmount;
        cartItems = parsedItems;
      });
      
      print('Final totalAmount: $totalAmount');
      print('Final cartItems length: ${cartItems.length}');
      print('CartItems content: $cartItems');
    } else {
      print('No arguments found or invalid format');
      print('Arguments is null: ${arguments == null}');
      print('Arguments type: ${arguments.runtimeType}');
      
      setState(() {
        totalAmount = 0.0;
        cartItems = [];
      });
    }
  }

  // Initialize Razorpay
  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Initialize token and fetch addresses
  Future<void> _initializeAndFetchAddresses() async {
    await _getAuthToken();
    await _fetchAddresses();
  }

  // Get authentication token from SharedPreferences
  Future<void> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _token = prefs.getString('auth_token');
      });
      print('Auth Token fetched: $_token'); // Add this line
      
      if (_token == null || _token!.isEmpty) {
        _showErrorSnackBar('Authentication token not found. Please login again.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get authentication token: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    titleController.dispose();
    pincodeController.dispose();
    cityController.dispose();
    stateController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  // Calculate totals
  double get subtotal => totalAmount;
  double get taxAmount => subtotal * taxRate;
  double get finalTotal => subtotal + deliveryFee + taxAmount;

  // Debug method
  void _debugPrintValues() {
    print('=== PAYMENT DEBUG INFO ===');
    print('totalAmount: $totalAmount');
    print('subtotal: $subtotal');
    print('deliveryFee: $deliveryFee');
    print('taxAmount: $taxAmount');
    print('finalTotal: $finalTotal');
    print('cartItems count: ${cartItems.length}');
    print('cartItems: $cartItems');
    print('========================');
  }

  // Fetch addresses from backend
  Future<void> _fetchAddresses() async {
    try {
      setState(() {
        isLoading = true;
      });

      if (_token == null || _token!.isEmpty) {
        throw Exception('Authentication token not available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl$addressEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> addressList = data['addresses'] ?? [];
        
        setState(() {
          savedAddresses = addressList
              .map((json) => Address.fromJson(json))
              .take(3)
              .toList();
          isLoading = false;
          
          if (savedAddresses.isNotEmpty) {
            selectedAddressIndex = 0;
          }
        });
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception('Failed to fetch addresses: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load addresses: ${e.toString()}');
    }
  }

  // Save new address to backend
  Future<void> _saveAddress() async {
    if (!_validateAddressForm()) return;

    try {
      setState(() {
        isSavingAddress = true;
      });

      if (_token == null || _token!.isEmpty) {
        throw Exception('Authentication token not available');
      }

      final addressData = {
        'title': titleController.text.trim(),
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl$addressEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(addressData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Address newAddress = Address.fromJson(responseData['address']);
        
        setState(() {
          if (savedAddresses.length < 3) {
            savedAddresses.add(newAddress);
            selectedAddressIndex = savedAddresses.length - 1;
          }
          isSavingAddress = false;
          isAddingNewAddress = false;
        });

        _clearAddressForm();
        _showSuccessSnackBar('Address saved successfully!');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception('Failed to save address: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSavingAddress = false;
      });
      _showErrorSnackBar('Failed to save address: ${e.toString()}');
    }
  }

  // Delete address from backend
  Future<void> _deleteAddress(String addressId, int index) async {
    try {
      if (_token == null || _token!.isEmpty) {
        throw Exception('Authentication token not available');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl$addressEndpoint/$addressId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          savedAddresses.removeAt(index);
          if (selectedAddressIndex == index) {
            selectedAddressIndex = savedAddresses.isNotEmpty ? 0 : -1;
          } else if (selectedAddressIndex > index) {
            selectedAddressIndex--;
          }
        });
        _showSuccessSnackBar('Address deleted successfully!');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception('Failed to delete address: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete address: ${e.toString()}');
    }
  }

  // Razorpay Payment Handlers
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() {
      isProcessingPayment = false;
    });
    _showSuccessSnackBar('Payment successful! Order ID: ${response.orderId}');
    _processSuccessfulOrder(response.paymentId, response.orderId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      isProcessingPayment = false;
    });
    _showErrorSnackBar('Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      isProcessingPayment = false;
    });
    _showSuccessSnackBar('External wallet selected: ${response.walletName}');
  }

  // Create Razorpay order and initiate payment
  Future<void> _initiateRazorpayPayment() async {
    try {
      setState(() {
        isProcessingPayment = true;
      });

      final orderData = await _createRazorpayOrder();
      
      if (orderData != null) {
        var options = {
          'key': 'rzp_live_vegmIuWT1fULsb', // <--- REPLACE THIS WITH YOUR ACTUAL PUBLIC RAZORPAY KEY ID (e.g., rzp_test_xxxxxxxxxxxxxx)
          'amount': (finalTotal * 100).toInt(),
          'name': 'Your App Name',
          'description': 'Order Payment',
          'order_id': orderData['id'],
          'prefill': {
            'contact': savedAddresses[selectedAddressIndex].phone,
            'email': 'customer@example.com' // You might want to fetch the actual user email
          },
          'theme': {
            'color': '#4CAF50'
          }
        };

        _razorpay.open(options);
      } else {
        setState(() {
          isProcessingPayment = false;
        });
        _showErrorSnackBar('Failed to create payment order');
      }
    } catch (e) {
      setState(() {
        isProcessingPayment = false;
      });
      _showErrorSnackBar('Payment initialization failed: ${e.toString()}');
    }
  }

  // Create Razorpay order on backend
  Future<Map<String, dynamic>?> _createRazorpayOrder() async {
    try {
      final requestBody = json.encode({
        'amount': (finalTotal * 100).toInt(),
        'currency': 'INR',
        'receipt': 'order_${DateTime.now().millisecondsSinceEpoch}',
      });
      print('Creating Razorpay order request body: $requestBody'); // Add this line

      final response = await http.post(
        Uri.parse('$baseUrl/api/create-razorpay-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: requestBody, // Use the variable
      );

      print('Razorpay order creation response status: ${response.statusCode}'); // Add this line
      print('Razorpay order creation response body: ${response.body}'); // Add this line

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Failed to create Razorpay order');
        return null;
      }
    } catch (e) {
      print('Error creating Razorpay order: $e');
      _showErrorSnackBar('Error creating Razorpay order: ${e.toString()}');
      return null;
    }
  }

  // Process successful order
  Future<void> _processSuccessfulOrder(String? paymentId, String? orderId) async {
    try {
      final orderData = {
        'items': cartItems,
        'address': savedAddresses[selectedAddressIndex].toJson(),
        'paymentMethod': selectedPaymentMethod,
        'paymentId': paymentId,
        'razorpayOrderId': orderId,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'taxAmount': taxAmount,
        'totalAmount': finalTotal,
      };
      print('Processing successful order request body: $orderData'); // Add this line

      final response = await http.post(
        Uri.parse('$baseUrl$orderEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(orderData),
      );

      print('Process successful order response status: ${response.statusCode}'); // Add this line
      print('Process successful order response body: ${response.body}'); // Add this line

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacementNamed(
          context,
          '/order-success',
          arguments: {
            'orderId': json.decode(response.body)['order_id'],
            'amount': finalTotal,
          },
        );
      } else {
        final errorData = json.decode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Failed to save order details');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing order: ${e.toString()}');
    }
  }

  bool _validateAddressForm() {
    if (titleController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        stateController.text.trim().isEmpty ||
        pincodeController.text.trim().isEmpty) {
      _showErrorSnackBar('Please fill all required fields');
      return false;
    }

    if (phoneController.text.trim().length < 10) {
      _showErrorSnackBar('Please enter a valid phone number');
      return false;
    }

    if (pincodeController.text.trim().length != 6) {
      _showErrorSnackBar('Please enter a valid 6-digit pincode');
      return false;
    }

    return true;
  }

  void _clearAddressForm() {
    titleController.clear();
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    cityController.clear();
    stateController.clear();
    pincodeController.clear();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _debugPrintValues();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[600],
        title: const Text(
          'Payment & Delivery',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            )
          : Column(
              children: [
                // Debug info (remove in production)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.yellow[100],
                  child: Text(
                    'DEBUG: Total: BHD${totalAmount.toStringAsFixed(2)}, Items: ${cartItems.length}',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cartItems.isNotEmpty) _buildCartSummary(),
                        const SizedBox(height: 24),
                        _buildDeliveryAddressSection(),
                        const SizedBox(height: 24),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 24),
                        _buildOrderSummary(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildBottomSection(),
              ],
            ),
    );
  }

  // Rest of the widget methods remain the same...
  // (Include all the other widget building methods from your original code)
  // I'll keep the rest as they are working fine

  Widget _buildCartSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Cart Items (${cartItems.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cartItems.isEmpty)
            const Text(
              'No items in cart',
              style: TextStyle(color: Colors.red),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cartItems.length > 3 ? 3 : cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.fastfood, color: Colors.green[600], size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name']?.toString() ?? 'Item',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Qty: ${item['quantity']?.toString() ?? '1'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'BHD${item['price']?.toString() ?? '0'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (cartItems.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${cartItems.length - 3} more items',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => _buildAddressSlot(index)),
          if (isAddingNewAddress) _buildNewAddressForm(),
        ],
      ),
    );
  }

  Widget _buildAddressSlot(int index) {
    bool hasAddress = index < savedAddresses.length;
    bool isSelected = hasAddress && selectedAddressIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.green[600]! : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? Colors.green[50] : Colors.white,
      ),
      child: hasAddress ? _buildSavedAddress(index) : _buildAddAddressCard(index),
    );
  }

  Widget _buildSavedAddress(int index) {
    Address address = savedAddresses[index];
    bool isSelected = selectedAddressIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedAddressIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Radio<int>(
              value: index,
              groupValue: selectedAddressIndex,
              onChanged: (value) {
                setState(() {
                  selectedAddressIndex = value!;
                });
              },
              activeColor: Colors.green[600],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          address.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteConfirmation(address.id, index);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                        child: Icon(Icons.more_vert, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.fullAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.phone,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAddressCard(int index) {
    return InkWell(
      onTap: () {
        if (savedAddresses.length < 3) {
          setState(() {
            isAddingNewAddress = true;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 32,
              color: Colors.green[600],
            ),
            const SizedBox(height: 8),
            Text(
              'Add New Address',
              style: TextStyle(
                color: Colors.green[600],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add delivery address',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewAddressForm() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add New Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    isAddingNewAddress = false;
                  });
                  _clearAddressForm();
                },
                icon: const Icon(Icons.close),
                color: Colors.grey[600],
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(titleController, 'Address Title (Home, Office, etc.)', Icons.label),
          const SizedBox(height: 12),
          _buildTextField(nameController, 'Full Name', Icons.person),
          const SizedBox(height: 12),
          _buildTextField(phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(addressController, 'Complete Address', Icons.home, maxLines: 2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(cityController, 'City', Icons.location_city),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(stateController, 'State', Icons.map),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(pincodeController, 'Pincode', Icons.pin_drop, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      isAddingNewAddress = false;
                    });
                    _clearAddressForm();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSavingAddress ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isSavingAddress
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Address',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[600]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentOption(
            'cod',
            'Cash on Delivery',
            Icons.money,
            'Pay when your order arrives',
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            'online',
            'Online Payment',
            Icons.credit_card,
            'Pay securely with Razorpay',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData icon, String subtitle) {
    bool isSelected = selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green[600]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.green[50] : Colors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: selectedPaymentMethod,
              onChanged: (val) {
                setState(() {
                  selectedPaymentMethod = val!;
                });
              },
              activeColor: Colors.green[600],
            ),
            Icon(icon, color: Colors.green[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (value == 'online')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Razorpay',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totalAmount == 0.0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cart amount is BHD 0.00. Please check your cart.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _buildSummaryRow('Subtotal', 'BHD${subtotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Delivery Fee', 'BHD${deliveryFee.toStringAsFixed(2)}'),
            _buildSummaryRow('Tax (${(taxRate * 100).toInt()}%)', 'BHD${taxAmount.toStringAsFixed(2)}'),
            const Divider(thickness: 1),
            _buildSummaryRow('Total Amount', 'BHD${finalTotal.toStringAsFixed(2)}', isTotal: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.grey[700],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    bool canProceed = selectedAddressIndex >= 0 && selectedAddressIndex < savedAddresses.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!canProceed)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please select a delivery address to continue',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'BHD${finalTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (canProceed && !isProcessingPayment && totalAmount > 0) ? _proceedToPayment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (canProceed && !isProcessingPayment && totalAmount > 0) ? Colors.green[600] : Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isProcessingPayment
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Place Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String addressId, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Address'),
          content: const Text('Are you sure you want to delete this address?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAddress(addressId, index);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _proceedToPayment() {
    if (selectedPaymentMethod == 'online') {
      _initiateRazorpayPayment();
    } else {
      _processCODOrder();
    }
  }

  void _processCODOrder() async {
    setState(() {
      isProcessingPayment = true;
    });

    try {
      final orderData = {
        'items': cartItems,
        'address': savedAddresses[selectedAddressIndex].toJson(),
        'paymentMethod': selectedPaymentMethod,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'taxAmount': taxAmount,
        'totalAmount': finalTotal,
      };

      final response = await http.post(
        Uri.parse('$baseUrl$orderEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(orderData),
      );

      setState(() {
        isProcessingPayment = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar('Order placed successfully!');
        
        Navigator.pushReplacementNamed(
          context,
          '/order-success',
          arguments: {
            'orderId': json.decode(response.body)['order_id'],
            'amount': finalTotal,
          },
        );
      } else {
        _showErrorSnackBar('Failed to place order');
      }
    } catch (e) {
      setState(() {
        isProcessingPayment = false;
      });
      _showErrorSnackBar('Error placing order: ${e.toString()}');
    }
  }
}

// Address model class remains the same
class Address {
  final String id;
  final String title;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  Address({
    required this.id,
    required this.title,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  String get fullAddress => '$address, $city, $state - $pincode';

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'isDefault': isDefault,
    };
  }
}
