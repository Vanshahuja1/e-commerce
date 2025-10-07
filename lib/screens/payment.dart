import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Backend API configuration
  static const String baseUrl = 'https://e-com-backend-x67v.onrender.com';
  static const String addressEndpoint = '/api/addresses';
  static const String orderEndpoint = '/api/orders';
  
  // Razorpay instance
  late Razorpay _razorpay;
  
  // State variables
  List<Address> savedAddresses = [];
  int selectedAddressIndex = -1;
  String selectedPaymentMethod = 'cod';
  bool isAddingNewAddress = false;
  bool isEditingAddress = false;
  bool isLoading = true;
  bool isSavingAddress = false;
  bool isProcessingPayment = false;
  String? _token;
  String? editingAddressId;
  String? specialRequests;
  
  // Cart data from arguments
  double totalAmount = 0.0;
  List<dynamic> cartItems = [];
  double deliveryFee = 0.0;
  double taxRate = 0.0;

  // Controllers for address form
  final TextEditingController titleController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController flatHouseController = TextEditingController();
  final TextEditingController floorController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getCartArguments();
    if (_token == null) {
      _initializeAndFetchAddresses();
    }
  }

  void _getCartArguments() {

    final arguments = ModalRoute.of(context)?.settings.arguments;
    

if (arguments != null && arguments is Map<String, dynamic>) {
  specialRequests = arguments['specialRequests'] as String?;

}
    if (arguments != null && arguments is Map<String, dynamic>) {
      final amountValue = arguments['amount'];
      
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
      
      final itemsValue = arguments['cartItems'];
      List<dynamic> parsedItems = [];
      if (itemsValue is List) {
        parsedItems = itemsValue;
      } else if (itemsValue != null) {
        parsedItems = [itemsValue];
      }
      
      setState(() {
        totalAmount = parsedAmount;
        cartItems = parsedItems;
      });
    } else {
      setState(() {
        totalAmount = 0.0;
        cartItems = [];
      });
    }
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _initializeAndFetchAddresses() async {
    await _getAuthToken();
    await _fetchAddresses();
  }

  Future<void> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _token = prefs.getString('auth_token');
      });
      
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
    flatHouseController.dispose();
    floorController.dispose();
    areaController.dispose();
    landmarkController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  double get subtotal => totalAmount;
  double get taxAmount => subtotal * taxRate;
  double get finalTotal => subtotal + deliveryFee + taxAmount;

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

  String _buildCompleteAddress() {
    List<String> addressParts = [];
    
    if (flatHouseController.text.trim().isNotEmpty) {
      addressParts.add(flatHouseController.text.trim());
    }
    
    if (floorController.text.trim().isNotEmpty) {
      addressParts.add('Floor: ${floorController.text.trim()}');
    }
    
    if (areaController.text.trim().isNotEmpty) {
      addressParts.add(areaController.text.trim());
    }
    
    if (landmarkController.text.trim().isNotEmpty) {
      addressParts.add('Near ${landmarkController.text.trim()}');
    }
    
    if (addressController.text.trim().isNotEmpty) {
      addressParts.add(addressController.text.trim());
    }
    
    return addressParts.join(', ');
  }

  Future<void> _loadAddresses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$addressEndpoint'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          setState(() {
            savedAddresses = (responseData['addresses'] as List)
                .map((address) => Address.fromJson(address))
                .toList();
                
            // Set the first address as selected if none selected
            if (savedAddresses.isNotEmpty && selectedAddressIndex == -1) {
              selectedAddressIndex = 0;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading addresses: $e');
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSavingAddress = true;
    });

    try {
      // Create the complete address string by combining all fields
      String completeAddress = _buildCompleteAddress();
      
      Map<String, dynamic> addressData = {
        'title': titleController.text.trim(),
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': completeAddress, // Send the complete formatted address
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
        'isDefault': savedAddresses.isEmpty, // First address is default
      };

      String url;
      http.Response response;
      
      if (isEditingAddress && editingAddressId != null) {
        url = '$baseUrl$addressEndpoint/$editingAddressId';
        response = await http.put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: json.encode(addressData),
        );
      } else {
        url = '$baseUrl$addressEndpoint';
        response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: json.encode(addressData),
        );
      }

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success']) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Address saved successfully'),
              backgroundColor: Colors.red,
            ),
          );

          // Refresh the addresses list
          await _loadAddresses();

          // Reset form state
          setState(() {
            isAddingNewAddress = false;
            isEditingAddress = false;
            editingAddressId = null;
          });
          _clearAddressForm();

        } else {
          throw Exception(responseData['message'] ?? 'Failed to save address');
        }
      } else {
        throw Exception(responseData['message'] ?? 'Server error');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSavingAddress = false;
      });
    }
  }

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

  Future<void> _initiateRazorpayPayment() async {
    try {
      setState(() {
        isProcessingPayment = true;
      });

      final orderData = await _createRazorpayOrder();
      
      if (orderData != null) {
        var options = {
          'key': 'rzp_live_vegmIuWT1fULsb',
          'amount': (finalTotal * 100).toInt(),
          'name': 'Your App Name',
          'description': 'Order Payment',
          'order_id': orderData['id'],
          'prefill': {
            'contact': savedAddresses[selectedAddressIndex].phone,
            'email': 'customer@example.com'
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

  Future<Map<String, dynamic>?> _createRazorpayOrder() async {
    try {
      final requestBody = json.encode({
        'amount': (finalTotal * 100).toInt(),
        'currency': 'INR',
        'receipt': 'order_${DateTime.now().millisecondsSinceEpoch}',
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/create-razorpay-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Failed to create Razorpay order');
        return null;
      }
    } catch (e) {
      _showErrorSnackBar('Error creating Razorpay order: ${e.toString()}');
      return null;
    }
  }

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
        'specialRequests': specialRequests,
      };

      final response = await http.post(
        Uri.parse('$baseUrl$orderEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(orderData),
      );

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

  void _populateAddressForm(Address address) {
    titleController.text = address.title;
    nameController.text = address.name;
    phoneController.text = address.phone;
    addressController.text = address.address;
    cityController.text = address.city;
    stateController.text = address.state;
    pincodeController.text = address.pincode;
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        
        title: const Text(
          'Payment & Delivery',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                color: Colors.red,
              ),
            )
          : Column(
              children: [
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

  Widget _buildCartSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
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
              Icon(Icons.shopping_cart, color: Colors.red[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Cart Items (${cartItems.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
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
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.fastfood, color: Colors.red[400], size: 20),
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
        border: Border.all(color: Colors.red[100]!),
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
              Icon(Icons.location_on, color: Colors.red[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Show selected address or add new address option
          if (savedAddresses.isNotEmpty && !isAddingNewAddress && !isEditingAddress)
            _buildSelectedAddress()
          else if (savedAddresses.isEmpty && !isAddingNewAddress && !isEditingAddress)
            _buildAddAddressCard()
          
          // Show address form for adding/editing
          else if (isAddingNewAddress || isEditingAddress)
            _buildAddressForm(),
        ],
      ),
    );
  }

  Widget _buildSelectedAddress() {
    if (selectedAddressIndex == -1 || 
        selectedAddressIndex >= savedAddresses.length ||
        savedAddresses.isEmpty) {
      return _buildAddAddressCard();
    }
    
    Address address = savedAddresses[selectedAddressIndex];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!, width: 2),
        
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[400],
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
                IconButton(
                  icon: Icon(Icons.menu, color: Colors.grey[600]),
                  tooltip: 'Address actions',
                  onPressed: () {
                    // Open drawer where address management and edit/delete actions are available
                    final scaffoldState = Scaffold.maybeOf(context);
                    if (scaffoldState?.hasDrawer ?? false) {
                      scaffoldState!.openDrawer();
                    } else {
                      // Fallback: navigate to addresses screen
                      Navigator.pushNamed(context, '/addresses');
                    }
                  },
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
              address.fullAddressFormatted,
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
    );
  }

  Widget _buildAddAddressCard() {
    return InkWell(
      onTap: () {
        setState(() {
          isAddingNewAddress = true;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 32,
              color: Colors.red[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Add Delivery Address',
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add your delivery address',
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

  Widget _buildAddressForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEditingAddress ? 'Edit Address' : 'Add New Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[400],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      isAddingNewAddress = false;
                      isEditingAddress = false;
                      editingAddressId = null;
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
            
            // Address Title/Type
            _buildTextField(
              titleController, 
              '*Address Type (Home/Office/Other)', 
              Icons.label,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Full Name
            _buildTextField(
              nameController, 
              '*Full Name', 
              Icons.person,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Phone Number
            _buildTextField(
              phoneController, 
              '*Phone Number', 
              Icons.phone, 
              keyboardType: TextInputType.phone,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Flat/House No/Building Name
            _buildTextField(
              flatHouseController, 
              '*Flat/House No/Building Name', 
              Icons.home,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Floor (Optional)
            _buildTextField(
              floorController, 
              'Floor (Optional)', 
              Icons.layers,
              isRequired: false
            ),
            const SizedBox(height: 12),
            
            // Area/Sector/Locality
            _buildTextField(
              areaController, 
              '*Area/Sector/Locality', 
              Icons.location_on,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Nearby Landmark
            _buildTextField(
              landmarkController, 
              '*Nearby Landmark', 
              Icons.place,
              isRequired: true
            ),
            const SizedBox(height: 12),
            
            // Complete Address
            _buildTextField(
              addressController, 
              '*Complete Address (Min 25 characters)', 
              Icons.home_outlined, 
              maxLines: 3,
              isRequired: true,
              minLength: 25
            ),
            const SizedBox(height: 12),
            
            // City and State Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    cityController, 
                    '*City', 
                    Icons.location_city,
                    isRequired: true
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    stateController, 
                    '*State', 
                    Icons.map,
                    isRequired: true
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Pincode
            _buildTextField(
              pincodeController, 
              '*Pincode', 
              Icons.pin_drop, 
              keyboardType: TextInputType.number,
              isRequired: true
            ),
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        isAddingNewAddress = false;
                        isEditingAddress = false;
                        editingAddressId = null;
                      });
                      _clearAddressForm();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red[400]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSavingAddress ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
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
                        : Text(
                            isEditingAddress ? 'Update Address' : 'Save Address',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    int? minLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red[400]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red[400]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      validator: (value) {
        String trimmedValue = value?.trim() ?? '';
        
        // Required field validation
        if (isRequired && trimmedValue.isEmpty) {
          return 'This field is required';
        }
        
        // Skip further validation if field is optional and empty
        if (!isRequired && trimmedValue.isEmpty) {
          return null;
        }
        
        // Minimum length validation
        if (minLength != null && trimmedValue.length < minLength) {
          return 'Minimum $minLength characters required';
        }
        
        // General minimum length (at least 2 characters for all required fields except phone/pincode)
        if (isRequired && controller != phoneController && controller != pincodeController) {
          if (trimmedValue.length < 2) {
            return 'Please enter at least 2 characters';
          }
        }
        
        // Phone number validation
        if (controller == phoneController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[0-9]{10}$').hasMatch(trimmedValue)) {
            return 'Enter a valid 10-digit phone number';
          }
        }
        
        // Pincode validation
        if (controller == pincodeController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[0-9]{6}$').hasMatch(trimmedValue)) {
            return 'Enter a valid 6-digit pincode';
          }
        }

        // Name validation (only letters and spaces)
        if (controller == nameController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z\s]{3,}$').hasMatch(trimmedValue)) {
            return 'Enter a valid name';
          }
        }
        
        // City validation (only letters and spaces)
        if (controller == cityController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z\s]{3,}$').hasMatch(trimmedValue)) {
            return 'Enter a valid city name';
          }
        }
        
        // State validation (only letters and spaces)
        if (controller == stateController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z\s]{3,}$').hasMatch(trimmedValue)) {
            return 'Enter a valid state name';
          }
        }
        
        // Complete address special validation
        if (controller == addressController && trimmedValue.isNotEmpty) {
          if (trimmedValue.length < 25) {
            return 'Enter complete address';
          }
          // Check if it's not just repeated characters or spaces
          String cleanAddress = trimmedValue.replaceAll(RegExp(r'\s+'), ' ');
          if (cleanAddress.length < 25) {
            return 'Enter complete address (minimum 25 characters)';
          }
        }
        
        // Flat/House validation (alphanumeric allowed)
        if (controller == flatHouseController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z0-9\s\-\/]{2,}$').hasMatch(trimmedValue)) {
            return 'Enter valid flat/house details';
          }
        }
        
        // Area/Sector/Locality validation
        if (controller == areaController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z0-9\s\-]{2,}$').hasMatch(trimmedValue)) {
            return 'Enter valid area/sector';
          }
        }
        
        // Landmark validation
        if (controller == landmarkController && trimmedValue.isNotEmpty) {
          if (trimmedValue.length < 3) {
            return 'Enter valid landmark';
          }
        }
        
        // Floor validation (optional, but if entered should be valid)
        if (controller == floorController && trimmedValue.isNotEmpty) {
          if (!RegExp(r'^[a-zA-Z0-9\s]{1,}$').hasMatch(trimmedValue)) {
            return 'Enter valid floor details';
          }
        }
        
        return null;
      },
    );
  }

  void _clearAddressForm() {
    titleController.clear();
    nameController.clear();
    phoneController.clear();
    flatHouseController.clear();
    floorController.clear();
    areaController.clear();
    landmarkController.clear();
    addressController.clear();
    cityController.clear();
    stateController.clear();
    pincodeController.clear();
  }

  void _showAddressSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Address'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: savedAddresses.length,
              itemBuilder: (context, index) {
                Address address = savedAddresses[index];
                bool isSelected = selectedAddressIndex == index;
                
                return RadioListTile<int>(
                  value: index,
                  groupValue: selectedAddressIndex,
                  onChanged: (value) {
                    setState(() {
                      selectedAddressIndex = value!;
                    });
                    Navigator.pop(context);
                  },
                  title: Text(address.name),
                  subtitle: Text('${address.title}\n${address.fullAddressFormatted}'),
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red[400] : Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      address.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  activeColor: Colors.red[400],
                  isThreeLine: true,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  isAddingNewAddress = true;
                });
              },
              child: Text('Add New', style: TextStyle(color: Colors.red[400])),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[50]!),
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
              Icon(Icons.payment, color: Colors.red[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
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
            color: isSelected ? Colors.red[400]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.red[10] : Colors.white,
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
              activeColor: Colors.red[400],
            ),
            Icon(icon, color: Colors.red[400], size: 24),
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
        border: Border.all(color: Colors.red[100]!),
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
              Icon(Icons.receipt_long, color: Colors.red[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
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
                  Icon(Icons.warning, color: Colors.black.withOpacity(0.6), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cart amount is ₹ 0.00. Please check your cart.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            _buildSummaryRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(2)}'),
            const Divider(thickness: 1),
            _buildSummaryRow('Total Amount', '₹${finalTotal.toStringAsFixed(2)}', isTotal: true),
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
              color: isTotal ? Colors.red[400] : Colors.grey[700],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.red[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    bool canProceed = savedAddresses.isNotEmpty && 
                     selectedAddressIndex >= 0 && 
                     selectedAddressIndex < savedAddresses.length;

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
                    Icon(Icons.warning, color: Colors.orange[600], size: 15),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Please select a delivery address to continue',
                        style: TextStyle(fontSize: 10),
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
                        '₹${finalTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.7),
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
                      backgroundColor: (canProceed && !isProcessingPayment && totalAmount > 0) ? Colors.red[400] : Colors.grey[400],
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
        'specialRequests': specialRequests, 
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

// Address model class
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
    required this.isDefault,
  });

  String get fullAddressFormatted => '$address, $city, $state - $pincode';

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