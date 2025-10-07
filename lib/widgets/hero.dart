import 'package:flutter/material.dart';
import 'dart:async';

class HeroSection extends StatefulWidget {
  const HeroSection({Key? key}) : super(key: key);

  @override
  _HeroSectionState createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  final int _totalPages = 5; // Changed to 5 for the 5 images

  // List of your asset images
  final List<String> _images = [
    'assets/images/slder1.jpg', // Replace with your actual image names
    'assets/images/slider2.jpg',
    'assets/images/slider3.jpg',
    'assets/images/slidedr4.jpg',
    'assets/images/slider5.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.9, // Increased to show more of current card
      initialPage: 1000, // Start from a high number to allow infinite scrolling in both directions
    );
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 4, left: 8, right: 8), // Removed top margin
      child: Container(
        height: 325, // Reduced height
        child: PageView.builder(
          controller: _pageController,
          itemCount: null, // Infinite scroll
          itemBuilder: (context, index) {
            final imageIndex = index % _totalPages;
            return _buildImageSlide(imageIndex);
          },
          onPageChanged: (index) {
            setState(() {
              _currentPage = index % _totalPages;
            });
          },
        ),
      ),
    );
  }

  Widget _buildImageSlide(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced to 1px margin
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Image.asset(
        _images[index],
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          // Fallback widget if image fails to load
          return Container(
            color: Colors.grey.shade200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 40,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 8),
                Text(
                  'Image ${index + 1}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}