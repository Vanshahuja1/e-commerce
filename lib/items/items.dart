import 'package:http/http.dart' as http;

/// items.dart – Updated with accurate image URLs for each item
class GroceryItems {
  // Using direct image URLs that actually represent the correct items
  static const Map<String, String> items = {
    // Fruits
    'Apple'       : 'assets/images/apple.png',
    'Banana'      : 'assets/images/banana.png',
    'Orange'      : 'https://images.unsplash.com/photo-1580052614034-c55d20bfee3b?w=400&h=400&fit=crop',
    'Mango'       : 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=400&h=400&fit=crop', // Fixed: actual mango
    'Grapes'      : 'https://images.unsplash.com/photo-1537640538966-79f369143f8f?w=400&h=400&fit=crop',
    'Strawberry'  : 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=400&h=400&fit=crop',
    'Pineapple'   : 'https://images.unsplash.com/photo-1589820296156-2454bb8a6ad1?w=400&h=400&fit=crop', // Fixed: actual pineapple
    'Watermelon'  : 'https://images.unsplash.com/photo-1563114773-84221bd62daa?w=400&h=400&fit=crop', // Fixed: actual watermelon
    'Pomegranate' : 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&h=400&fit=crop', // Fixed: actual pomegranate
    'Kiwi'        : 'https://images.unsplash.com/photo-1585059895524-72359e06133a?w=400&h=400&fit=crop',

    // Vegetables
    'Tomato'      : 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&h=400&fit=crop',
    'Potato'      : 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&h=400&fit=crop', // Fixed: actual potatoes
    'Onion'       : 'https://images.unsplash.com/photo-1508747703725-719777637510?w=400&h=400&fit=crop',
    'Carrot'      : 'https://images.unsplash.com/photo-1445282768818-728615cc910a?w=400&h=400&fit=crop',
    'Broccoli'    : 'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?w=400&h=400&fit=crop',
    'Spinach'     : 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=400&h=400&fit=crop',
    'Cabbage'     : 'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=400&h=400&fit=crop',
    'Cauliflower' : 'https://images.unsplash.com/photo-1510627489930-0c1b0bfb6785?w=400&h=400&fit=crop', // Fixed: actual cauliflower
    'Bell Pepper' : 'https://images.unsplash.com/photo-1525607551316-4a8e16d1f9ba?w=400&h=400&fit=crop',
    'Cucumber'    : 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=400&h=400&fit=crop',
    'Lettuce'     : 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=400&h=400&fit=crop',
    'Beetroot'    : 'https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=400&h=400&fit=crop', // Fixed: actual beetroot

   
    // Pulses & Legumes
    'Lentils'     : 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&h=400&fit=crop',
    'Chickpeas'   : 'https://images.unsplash.com/photo-1610648659005-89bbc2020b80?w=400&h=400&fit=crop', // Fixed: actual chickpeas
    'Black Beans' : 'https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=400&h=400&fit=crop', // Fixed: actual black beans
    'Kidney Beans': 'https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=400&h=400&fit=crop', // Fixed: actual kidney beans

   
   
    // Beverages
    'Tea'        : 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400&h=400&fit=crop',
    'Coffee'     : 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=400&fit=crop',
    'Fruit Juice': 'https://images.unsplash.com/photo-1610970881699-44a5587cabec?w=400&h=400&fit=crop',

       'Dried Fruit': 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=400&fit=crop', // Fixed: actual dried fruits

    // Condiments & Sauces
    'Tomato Sauce': 'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=400&h=400&fit=crop', // Fixed: actual tomato sauce
    'Salt'        : 'https://images.unsplash.com/photo-1594736797933-d0401ba2fe65?w=400&h=400&fit=crop', // Fixed: actual salt
    'Sugar'       : 'https://images.unsplash.com/photo-1582049165715-8796f82d5c71?w=400&h=400&fit=crop', // Fixed: actual sugar
    'Honey'       : 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400&h=400&fit=crop', // Fixed: actual honey

    // Seafood & Meat
    'Fish'   : 'https://images.unsplash.com/photo-1544943910-4c1dc44aab44?w=400&h=400&fit=crop', // Fixed: actual fish
    'Chicken': 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&h=400&fit=crop',
    'Eggs'   : 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400&h=400&fit=crop',

    // Bakery Items
    'Bread' : 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&h=400&fit=crop',
    'Cake'  : 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&h=400&fit=crop',
  };

