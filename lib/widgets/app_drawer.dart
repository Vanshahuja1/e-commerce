import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final List<dynamic> products;

  const AppDrawer({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 70, // Much smaller than default DrawerHeader height
              decoration: BoxDecoration(color: Colors.red.shade400),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ..._getCategories().map((category) {
              final categoryProducts = products.where((p) {
                final cat = p['category']?.toString().toLowerCase() ?? '';
                return cat.contains(category.toLowerCase());
              }).take(3).toList();

              return ExpansionTile(
                title: Text(category, style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  if (categoryProducts.isEmpty)
                    ListTile(title: Text('No products', style: TextStyle(color: Colors.grey))),
                  ...categoryProducts.map((product) {
                    return ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                            ? Image.network(product['imageUrl'].toString(), fit: BoxFit.cover)
                            : Icon(Icons.image, color: Colors.grey),
                      ),
                      title: Text(product['name']?.toString() ?? 'Unknown'),
                      subtitle: Text('₹${product['price']?.toString() ?? ''}'),
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.pushNamed(context, '/showcase', arguments: product);
                      },
                    );
                  }),
                  ListTile(
                    title: Text('View All $category', style: TextStyle(color: Colors.red.shade400)),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pushNamed(context, '/search', arguments: {'category': category});
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _getCategories() {
    // Instead of hardcoded categories, generate from actual product data
    final Set<String> uniqueCategories = {};

    for (var product in products) {
      final category = product['category']?.toString();
      if (category != null && category.isNotEmpty) {
        uniqueCategories.add(category);
      }
    }

    // If no categories found in data, fallback to default categories
    if (uniqueCategories.isEmpty) {
      return const [
        'Savory',
        'Namkeen',
        'Sweet',
        'Travel Pack Combo',
        'Value Pack Offers',
        'Gift Packs',
      ];
    }

    return uniqueCategories.toList()..sort();
  }
}