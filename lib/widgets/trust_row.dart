import 'package:flutter/material.dart';

class TrustRow extends StatelessWidget {
  const TrustRow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color backgroundRed = Color(0xFF9D2B35); // deep red similar to image
    const Color onRed = Colors.white;

    return Container(
      color: backgroundRed,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 2 columns grid as shown in the image (2x2)
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 32,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85, // Adjusted to give more vertical space
            ),
            children: const [
              _TrustItem(
                icon: Icons.public,
                title: 'Loved By India',
                description:
                    'Trusted by over 10,00,000 satisfied customers nationwide.',
              ),
              _TrustItem(
                icon: Icons.pan_tool_outlined,
                title: 'Handmade',
                description:
                    'Every item is crafted by hand with love and tradition.',
              ),
              _TrustItem(
                icon: Icons.schedule,
                title: 'Ships In 1–2 Days',
                description:
                    'Prompt delivery to guarantee freshness at your doorstep.',
              ),
              _TrustItem(
                icon: Icons.science_outlined,
                title: 'No Preservatives',
                description:
                    '100% natural ingredients for pure, fresh taste every time.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    const Color onRed = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: onRed,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: onRed,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: onRed.withOpacity(0.9),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}