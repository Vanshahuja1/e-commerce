import 'package:flutter/material.dart';
import '/models/user_model.dart';

class Footer extends StatelessWidget {
  final UserModel? currentUser;
  final bool isLoggedIn;
  final VoidCallback onHomeTap;
  final VoidCallback onCategoriesTap;
  final VoidCallback onDiscountTap;
  final VoidCallback onProfileTap;
  final int currentIndex;

  const Footer({
    Key? key,
    this.currentUser,
    this.isLoggedIn = false,
    required this.onHomeTap,
    required this.onCategoriesTap,
    required this.onDiscountTap,
    required this.onProfileTap,
    this.currentIndex = 0,
  }) : super(key: key);

  void _handleLoginRedirect(BuildContext context) {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade50.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = constraints.maxWidth > 550 ? 25.0 : 19.0;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 600 ? 40 : 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. Home
                  _buildFooterItem(
                    imagePath: 'assets/images/ico_home.png',
                    label: 'Home',
                    isActive: currentIndex == 0,
                    iconSize: iconSize,
                    onTap: onHomeTap,
                    context: context,
                  ),
                  // 2. Categories
                  _buildFooterItem(
                    imagePath: 'assets/images/ico_category.png',
                    label: 'Categories',
                    isActive: currentIndex == 1,
                    iconSize: iconSize,
                    onTap: onCategoriesTap,
                    context: context,
                  ),
                  // 3. Discount
                  _buildFooterItem(
                    imagePath: 'assets/images/ico_discount.png',
                    label: 'Discount',
                    isActive: currentIndex == 2,
                    iconSize: iconSize,
                    onTap: onDiscountTap,
                    context: context,
                  ),
                  // 4. Profile
                  _buildFooterItem(
                    imagePath: 'assets/images/ico_user.png',
                    label: isLoggedIn ? 'Profile' : 'Login',
                    isActive: currentIndex == 3,
                    iconSize: iconSize,
                    onTap: isLoggedIn ? onProfileTap : () => _handleLoginRedirect(context),
                    context: context,
                    requiresLogin: !isLoggedIn,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooterItem({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
    required BuildContext context,
    bool isActive = false,
    bool highlight = false,
    bool requiresLogin = false,
    double iconSize = 24.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive || highlight
              ? Colors.red.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  imagePath,
                  width: iconSize,
                  height: iconSize,
                  color: isActive || highlight 
                      ? Colors.red.shade500 
                      : (requiresLogin)
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                ),
                if (requiresLogin)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive || highlight
                    ? Colors.red.shade500
                    : (requiresLogin)
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                fontWeight: isActive || highlight
                    ? FontWeight.bold
                    : FontWeight.normal,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}