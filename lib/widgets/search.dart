import 'package:flutter/material.dart';
import 'dart:async';

class SearchWidget extends StatefulWidget {
  final Function(String)? onSearch;
  final String? initialQuery;
  final String hintText;

  const SearchWidget({
    Key? key,
    this.onSearch,
    this.initialQuery,
    this.hintText = 'Search for products',
  }) : super(key: key);

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _bannerScrollController = ScrollController();
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _startBannerScroll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _bannerTimer?.cancel();
    _bannerScrollController.dispose();
    super.dispose();
  }

  void _startBannerScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(milliseconds: 25), (_) async {
      if (!_bannerScrollController.hasClients) return;
      final position = _bannerScrollController.position;
      final max = position.maxScrollExtent;
      final next = position.pixels + 2;
      if (next >= max) {
        try {
          _bannerScrollController.jumpTo(0);
        } catch (_) {}
      } else {
        try {
          await _bannerScrollController.animateTo(
            next,
            duration: const Duration(milliseconds: 8),
            curve: Curves.linear,
          );
        } catch (_) {}
      }
    });
  }

  Widget _buildTopBanner() {
    const messageOne = 'Orders above ₹1000 (Prepaid) qualify for Free Standard Shipping.';
    const messageTwo = 'Order above 1500 and get a Free Channa Masala';
    const separator = '     •     ';
    final marqueeText = '$messageOne$separator$messageTwo$separator';
    final repeated = List.generate(6, (_) => marqueeText).join('');

    return Container(
      height: 20,
      color: Colors.red.shade600,
      child: ClipRect(
        child: IgnorePointer(
          ignoring: true, // Make banner non-interactive/non-scrollable by user
          child: ListView(
            controller: _bannerScrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            primary: false,
            shrinkWrap: true,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    repeated,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      if (widget.onSearch != null) {
        // Use custom onSearch callback if provided
        widget.onSearch!(query);
      } else {
        // Default behavior: navigate to search screen with query
        Navigator.pushNamed(
          context,
          '/search',
          arguments: {'query': query}, // Pass query instead of category
        );
      }
    }
  }

  void _handleTap() {
    // When the search field is tapped, navigate to search screen
    // This allows users to tap on the search field to go to the search screen
    Navigator.pushNamed(context, '/search');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopBanner(),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _handleTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onSubmitted: (_) => _handleSearch(),
              onTap: () {
                // Remove the GestureDetector behavior when TextField is actually tapped
              },
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: GestureDetector(
                  onTap: _handleSearch,
                  child: Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.arrow_forward,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        onPressed: _handleSearch,
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              onChanged: (value) {
                setState(() {}); // Rebuild to show/hide clear button
              },
            ),
          ),
        ),
      ],
    );
  }
}