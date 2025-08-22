import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {
  final Function(String)? onSearch;
  final String? initialQuery;
  final String hintText;

  const SearchWidget({
    Key? key,
    this.onSearch,
    this.initialQuery,
    this.hintText = 'Search for fruits, vegetables...',
  }) : super(key: key);

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      if (widget.onSearch != null) {
        widget.onSearch!(query);
      } else {
        // Default behavior: navigate to search screen with query
        Navigator.pushNamed(
          context,
          '/search',
          arguments: {'query': query},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade600,
            size: 20,
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
                    color: Colors.green.shade700,
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
    );
  }
}