import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final List<Map<String, dynamic>> categories = [
 {
        'name': 'Savory',
        'image': 'assets/images/images.png',
        'color': const Color.fromARGB(255, 245, 176, 112),
      },
      {
        'name': 'Namkeen',
        'image': 'assets/images/images (1).png',
        'color': const Color.fromARGB(255, 223, 238, 142),
      },
      {
        'name': 'Sweet',
        'image': 'assets/images/images (2).jpg',
        'color': const Color.fromARGB(195, 210, 255, 250),
      },
     
       {
        'name': 'Travel Pack Combo',
        'image': 'assets/images/travelpack.png',
       'color': const Color.fromARGB(255, 255, 211, 229),
      },
      {
        'name': 'Value Pack Offers',
        'image': 'assets/images/valuepack.png',
       'color': const Color.fromARGB(255, 200, 252, 221),
      },
      {
        'name': 'Gift Packs',
        'image': 'assets/images/giftpack.png',
       'color': const Color.fromARGB(255, 233, 218, 255),
      },
     
     
    ];

    //  Mapping of specific items to broader categories
    final Map<String, String> categoryMapping = {
      'Savory': 'Savory',
      'Namkeen': 'Namkeen',
      'Sweets': 'Sweets',
      'Combo': 'Travel Pack Combo',
      'Value Pack Offers': 'Value Pack Offers',
      'Gift Packs': 'Gift Packs',
     
    };

    //  Helper to resolve the mapped category or fallback
    String resolveCategory(String raw) {
      return categoryMapping[raw] ?? raw;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  Category Icon Row
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 2),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final String name = category['name'] as String;
                return Container(
                  width: 65,
                  margin: const EdgeInsets.only(right: 2),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.search,
                        arguments: {'category': name},
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: category['color'] as Color,
                            borderRadius: BorderRadius.circular(22.5),
                            border: Border.all(
                              color: category['color'] as Color,
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
                              name,
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
