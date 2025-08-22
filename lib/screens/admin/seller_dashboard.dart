import 'package:flutter/material.dart';
import 'dart:io';
import 'constants.dart';
import 'models.dart';
import 'widgets.dart';
import 'forms.dart';
import '../../items/items.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({Key? key}) : super(key: key);

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> with TickerProviderStateMixin {
  Map<String, dynamic>? userInfo;
  List<Map<String, dynamic>> myItems = [];
  bool isLoading = true;
  bool isRefreshing = false;
  int selectedIndex = 0;
  bool isSidebarOpen = false;
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  String? errorMessage;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  String selectedCategory = 'Fruits';
  String selectedUnit = 'kg';
  String? selectedImageUrl;
  String? selectedPredefinedItem;
  bool isEditMode = false;
  String? editingItemId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initAndLoad();
  }

  void _initializeAnimations() {
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sidebarController, curve: Curves.easeInOutCubic),
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      isSidebarOpen = !isSidebarOpen;
      if (isSidebarOpen) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  Future<void> _initAndLoad() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final userInfoData = await ApiService.loadUserInfo();
      final itemsData = await ApiService.loadMyItems();
      setState(() {
        userInfo = userInfoData;
        myItems = itemsData;
      });
      _fadeController.forward();
      _scaleController.forward();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data. Please check your connection.';
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
      errorMessage = null;
    });
    try {
      final userInfoData = await ApiService.loadUserInfo();
      final itemsData = await ApiService.loadMyItems();
      setState(() {
        userInfo = userInfoData;
        myItems = itemsData;
      });
      _showSnackBar('Data refreshed successfully', isError: false);
    } catch (e) {
      _showSnackBar('Failed to refresh data', isError: true);
    }
    setState(() => isRefreshing = false);
  }

  Future<void> _publishItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = selectedImageUrl;
      
      if (selectedPredefinedItem != null) {
        imageUrl = GroceryItems.getImageUrl(selectedPredefinedItem!);
      }
      
      final itemData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'category': selectedCategory,
        'imageUrl': imageUrl,
        'quantity': int.parse(_quantityController.text),
        'unit': selectedUnit,
      };
      
      final success = await ApiService.publishItem(itemData, itemId: editingItemId);
      if (success) {
        _showSnackBar(isEditMode ? 'Item updated successfully!' : 'Item published successfully!');
        _clearForm();
        await _refreshData();
        setState(() => selectedIndex = 0);
      } else {
        _showSnackBar('Error ${isEditMode ? 'updating' : 'publishing'} item', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _quantityController.clear();
    selectedCategory = 'Fruits';
    selectedUnit = 'kg';
    selectedImageUrl = null;
    selectedPredefinedItem = null;
    isEditMode = false;
    editingItemId = null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: Duration(seconds: isError ? 4 : 3),
        elevation: 8,
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pop();
  }

  void _editItem(Map<String, dynamic> item) {
    _nameController.text = item['name']?.toString() ?? '';
    _descriptionController.text = item['description']?.toString() ?? '';
    _priceController.text = item['price']?.toString() ?? '';
    _quantityController.text = item['quantity']?.toString() ?? '';
    selectedCategory = item['category']?.toString() ?? 'Fruits';
    selectedUnit = item['unit']?.toString() ?? 'kg';
    selectedImageUrl = item['imageUrl']?.toString();
    
    setState(() {
      isEditMode = true;
      editingItemId = item['_id']?.toString() ?? item['id']?.toString();
      selectedIndex = 1;
    });
  }

  void _showItemActions(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item['imageUrl'] != null
                            ? Image.network(
                                item['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_outlined);
                                },
                              )
                            : const Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹${item['price']}/${item['unit']}',
                            style: const TextStyle(
                              color: AppConstants.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildActionTile(
                icon: Icons.edit_outlined,
                title: 'Edit Item',
                subtitle: 'Modify item details',
                color: AppConstants.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  _editItem(item);
                },
              ),
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete Item',
                subtitle: 'Remove from inventory',
                color: AppConstants.errorColor,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(item);
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppConstants.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppConstants.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppConstants.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Delete Item',
                style: TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${item['name']}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: AppConstants.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final itemId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
              final success = await ApiService.deleteItem(itemId);
              if (success) {
                _showSnackBar('Item deleted successfully!');
                await _refreshData();
              } else {
                _showSnackBar('Error deleting item', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
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
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: CustomAppBar(
        onMenuTap: _toggleSidebar,
        onRefresh: _refreshData,
        isRefreshing: isRefreshing,
        isLoading: isLoading,
        sidebarAnimation: _sidebarAnimation,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMainContent()),
            if (isSidebarOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleSidebar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
            CustomSidebar(
              sidebarAnimation: _sidebarAnimation,
              userInfo: userInfo,
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  selectedIndex = index;
                  _toggleSidebar();
                });
              },
              onHomePressed: _navigateToHome,
              isEditMode: isEditMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _getSelectedView(),
      ),
    );
  }

  Widget _getSelectedView() {
    switch (selectedIndex) {
      case 0:
        return _buildMyItemsView();
      case 1:
        return ItemForm(
          formKey: _formKey,
          nameController: _nameController,
          descriptionController: _descriptionController,
          priceController: _priceController,
          quantityController: _quantityController,
          selectedCategory: selectedCategory,
          selectedUnit: selectedUnit,
          selectedImageUrl: selectedImageUrl,
          selectedPredefinedItem: selectedPredefinedItem,
          isEditMode: isEditMode,
          isLoading: isLoading,
          onCategoryChanged: (value) => setState(() => selectedCategory = value),
          onUnitChanged: (value) => setState(() => selectedUnit = value),
          onPredefinedItemChanged: (value) {
            setState(() {
              selectedPredefinedItem = value;
              selectedImageUrl = value != null ? GroceryItems.getImageUrl(value) : null;
            });
          },
          onSubmit: _publishItem,
        );
      case 2:
        return _buildManageItemsView();
      default:
        return _buildMyItemsView();
    }
  }

  Widget _buildLoadingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 600 ? 48.0 : 24.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppConstants.primaryColor),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Loading your dashboard...',
                        style: TextStyle(
                          color: AppConstants.textSecondary,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please wait while we fetch your data',
                        style: TextStyle(
                          color: AppConstants.textTertiary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth > 600 ? 48.0 : 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppConstants.errorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: AppConstants.errorColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: constraints.maxWidth > 600 ? 24 : 20,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppConstants.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _initAndLoad,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyItemsView() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppConstants.primaryColor,
      strokeWidth: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 1200 ? 1200 : constraints.maxWidth,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: _getHorizontalPadding(constraints.maxWidth),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildSectionHeader(
                          title: 'My Items',
                          subtitle: 'Manage your product inventory',
                          trailing: _buildItemsCounter(),
                          constraints: constraints,
                        ),
                      ),
                      myItems.isEmpty
                          ? Container(
                              height: constraints.maxHeight * 0.6,
                              child: EmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'No items in your inventory',
                                subtitle: 'Start building your product catalog by adding your first item',
                                buttonText: 'Add Your First Item',
                                onPressed: () => setState(() => selectedIndex = 1),
                              ),
                            )
                          : _buildResponsiveGrid(constraints),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageItemsView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth > 1200 ? 1200 : constraints.maxWidth,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: _getHorizontalPadding(constraints.maxWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _buildSectionHeader(
                    title: 'Manage Items',
                    subtitle: 'Edit and organize your products',
                    trailing: _buildItemsCounter(),
                    constraints: constraints,
                  ),
                ),
                Expanded(
                  child: myItems.isEmpty
                      ? EmptyState(
                          icon: Icons.manage_search_outlined,
                          title: 'No items to manage',
                          subtitle: 'Add some items to your inventory first',
                          buttonText: 'Add Items',
                          onPressed: () => setState(() => selectedIndex = 1),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshData,
                          color: AppConstants.primaryColor,
                          strokeWidth: 3,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: 8,
                              bottom: MediaQuery.of(context).padding.bottom + 24,
                            ),
                            itemCount: myItems.length,
                            itemBuilder: (context, index) {
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 400 + (index * 100)),
                                curve: Curves.easeOutBack,
                                child: _buildManageItemCard(myItems[index], index, constraints),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth > 1200) return 32.0;
    if (screenWidth > 800) return 24.0;
    if (screenWidth > 600) return 20.0;
    return 16.0;
  }

  Widget _buildResponsiveGrid(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    int crossAxisCount = 2;
    double childAspectRatio = 0.75;
    double crossAxisSpacing = 12;
    double mainAxisSpacing = 12;
    
    // Improved responsive breakpoints
    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.8;
      crossAxisSpacing = 20;
      mainAxisSpacing = 20;
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
      childAspectRatio = 0.8;
      crossAxisSpacing = 16;
      mainAxisSpacing = 16;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.8;
      crossAxisSpacing = 14;
      mainAxisSpacing = 14;
    } else if (screenWidth > 400) {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
      crossAxisSpacing = 12;
      mainAxisSpacing = 12;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 1.2;
      crossAxisSpacing = 8;
      mainAxisSpacing = 8;
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: crossAxisSpacing / 2,
        vertical: 8,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: myItems.length,
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutBack,
          child: _buildItemCard(myItems[index], index, constraints),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
    required BoxConstraints constraints,
  }) {
    final isCompact = constraints.maxWidth < 600;
    final titleSize = isCompact ? 24.0 : 32.0;
    final subtitleSize = isCompact ? 14.0 : 16.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isCompact) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: AppConstants.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              if (trailing != null) ...[
                const SizedBox(height: 16),
                trailing,
              ],
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        color: AppConstants.textSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing,
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildItemsCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor.withOpacity(0.1),
            AppConstants.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${myItems.length} ${myItems.length == 1 ? 'Item' : 'Items'}',
              style: const TextStyle(
                color: AppConstants.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index, BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 400;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showItemActions(item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: item['imageUrl'] != null
                          ? Image.network(
                              item['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: isSmallScreen ? 24 : 32,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                size: isSmallScreen ? 24 : 32,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 12 : 14,
                          color: AppConstants.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '₹${item['price']}',
                                style: TextStyle(
                                  color: AppConstants.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '/${item['unit']}',
                              style: TextStyle(
                                color: AppConstants.textSecondary,
                                fontSize: isSmallScreen ? 10 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['quantity']} ${item['unit']}',
                                style: TextStyle(
                                  color: AppConstants.primaryColor,
                                  fontSize: isSmallScreen ? 9 : 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.more_vert_rounded,
                            color: AppConstants.textTertiary,
                            size: isSmallScreen ? 14 : 16,
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
      ),
    );
  }

  Widget _buildManageItemCard(Map<String, dynamic> item, int index, BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showItemActions(item),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 50 : 60,
                  height: isSmallScreen ? 50 : 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: item['imageUrl'] != null
                        ? Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_outlined,
                                color: Colors.grey,
                                size: isSmallScreen ? 20 : 24,
                              );
                            },
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: isSmallScreen ? 20 : 24,
                          ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 14 : 16,
                          color: AppConstants.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['description'] ?? 'No description',
                        style: TextStyle(
                          color: AppConstants.textSecondary,
                          fontSize: isSmallScreen ? 11 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item['category'] ?? 'Unknown',
                              style: TextStyle(
                                color: AppConstants.primaryColor,
                                fontSize: isSmallScreen ? 9 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${item['quantity']} ${item['unit']}',
                            style: TextStyle(
                              color: AppConstants.textSecondary,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${item['price']}',
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                    ),
                    Text(
                      '/${item['unit']}',
                      style: TextStyle(
                        color: AppConstants.textSecondary,
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.more_vert_rounded,
                      color: AppConstants.textTertiary,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}