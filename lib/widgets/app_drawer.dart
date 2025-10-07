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
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.red.shade400),
              child: Text(
                'Categories',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ..._getCategories().map((category) {
              final categoryProducts = products.where((p) {
                final cat = p['category']?.toString().toLowerCase() ?? '';
                return cat == category.toLowerCase() ||
                       cat.contains(category.toLowerCase()) ||
                       category.toLowerCase().contains(cat);
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
    return const [
      'Savory',
      'Namkeen',
      'Sweet',
      'Travel Pack Combo',
      'Value Pack Offers',
      'Gift Packs',
    ];
  }
}
