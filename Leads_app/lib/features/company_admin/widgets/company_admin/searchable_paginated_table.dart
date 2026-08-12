import 'package:flutter/material.dart';

class SearchablePaginatedTable<T> extends StatefulWidget {
  final List<T> items;
  final List<DataColumn> columns;
  final List<DataCell> Function(T item) rowBuilder;
  final bool Function(T item, String query) searchMatcher;
  final String searchPlaceholder;
  final int initialRowsPerPage;
  final Widget? emptyState;
  final Widget? headerAction;

  const SearchablePaginatedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    required this.searchMatcher,
    this.searchPlaceholder = 'Search...',
    this.initialRowsPerPage = 10,
    this.emptyState,
    this.headerAction,
  });

  @override
  State<SearchablePaginatedTable<T>> createState() => _SearchablePaginatedTableState<T>();
}

class _SearchablePaginatedTableState<T> extends State<SearchablePaginatedTable<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _rowsPerPage = widget.initialRowsPerPage;
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
        _currentPage = 0; // Reset to first page on search
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final headerRowColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFCF8FF);
    final searchFillColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withValues(alpha: 0.3);
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // 1. Filter items based on search query
    List<T> filteredItems = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return widget.searchMatcher(item, _searchQuery);
    }).toList();

    // 3. Paginate
    final totalItems = filteredItems.length;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) < totalItems
        ? (startIndex + _rowsPerPage)
        : totalItems;
    final paginatedItems = totalItems > 0
        ? filteredItems.sublist(startIndex, endIndex)
        : <T>[];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isHeightConstrained = constraints.maxHeight != double.infinity;

          Widget bodyWidget;
          if (totalItems == 0) {
            final emptyContent = widget.emptyState ??
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: subTextCol),
                      const SizedBox(height: 8),
                      Text(
                        'No records found',
                        style: TextStyle(color: subTextCol, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
            bodyWidget = isHeightConstrained ? Expanded(child: Center(child: emptyContent)) : emptyContent;
          } else {
            final tableWidget = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(headerRowColor),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  columns: widget.columns,
                  rows: paginatedItems.map((item) {
                    return DataRow(
                      cells: widget.rowBuilder(item),
                    );
                  }).toList(),
                ),
              ),
            );

            bodyWidget = isHeightConstrained
                ? Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: tableWidget,
                    ),
                  )
                : tableWidget;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: isHeightConstrained ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Table Header Toolbar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, toolbarConstraints) {
                    final isCompactToolbar = toolbarConstraints.maxWidth < 450;
                    final searchField = TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: textCol, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        hintText: widget.searchPlaceholder,
                        hintStyle: TextStyle(color: subTextCol, fontSize: 14, fontFamily: 'Inter'),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextCol, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: searchFillColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF422CD8), width: 1.5),
                        ),
                      ),
                    );

                    if (isCompactToolbar && widget.headerAction != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: 12),
                          widget.headerAction!,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchField),
                        if (widget.headerAction != null) ...[
                          const SizedBox(width: 12),
                          widget.headerAction!,
                        ],
                      ],
                    );
                  },
                ),
              ),

              // Divider
              Divider(height: 1, color: borderCol),

              // Table Content
              bodyWidget,

              // Divider
              Divider(height: 1, color: borderCol),

              // Table Footer / Pagination controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // Rows per page selector
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rows:', style: TextStyle(fontSize: 12, color: subTextCol, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          elevation: 2,
                          dropdownColor: cardBgColor,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          style: const TextStyle(color: Color(0xFF422CD8), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Inter'),
                          items: [5, 10, 20, 50].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _rowsPerPage = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    // Paging navigation
                    if (totalItems > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${startIndex + 1}-$endIndex of $totalItems',
                            style: TextStyle(fontSize: 12, color: subTextCol, fontFamily: 'Inter'),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded, size: 20, color: subTextCol),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right_rounded, size: 20, color: subTextCol),
                            onPressed: _currentPage < (totalPages - 1)
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
