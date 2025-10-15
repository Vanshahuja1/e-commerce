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
            // Header
            Container(
              height: 70,
              decoration: BoxDecoration(color: Colors.red.shade400),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: const Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            
            // Categories (dynamic from products)
            ..._getCategories().map((category) {
              final categoryProducts = products.where((p) {
                final cat = p['category']?.toString().toLowerCase() ?? '';
                return cat.contains(category.toLowerCase());
              }).take(3).toList();

              return ExpansionTile(
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  if (categoryProducts.isEmpty)
                    const ListTile(
                      title: Text('No products', style: TextStyle(color: Colors.grey)),
                    ),
                  ...categoryProducts.map((product) {
                    return ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                            ? Image.network(product['imageUrl'].toString(), fit: BoxFit.cover)
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                      title: Text(product['name']?.toString() ?? 'Unknown'),
                      subtitle: Text('₹${product['price']?.toString() ?? ''}'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/showcase', arguments: product);
                      },
                    );
                  }),
                  ListTile(
                    title: Text('View All $category', style: TextStyle(color: Colors.red.shade400)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/search', arguments: {'category': category});
                    },
                  ),
                ],
              );
            }),
            
            // Contact Us footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ListTile(
                leading: Icon(Icons.contact_support, color: Colors.red.shade400),
                title: Text(
                  'Contact Us',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/contact-us');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getCategories() {
    final Set<String> uniqueCategories = {};

    for (var product in products) {
      final category = product['category']?.toString();
      if (category != null && category.isNotEmpty) {
        uniqueCategories.add(category);
      }
    }

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