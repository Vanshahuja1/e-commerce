import 'package:flutter/material.dart';
import '../../utils/app_routes.dart'; // Adjust the path as needed

class CategorySection extends StatelessWidget {
  const CategorySection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔹 List for the top trail
    final List<String> trails = [
      'All',
      'Fresh Fruit',
      'Vegetables',
      'Herbs & Lettuce',
      'Dried Fruit',
 
    ];

    // 🔹 List for the category icons (unchanged)
    final List<Map<String, dynamic>> categories = [
      {'name': 'All', 'image': 'assets/images/fruits.png', 'color': const Color.fromARGB(255, 227, 42, 42)},
      {'name': 'Banana', 'image': 'assets/images/banana.png', 'color': const Color.fromARGB(255, 247, 222, 2)},
      {'name': 'Apple', 'image': 'assets/images/apple.png', 'color': const Color.fromARGB(255, 12, 99, 18)},
       {'name': 'berries', 'image': 'assets/images/berries1.png', 'color': const Color.fromARGB(255, 61, 8, 8)},
      {'name': 'Citrus', 'image': 'assets/images/citrus1.png', 'color': const Color.fromARGB(255, 250, 47, 1)},
      {'name': 'Melons', 'image': 'assets/images/melons1.png', 'color': const Color.fromARGB(255, 170, 245, 7)},
     
     
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Top Trail (Deals, Fresh Fruits, Vegetables, etc.)
          // 🔹 Top Trail (Deals, Fresh Fruits, Vegetables, etc.)
Container(
  margin: const EdgeInsets.only(bottom: 8),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: trails.map((item) {
        return Padding(
          padding: const EdgeInsets.only(right: 12), // spacing between items
          child: Text(
            item,
            style: TextStyle(
              fontSize: 11, // smaller font size
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        );
      }).toList(),
    ),
  ),
),


          // 🔹 Category icons (unchanged)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 2),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  width: 65,
                  margin: const EdgeInsets.only(right: 2),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.search,
                        arguments: {'category': category['name']},
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: (category['color'] as Color),
                            borderRadius: BorderRadius.circular(22.5),
                            border: Border.all(
                              color: (category['color'] as Color),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22.5),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Image.asset(
                                category['image'] as String,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    size: 22,
                                    color: category['color'] as Color,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Container(
                            width: 60,
                            child: Text(
                              category['name'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
