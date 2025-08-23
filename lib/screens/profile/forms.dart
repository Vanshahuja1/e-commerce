import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'constants.dart';
import '../../items/items.dart';

class ItemForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final String selectedCategory;
  final String selectedUnit;
  final String? selectedImageUrl;
  final String? selectedPredefinedItem;
  final File? selectedImageFile;
  final bool usePredefindedImage;
  final bool isEditMode;
  final bool isLoading;
  final Function(String) onCategoryChanged;
  final Function(String) onUnitChanged;
  final Function(String?) onPredefinedItemChanged;
  final Function(File?) onImageFileChanged;
  final Function(bool) onImageModeChanged;
  final VoidCallback onSubmit;

  const ItemForm({
    Key? key,
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.quantityController,
    required this.selectedCategory,
    required this.selectedUnit,
    this.selectedImageUrl,
    this.selectedPredefinedItem,
    this.selectedImageFile,
    required this.usePredefindedImage,
    required this.isEditMode,
    required this.isLoading,
    required this.onCategoryChanged,
    required this.onUnitChanged,
    required this.onPredefinedItemChanged,
    required this.onImageFileChanged,
    required this.onImageModeChanged,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      widget.onImageFileChanged(File(pickedFile.path));
      widget.onImageModeChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: widget.isEditMode ? 'Edit Item' : 'Add New Item',
            subtitle: widget.isEditMode ? 'Update your product details' : 'Expand your product catalog',
          ),
          const SizedBox(height: 32),
          Form(
            key: widget.formKey,
            child: Column(
              children: [
                _buildImageSelectionSection(),
                const SizedBox(height: 24),
                _buildFormFields(),
                const SizedBox(height: 32),
                _buildPublishButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isCompact ? 28 : 36,
                fontWeight: FontWeight.w800,
                color: AppConstants.textPrimary,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: AppConstants.textSecondary,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppConstants.borderLight, width: 1.5),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Product Image',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 600
                ? Row(
                    children: [
                      Expanded(
                        child: _buildImageOption(
                          title: 'Use Predefined',
                          subtitle: 'Choose from our collection',
                          icon: Icons.collections_rounded,
                          isSelected: widget.usePredefindedImage,
                          onTap: () => widget.onImageModeChanged(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildImageOption(
                          title: 'Upload Custom',
                          subtitle: 'Use your own image',
                          icon: Icons.cloud_upload_rounded,
                          isSelected: !widget.usePredefindedImage,
                          onTap: () => widget.onImageModeChanged(false),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildImageOption(
                        title: 'Use Predefined',
                        subtitle: 'Choose from our collection',
                        icon: Icons.collections_rounded,
                        isSelected: widget.usePredefindedImage,
                        onTap: () => widget.onImageModeChanged(true),
                      ),
                      const SizedBox(height: 12),
                      _buildImageOption(
                        title: 'Upload Custom',
                        subtitle: 'Use your own image',
                        icon: Icons.cloud_upload_rounded,
                        isSelected: !widget.usePredefindedImage,
                        onTap: () => widget.onImageModeChanged(false),
                      ),
                    ],
                  );
            },
          ),
          const SizedBox(height: 24),
          if (widget.usePredefindedImage) _buildPredefinedImageSelector(),
          if (!widget.usePredefindedImage) _buildCustomImageUploader(),
        ],
      ),
    );
  }

  Widget _buildImageOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor.withOpacity(0.08) : AppConstants.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppConstants.primaryColor : AppConstants.borderLight,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppConstants.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isSelected ? AppConstants.primaryColor : AppConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppConstants.primaryColor.withOpacity(0.7) : AppConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredefinedImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: widget.selectedPredefinedItem,
          decoration: InputDecoration(
            labelText: 'Select Item',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConstants.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConstants.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            filled: true,
            fillColor: AppConstants.backgroundColor,
          ),
          isExpanded: true,
          items: GroceryItems.getAllItems().map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: widget.onPredefinedItemChanged,
        ),
        if (widget.selectedPredefinedItem != null && widget.selectedImageUrl != null) ...[
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.borderLight, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                widget.selectedImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.image_not_supported_outlined),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomImageUploader() {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppConstants.borderLight,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: widget.selectedImageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      widget.selectedImageFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to upload image',
                        style: TextStyle(
                          color: AppConstants.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG, PNG up to 5MB',
                        style: TextStyle(
                          color: AppConstants.textSecondary,
                          fontSize: 13,
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

  Widget _buildFormFields() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppConstants.borderLight, width: 1.5),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Product Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: widget.nameController,
            label: 'Product Name',
            hint: 'Enter product name',
            icon: Icons.inventory_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter product name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: widget.descriptionController,
            label: 'Description',
            hint: 'Enter product description',
            icon: Icons.description_rounded,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter description';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 600
                ? Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: widget.priceController,
                          label: 'Price (BHD)',
                          hint: '0.00',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter valid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: widget.quantityController,
                          label: 'Quantity',
                          hint: '0',
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter quantity';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter valid quantity';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: widget.priceController,
                        label: 'Price (BHD)',
                        hint: '0.00',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: widget.quantityController,
                        label: 'Quantity',
                        hint: '0',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter valid quantity';
                          }
                          return null;
                        },
                      ),
                    ],
                  );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 600
                ? Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Category',
                          value: widget.selectedCategory,
                          items: AppConstants.categories,
                          icon: Icons.category_rounded,
                          onChanged: (value) => widget.onCategoryChanged(value!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Unit',
                          value: widget.selectedUnit,
                          items: AppConstants.units,
                          icon: Icons.straighten_rounded,
                          onChanged: (value) => widget.onUnitChanged(value!),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildDropdown(
                        label: 'Category',
                        value: widget.selectedCategory,
                        items: AppConstants.categories,
                        icon: Icons.category_rounded,
                        onChanged: (value) => widget.onCategoryChanged(value!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        label: 'Unit',
                        value: widget.selectedUnit,
                        items: AppConstants.units,
                        icon: Icons.straighten_rounded,
                        onChanged: (value) => widget.onUnitChanged(value!),
                      ),
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppConstants.primaryColor,
            size: 18,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        filled: true,
        fillColor: AppConstants.backgroundColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppConstants.primaryColor,
            size: 18,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
        filled: true,
        fillColor: AppConstants.backgroundColor,
      ),
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: AppConstants.primaryColor.withOpacity(0.3),
        ),
        child: widget.isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isEditMode ? Icons.update_rounded : Icons.publish_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isEditMode ? 'Update Item' : 'Publish Item',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