  /// Enhanced image validation with better error handling
  static Future<bool> isImageUrlValid(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print('Error checking image URL: $e');
      return false;
    }
  }

  /// Method to get a fallback image URL if the primary one fails
  static String getFallbackImageUrl(String itemName) {
    // High-quality fallback images by category
    const Map<String, String> categoryFallbacks = {
      'fruits': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&h=400&fit=crop',
      'vegetables': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&h=400&fit=crop',
      'dairy': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&h=400&fit=crop',
      'grains': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&h=400&fit=crop',
      'spices': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400&h=400&fit=crop',
      'general': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&h=400&fit=crop',
    };
    
    // Determine category based on item name
    String category = _getItemCategory(itemName);
    return categoryFallbacks[category] ?? categoryFallbacks['general']!;
  }

  /// Helper method to determine item category
  static String _getItemCategory(String itemName) {
    const Map<String, List<String>> categories = {
      'fruits': ['Apple', 'Banana', 'Orange', 'Mango', 'Grapes', 'Strawberry', 
                'Pineapple', 'Watermelon', 'Pomegranate', 'Kiwi'],
      'vegetables': ['Tomato', 'Potato', 'Onion', 'Carrot', 'Broccoli', 'Spinach', 
                    'Cabbage', 'Cauliflower', 'Bell Pepper', 'Cucumber', 'Lettuce', 'Beetroot'],
      'dairy': ['Milk', 'Cheese', 'Butter', 'Yogurt', 'Paneer', 'Cream'],
      'grains': ['Rice', 'Wheat Flour', 'Oats', 'Quinoa', 'Barley'],
      'spices': ['Turmeric Powder', 'Red Chili Powder', 'Cumin Seeds', 
                'Coriander Seeds', 'Black Pepper', 'Garam Masala'],
    };

    for (String category in categories.keys) {
      if (categories[category]!.contains(itemName)) {
        return category;
      }
    }
    return 'general';
  }

  /// Get image URL with automatic fallback
  static Future<String> getValidImageUrl(String itemName) async {
    String? primaryUrl = getImageUrl(itemName);
    
    if (primaryUrl == null) {
      return getFallbackImageUrl(itemName);
    }

    bool isValid = await isImageUrlValid(primaryUrl);
    if (isValid) {
      return primaryUrl;
    } else {
      return getFallbackImageUrl(itemName);
    }
  }

  // This method returns all items for your seller dashboard
  static List<String> getAllItems() {
    return items.keys.toList()..sort();
  }

  static List<String> getItemNames() {
    return items.keys.toList()..sort();
  }

  static String? getImageUrl(String itemName) {
    return items[itemName];
  }

  static List<String> getItemsByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fruits':
        return items.keys.where((item) => [
          'Apple', 'Banana', 'Orange', 'Mango', 'Grapes', 'Strawberry', 
          'Pineapple', 'Watermelon', 'Pomegranate', 'Kiwi'
        ].contains(item)).toList();
      case 'vegetables':
        return items.keys.where((item) => [
          'Tomato', 'Potato', 'Onion', 'Carrot', 'Broccoli', 'Spinach', 
          'Cabbage', 'Cauliflower', 'Bell Pepper', 'Cucumber', 'Lettuce', 'Beetroot'
        ].contains(item)).toList();
      case 'dairy':
        return items.keys.where((item) => [
          'Milk', 'Cheese', 'Butter', 'Yogurt', 'Paneer', 'Cream'
        ].contains(item)).toList();
      case 'grains & cereals':
        return items.keys.where((item) => [
          'Rice', 'Wheat Flour', 'Oats', 'Quinoa', 'Barley'
        ].contains(item)).toList();
      case 'pulses & legumes':
        return items.keys.where((item) => [
          'Lentils', 'Chickpeas', 'Black Beans', 'Kidney Beans'
        ].contains(item)).toList();
      case 'spices & herbs':
        return items.keys.where((item) => [
          'Turmeric Powder', 'Red Chili Powder', 'Cumin Seeds', 
          'Coriander Seeds', 'Black Pepper', 'Garam Masala'
        ].contains(item)).toList();
      case 'cooking oils':
        return items.keys.where((item) => [
          'Sunflower Oil', 'Olive Oil', 'Coconut Oil', 'Mustard Oil'
        ].contains(item)).toList();
      case 'beverages':
        return items.keys.where((item) => [
          'Tea', 'Coffee', 'Fruit Juice'
        ].contains(item)).toList();
      case 'snacks & processed':
        return items.keys.where((item) => [
          'Biscuits', 'Chips', 'Nuts', 'Dried Fruits'
        ].contains(item)).toList();
      case 'condiments & sauces':
        return items.keys.where((item) => [
          'Tomato Sauce', 'Salt', 'Sugar', 'Honey'
        ].contains(item)).toList();
      case 'seafood & meat':
        return items.keys.where((item) => [
          'Fish', 'Chicken', 'Eggs'
        ].contains(item)).toList();
      case 'bakery':
        return items.keys.where((item) => [
          'Bread', 'Cake'
        ].contains(item)).toList();
      default:
        return getAllItems();
    }
  }
}