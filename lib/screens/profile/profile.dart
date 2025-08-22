import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  String? _token;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Form controllers for editing (only name and phone needed now)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Admin stats
  Map<String, dynamic>? _adminStats;

  @override
  void initState() {
    super.initState();
    // Initialize with default length, will be updated in _loadUserData
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      
      if (_token == null) {
        _redirectToLogin();
        return;
      }

      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _user = data['user'];
            
            // Update TabController based on user type
            _tabController.dispose();
            int tabLength = _user?['userType'] == 'admin' ? 3 : 2;
            _tabController = TabController(length: tabLength, vsync: this);
            
            _isLoading = false;
          });

          // Load admin stats if user is admin
          if (_user?['userType'] == 'admin') {
            _loadAdminStats();
          }
        } else {
          _showError(data['message'] ?? 'Failed to load user data');
        }
      } else {
        _showError('Failed to load user data');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  Future<void> _loadAdminStats() async {
    try {
      final response = await http.get(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/admin/stats'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _adminStats = data['stats'];
          });
        }
      }
    } catch (e) {
      print('Error loading admin stats: $e');
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushReplacementNamed('/login');
  }

 
  Future<void> _updateProfile() async {
    // Close the dialog first
    Navigator.pop(context);
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Updating profile...'),
          ],
        ),
      ),
    );

    try {
      // Prepare the request body with only changed fields
      Map<String, dynamic> requestBody = {};
      
      if (_nameController.text.trim() != (_user?['name'] ?? '')) {
        requestBody['name'] = _nameController.text.trim();
      }
      
      if (_phoneController.text.trim() != (_user?['phone'] ?? '')) {
        requestBody['phone'] = _phoneController.text.trim();
      }
      
      // If no changes, just close loading and show message
      if (requestBody.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to update'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('https://backend-ecommerce-app-co1r.onrender.com/api/user/update-info'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      // Close loading dialog
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Update local user data
          setState(() {
            if (requestBody.containsKey('name')) {
              _user!['name'] = _nameController.text.trim();
            }
            if (requestBody.containsKey('phone')) {
              _user!['phone'] = _phoneController.text.trim();
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showError(data['message'] ?? 'Failed to update profile');
        }
      } else {
        final data = json.decode(response.body);
        _showError(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.pop(context);
      _showError('Network error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Failed to load user data'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 20),
                _buildTabSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.green[600],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _user?['name'] ?? 'Profile',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green[700]!,
                Colors.green[500]!,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
        ),
      ],
    );
  }

  // ...existing code...

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  backgroundImage: _user?['profileImage'] != null
                      ? NetworkImage(_user!['profileImage'])
                      : null,
                  child: _user?['profileImage'] == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.green[600],
                        )
                      : null,
                ),
                // REMOVED: green dot Positioned widget
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user?['name'] ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildUserTypeChip(),
          const SizedBox(height: 16),
          _buildUserInfo(),
        ],
      ),
    );
  }

  Widget _buildUserTypeChip() {
    Color chipColor;
    IconData chipIcon;
    String userType = _user?['userType'] ?? 'buyer';

    // Only allow 'admin' or 'buyer'
    if (userType == 'admin') {
      chipColor = Colors.red;
      chipIcon = Icons.admin_panel_settings;
      userType = 'ADMIN';
    } else {
      chipColor = Colors.green;
      chipIcon = Icons.shopping_cart;
      userType = 'BUYER';
    }

    return Chip(
      avatar: Icon(chipIcon, color: Colors.white, size: 18),
      label: Text(
        userType,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
    );
  }

// ...existing code...

  Widget _buildUserInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.email, _user?['email'] ?? ''),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.phone, _user?['phone'] ?? ''),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSection() {
    List<Widget> tabs = [
      const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
      const Tab(text: 'Settings', icon: Icon(Icons.settings)),
    ];

    List<Widget> tabViews = [
      _buildOverviewTab(),
      _buildSettingsTab(),
    ];

    // Add admin tab for admin users
    if (_user?['userType'] == 'admin') {
      tabs.add(const Tab(text: 'Admin', icon: Icon(Icons.admin_panel_settings)));
      tabViews.add(_buildAdminTab());
    }

    return Container(
      height: 600,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green[600],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green[600],
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    String status = 'Active';
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsItem(
            Icons.edit,
            'Edit Profile',
            'Update your name and mobile number',
            () => _showEditProfileDialog(),
          ),
          _buildSettingsItem(
            Icons.notifications,
            'Notifications',
            'Manage notification preferences',
            () {},
          ),
          _buildSettingsItem(
            Icons.help,
            'Help & Support',
            'Get help and contact support',
            () {},
          ),
          _buildSettingsItem(
            Icons.info,
            'About',
            'App version and information',
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_adminStats != null) _buildAdminStats(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            icon: const Icon(Icons.dashboard),
            label: const Text('Go to Admin Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Total Users',
          _adminStats!['totalUsers'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Products',
          _adminStats!['totalProducts']?.toString() ?? '0',
          Icons.inventory,
          Colors.green,
        ),
        _buildStatCard(
          'Active Products',
          _adminStats!['activeProducts']?.toString() ?? '0',
          Icons.verified,
          Colors.purple,
        ),
        _buildStatCard(
          'Total Orders',
          _adminStats!['totalOrders']?.toString() ?? '0',
          Icons.shopping_bag,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // Updated Edit Profile Dialog - Only Name and Mobile Number
  void _showEditProfileDialog() {
    // Reset controllers with current values
    _nameController.text = _user?['name'] ?? '';
    _phoneController.text = _user?['phone'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _updateProfile(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
