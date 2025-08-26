class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> images;
  final int stock;
  final bool isActive;
  final int discount; // Discount percentage (0-100)
  final int tax; // Tax percentage (0-100)
  final bool hasVAT; // Whether VAT is applicable
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.images,
    required this.stock,
    this.isActive = true,
    this.discount = 0,
    this.tax = 0,
    this.hasVAT = false,
    this.createdAt,
    this.updatedAt,
  });

  // Calculate discounted price
  double get discountedPrice {
    if (discount > 0) {
      return price - (price * discount / 100);
    }
    return price;
  }

  // Calculate price with tax
  double get priceWithTax {
    if (tax > 0) {
      return discountedPrice + (discountedPrice * tax / 100);
    }
    return discountedPrice;
  }

  // Calculate final price (with discount, tax, and VAT if applicable)
  double get finalPrice {
    double basePrice = priceWithTax;
    if (hasVAT) {
      // Assuming standard VAT rate of 18% - you can modify this as needed
      const double vatRate = 18.0;
      basePrice += (basePrice * vatRate / 100);
    }
    return basePrice;
  }

  // Calculate discount amount
  double get discountAmount {
    if (discount > 0) {
      return price * discount / 100;
    }
    return 0.0;
  }

  // Calculate tax amount
  double get taxAmount {
    if (tax > 0) {
      return discountedPrice * tax / 100;
    }
    return 0.0;
  }

  // Calculate VAT amount
  double get vatAmount {
    if (hasVAT) {
      const double vatRate = 18.0;
      return priceWithTax * vatRate / 100;
    }
    return 0.0;
  }

  // Convert ProductModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'images': images,
      'stock': stock,
      'isActive': isActive,
      'discount': discount,
      'tax': tax,
      'hasVAT': hasVAT,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create ProductModel from JSON
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
      discount: json['discount'] ?? 0,
      tax: json['tax'] ?? 0,
      hasVAT: json['hasVAT'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // Copy ProductModel with updated fields
  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? images,
    int? stock,
    bool? isActive,
    int? discount,
    int? tax,
    bool? hasVAT,
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
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      hasVAT: hasVAT ?? this.hasVAT,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $price, stock: $stock, discount: $discount%, tax: $tax%, hasVAT: $hasVAT)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CartItem {
  final String productId;
  final String productName;
  final double price;
  final String image;
  final int quantity;
  final int discount; // Discount percentage
  final int tax; // Tax percentage
  final bool hasVAT; // Whether VAT is applicable

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.image,
    required this.quantity,
    this.discount = 0,
    this.tax = 0,
    this.hasVAT = false,
  });

  // Calculate discounted price per item
  double get discountedPrice {
    if (discount > 0) {
      return price - (price * discount / 100);
    }
    return price;
  }

  // Calculate price with tax per item
  double get priceWithTax {
    if (tax > 0) {
      return discountedPrice + (discountedPrice * tax / 100);
    }
    return discountedPrice;
  }

  // Calculate final price per item (with discount, tax, and VAT if applicable)
  double get finalPricePerItem {
    double basePrice = priceWithTax;
    if (hasVAT) {
      const double vatRate = 18.0;
      basePrice += (basePrice * vatRate / 100);
    }
    return basePrice;
  }

  // Calculate total price for all quantities
  double get totalPrice => finalPricePerItem * quantity;

  // Calculate total discount amount for all quantities
  double get totalDiscountAmount {
    if (discount > 0) {
      return (price * discount / 100) * quantity;
    }
    return 0.0;
  }

  // Calculate total tax amount for all quantities
  double get totalTaxAmount {
    if (tax > 0) {
      return (discountedPrice * tax / 100) * quantity;
    }
    return 0.0;
  }

  // Calculate total VAT amount for all quantities
  double get totalVATAmount {
    if (hasVAT) {
      const double vatRate = 18.0;
      return (priceWithTax * vatRate / 100) * quantity;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'image': image,
      'quantity': quantity,
      'discount': discount,
      'tax': tax,
      'hasVAT': hasVAT,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      image: json['image'] ?? '',
      quantity: json['quantity'] ?? 0,
      discount: json['discount'] ?? 0,
      tax: json['tax'] ?? 0,
      hasVAT: json['hasVAT'] ?? false,
    );
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    double? price,
    String? image,
    int? quantity,
    int? discount,
    int? tax,
    bool? hasVAT,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      hasVAT: hasVAT ?? this.hasVAT,
    );
  }

  // Factory method to create CartItem from ProductModel
  factory CartItem.fromProduct(ProductModel product, {required int quantity}) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      price: product.price,
      image: product.images.isNotEmpty ? product.images.first : '',
      quantity: quantity,
      discount: product.discount,
      tax: product.tax,
      hasVAT: product.hasVAT,
    );
  }
}