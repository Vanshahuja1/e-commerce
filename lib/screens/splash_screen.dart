import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSliderBox = true;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      color: Color(0xFFFAE54A),
      title: 'Welcome to\ntazaj',
      description: 'Buy Fresh. Eat Well',
      subtitle: 'Fruits & Vegetables',
      lottiePath: 'assets/animations/pineapple.json',
      buttonText: 'Direction Location',
      buttonColor: Color(0xFF27C96C),
      locationText: 'Start needs your location?',
    ),
    OnboardingSlide(
      color: Color(0xFF27C96C),
      title: 'LOGIN',
      description: 'Enter your phone number to proceed',
      subtitle: '',
      lottiePath: 'assets/animations/apple.json',
      buttonText: 'Enter phone number',
      buttonColor: Color(0xFFF30201),
      locationText: '',
    ),
    OnboardingSlide(
      color: Color(0xFFF15230),
      title: 'delivery to\nYour Doorstep',
      description: 'Fresh, quality products delivered fast. Easy, reliable, and right to your doorstep.',
      subtitle: '',
      lottiePath: 'assets/animations/delivery.json',
      buttonText: 'Get Started',
      buttonColor: Color(0xFFF15230),
      locationText: '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _startAutoSlide();
    });
    _showSliderBox = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSliderBoxWithDelay();
    });
  }

  void _showSliderBoxWithDelay() async {
    setState(() {
      _showSliderBox = false;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _showSliderBox = true;
      });
    }
  }

  void _startAutoSlide() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      int nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage = nextPage;
      });
      _showSliderBoxWithDelay();
      if (nextPage == 0) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return false;
      }
      return true;
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView for slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _showSliderBoxWithDelay();
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              if (index == 0) {
                // First slide with LEFT-ALIGNED animation layout
                return Container(
                  color: _slides[index].color,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Title Section
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.only(top: 60, bottom: 0, left: 20, right: 20),
                            child: Text(
                              _slides[index].title,
                              style: GoogleFonts.poppins(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Animation Section - LEFT-ALIGNED with left shift
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            clipBehavior: Clip.none, // Don't clip the overflowing content
                            child: Stack(
                              clipBehavior: Clip.none, // Don't clip in Stack either
                              children: [
                                Positioned(
                                  left: -40, // Position 40 pixels to the left of center
                                  top: 0,
                                  bottom: 0,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.9, // Even more width
                                    child: Center(
                                      child: Lottie.asset(
                                        slide.lottiePath,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Description Section
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(height: 40),
                                Text(
                                  _slides[index].description,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _slides[index].subtitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (index == 1) {
                // Second slide with login layout
                return Container(
                  color: _slides[index].color,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Center(
                              child: Transform.scale(
                                scale: 0.8,
                                child: Lottie.asset(slide.lottiePath, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (index == 2) {
                return Container(
                  color: _slides[index].color,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Center(
                              child: Transform.scale(
                                scale: 1.3,
                                child: Lottie.asset(slide.lottiePath, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  color: _slides[index].color,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 100,
                          color: Colors.white,
                        ),
                        SizedBox(height: 30),
                        Text(
                          _slides[index].title,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _slides[index].description,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
          if (_showSliderBox)
            Positioned(
              bottom: 60,
              left: 20,
              right: 20,
              child: AnimatedSlide(
                offset: _showSliderBox ? Offset.zero : Offset(0, 0.3),
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage == 0) ...[
                        if (_slides[_currentPage].locationText.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 15),
                            child: Text(
                              _slides[_currentPage].locationText,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _navigateToHome,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _slides[_currentPage].buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              _slides[_currentPage].buttonText,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else if (_currentPage == 1) ...[
                        Text(
                          _slides[_currentPage].title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _slides[_currentPage].description,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                            ),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: '+973',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _navigateToHome,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _slides[_currentPage].buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 5,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _slides[_currentPage].buttonText,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.grey[400],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                'or',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _navigateToHome,
                              child: Container(
                                width: 35,
                                height: 35,
                                child: Image.asset(
                                  'assets/images/facebook.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(width: 15),
                            GestureDetector(
                              onTap: _navigateToHome,
                              child: Container(
                                width: 35,
                                height: 35,
                                child: Image.asset(
                                  'assets/images/google.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_currentPage == 2) ...[
                        Container(
                          width: 72,
                          height: 72,
                          child: Image.asset(
                            'assets/images/location.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          _slides[_currentPage].title,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey[700],
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 15),
                        Text(
                          _slides[_currentPage].description,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 25),
                      ] else ...[
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _navigateToHome,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _slides[_currentPage].buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              _slides[_currentPage].buttonText,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 5),
                  width: _currentPage == index ? 25 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? _slides[_currentPage].buttonColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 15,
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: _slides[_currentPage].color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _currentPage == 0 ? Colors.black : Colors.white,
                  width: 1.5,
                ),
              ),
              child: TextButton(
                onPressed: _navigateToHome,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Skip',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _currentPage == 0 ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingSlide {
  final Color color;
  final String title;
  final String description;
  final String subtitle;
  final String lottiePath;
  final String buttonText;
  final Color buttonColor;
  final String locationText;

  OnboardingSlide({
    required this.color,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.lottiePath,
    required this.buttonText,
    required this.buttonColor,
    required this.locationText,
  });
}