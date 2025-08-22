import 'package:flutter/material.dart';
import 'constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final bool isLoading;
  final Animation<double> sidebarAnimation;

  const CustomAppBar({
    Key? key,
    required this.onMenuTap,
    this.onRefresh,
    this.isRefreshing = false,
    this.isLoading = false,
    required this.sidebarAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Seller Dashboard', 
        style: TextStyle(
          fontWeight: FontWeight.w700, 
          fontSize: 22,
          letterSpacing: -0.8,
        )
      ),
      backgroundColor: AppConstants.surfaceColor,
      foregroundColor: AppConstants.textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.borderColor.withOpacity(0.1),
                AppConstants.borderColor,
                AppConstants.borderColor.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onMenuTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.borderLight),
              ),
              child: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: sidebarAnimation,
                color: AppConstants.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (!isLoading && onRefresh != null)
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isRefreshing ? null : onRefresh,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.borderLight),
                  ),
                  child: isRefreshing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CustomSidebar extends StatelessWidget {
  final Animation<double> sidebarAnimation;
  final Map<String, dynamic>? userInfo;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onHomePressed;
  final bool isEditMode;

  const CustomSidebar({
    Key? key,
    required this.sidebarAnimation,
    this.userInfo,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onHomePressed,
    this.isEditMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sidebarAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-300 * (1 - sidebarAnimation.value), 0),
          child: Container(
            width: 300,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 32,
                  offset: const Offset(8, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildUserProfileSection(),
                Expanded(child: _buildNavigationMenu()),
                _buildSidebarFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserProfileSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppConstants.primaryColor, AppConstants.primaryDark],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppConstants.primaryLight,
              child: Text(
                userInfo?['name']?.substring(0, 1).toUpperCase() ?? 'S',
                style: const TextStyle(
                  fontSize: 32, 
                  color: Colors.white, 
                  fontWeight: FontWeight.w800
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            userInfo?['name'] ?? 'Loading...',
            style: const TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userInfo?['email'] ?? 'Loading...',
              style: const TextStyle(
                fontSize: 13, 
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard', 'Overview & Analytics'),
        _buildNavItem(1, Icons.add_business_rounded, isEditMode ? 'Edit Item' : 'Add New Item', 'Manage Products'),
        _buildNavItem(2, Icons.inventory_2_rounded, 'Manage Items', 'Edit & Organize'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Divider(color: AppConstants.borderLight, thickness: 1),
        ),
        _buildNavItem(-1, Icons.home_rounded, 'Back to Home', 'Return to Main', isHome: true),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title, String subtitle, {bool isHome = false}) {
    final isSelected = selectedIndex == index && !isHome;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isHome) {
              onHomePressed();
            } else {
              onItemSelected(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected 
                ? Border.all(color: AppConstants.primaryColor.withOpacity(0.3))
                : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? AppConstants.primaryColor.withOpacity(0.2) 
                      : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? AppConstants.primaryColor : AppConstants.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? AppConstants.primaryColor : AppConstants.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isSelected ? AppConstants.primaryColor.withOpacity(0.7) : AppConstants.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppConstants.backgroundColor,
        border: Border(top: BorderSide(color: AppConstants.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: AppConstants.primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller Portal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'v2.1.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onTap;

  const ItemCard({
    Key? key,
    required this.item,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final itemName = item['name']?.toString() ?? 'Unknown Item';
    final itemPrice = item['price']?.toString() ?? '0';
    final itemUnit = item['unit']?.toString() ?? 'unit';
    final itemQuantity = item['quantity']?.toString() ?? '0';
    final itemCategory = item['category']?.toString() ?? 'Unknown';
    final itemImageUrl = item['imageUrl']?.toString();

    return Hero(
      tag: 'item_${item['_id'] ?? item['id'] ?? index}',
      child: Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppConstants.borderLight, width: 1.5),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50.withOpacity(0.5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        color: Colors.grey.shade100,
                        child: itemImageUrl != null && itemImageUrl.isNotEmpty
                            ? Image.network(
                                itemImageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 120,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : const Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          itemCategory,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 90,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 32,
                        child: Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '₹$itemPrice/$itemUnit',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppConstants.primaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$itemQuantity $itemUnit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppConstants.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: onTap,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppConstants.backgroundColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppConstants.borderLight),
                                    ),
                                    child: const Icon(
                                      Icons.more_vert_rounded,
                                      color: AppConstants.textSecondary,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 72,
              color: AppConstants.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppConstants.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: AppConstants.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
