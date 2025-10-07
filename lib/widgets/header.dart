import 'package:flutter/material.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';
import '/services/cart_service.dart';

class Header extends StatefulWidget implements PreferredSizeWidget {
  final int cartItemCount;
  final UserModel? currentUser;
  final bool isLoggedIn;
  final VoidCallback onCartTap;
  final VoidCallback onProfileTap;
  
  final VoidCallback? onSearchTap; // Made optional
  final VoidCallback onLogout;

  const Header({
    Key? key,
    required this.cartItemCount,
    this.currentUser,
    this.isLoggedIn = false,
    required this.onCartTap,
    required this.onProfileTap,
   
    this.onSearchTap, // Made optional
    required this.onLogout,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  int _realTimeCartCount = 0;
  bool _isLoadingCart = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _loadRealTimeCartCount();
    }
  }

  @override
  void didUpdateWidget(Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update real-time count when widget updates
    if (widget.isLoggedIn && oldWidget.cartItemCount != widget.cartItemCount) {
      _loadRealTimeCartCount();
    }
  }

  Future<void> _loadRealTimeCartCount() async {
    if (_isLoadingCart || !widget.isLoggedIn) return;
    
    setState(() {
      _isLoadingCart = true;
    });

    try {
      final count = await CartService.getCartItemCount();
      if (mounted) {
        setState(() {
          _realTimeCartCount = count;
          _isLoadingCart = false;
        });
      }
    } catch (e) {
      print('Error loading cart count: $e');
      if (mounted) {
        setState(() {
          _realTimeCartCount = widget.cartItemCount; // Fallback to passed count
          _isLoadingCart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isDesktop = screenWidth >= 1024;
    final isMobile = screenWidth < 768;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          tooltip: 'Menu',
          onPressed: () {
            final scaffoldState = Scaffold.maybeOf(ctx);
            if (scaffoldState?.hasDrawer ?? false) {
              scaffoldState!.openDrawer();
            }
          },
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SizedBox(
          height: 36,
          child: Image.asset('images/logo1.png', fit: BoxFit.contain),
        ),
      ),
      actions: _buildActions(isDesktop, isTablet, isMobile, context),
    );
  }

  List<Widget> _buildActions(bool isDesktop, bool isTablet, bool isMobile, BuildContext context) {
    // Categories previously accessible via three-dot menu are now in the drawer.
    // Keep cart and profile actions as before.
    return <Widget>[
      const SizedBox(width: 8),
      _buildCartButton(context),
      const SizedBox(width: 2),
      _buildProfileButton(context),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildCartButton(BuildContext context) {
    // Use real-time count if available and logged in, otherwise show 0
    final displayCount = widget.isLoggedIn ? (_realTimeCartCount > 0 ? _realTimeCartCount : widget.cartItemCount) : 0;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          color: const Color.fromARGB(255, 11, 11, 11),
          onPressed: () {
            if (widget.isLoggedIn) {
              Navigator.pushNamed(context, '/cart');
              _loadRealTimeCartCount();
            } else {
              Navigator.pushNamed(context, '/login');
            }
          },
          tooltip: 'Cart',
          iconSize: 20,
        ),
        if (displayCount > 0 && widget.isLoggedIn)
          Positioned(
            right:4,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: _isLoadingCart
                  ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      displayCount > 99 ? '99+' : '$displayCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return IconButton(
      icon: Image.asset(
        'assets/images/ico_user.png',
        width: 20,
        height: 20,
        color: const Color.fromARGB(255, 5, 5, 5),
      ),
      onPressed: () {
        if (widget.isLoggedIn) {
          if (widget.currentUser?.userType == 'admin') {
            Navigator.pushNamed(context, '/admin');
          } else {
            Navigator.pushNamed(context, '/profile');
          }
        } else {
          Navigator.pushNamed(context, '/login');
        }
      },
      tooltip: 'Profile',
      iconSize: 20,
    );
  }
}