import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/order_model.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  String _selectedFilterChip = 'All Orders';
  final List<String> _filterChips = ['All Orders', 'Confirmed', 'In Progress', 'Ready', 'Delivered', 'Closed', 'Cancelled'];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(ordersProvider.notifier).loadOrders(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      final notifier = ref.read(ordersProvider.notifier);
      if (notifier.hasMoreOrders) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    setState(() => _isLoadingMore = true);
    await ref.read(ordersProvider.notifier).loadMoreOrders();
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'in progress':
        return const Color(0xFFD97706);
      case 'ready':
        return const Color(0xFF7C3AED);
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
      case 'closed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final chipBgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    final permService = ref.watch(permissionServiceProvider);
    final canCreate = permService.hasPermission('order_create') || permService.hasPermission('order.create');

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                decoration: const InputDecoration(
                  hintText: 'Search orders by ID, customer, project...',
                  hintStyle: TextStyle(color: Colors.white70, fontFamily: 'Outfit'),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase());
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Orders Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  const SizedBox(height: 2),
                  Text('Track active project orders & engineer assignments', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontFamily: 'Outfit')),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'orderFab',
              onPressed: () => context.push('/order-form'),
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Order', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).loadOrders(reset: true),
        child: ordersState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading orders: $err', style: const TextStyle(color: Color(0xFFDC2626), fontFamily: 'Outfit')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.read(ordersProvider.notifier).loadOrders(reset: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (allOrders) {
            double totalRevenue = 0;
            int activeCount = 0;
            int completedCount = 0;

            for (final o in allOrders) {
              final status = o.status.toLowerCase();
              if (status != 'cancelled') {
                totalRevenue += o.amount;
              }
              if (status == 'in progress' || status == 'confirmed') {
                activeCount++;
              } else if (status == 'delivered' || status == 'ready' || status == 'completed') {
                completedCount++;
              }
            }

            final filteredOrders = allOrders.where((order) {
              final matchesSearch = order.orderId.toLowerCase().contains(_searchQuery) ||
                  order.customerName.toLowerCase().contains(_searchQuery) ||
                  order.projectName.toLowerCase().contains(_searchQuery) ||
                  order.assignedEngineer.toLowerCase().contains(_searchQuery);

              if (!matchesSearch) return false;

              if (_selectedFilterChip == 'All Orders') return true;
              return order.status.toLowerCase() == _selectedFilterChip.toLowerCase();
            }).toList();

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // TOP METRIC REVENUE CARDS
                SliverToBoxAdapter(
                  child: Container(
                    color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMetricCard(context, 'Total Revenue', _formatCurrency(totalRevenue), Icons.account_balance_wallet_outlined, const Color(0xFF16A34A)),
                          const SizedBox(width: 12),
                          _buildMetricCard(context, 'Total Orders', allOrders.length.toString(), Icons.shopping_bag_outlined, const Color(0xFF5B4CF0)),
                          const SizedBox(width: 12),
                          _buildMetricCard(context, 'Active Orders', activeCount.toString(), Icons.pending_actions_rounded, const Color(0xFFD97706)),
                          const SizedBox(width: 12),
                          _buildMetricCard(context, 'Completed', completedCount.toString(), Icons.task_alt_rounded, const Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ),

                // STATUS TAB FILTER BAR
                SliverToBoxAdapter(
                  child: Container(
                    color: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterChips.map((chip) {
                          final isSelected = _selectedFilterChip == chip;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(chip, style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : subtitleColor,
                              )),
                              selected: isSelected,
                              selectedColor: const Color(0xFF5B4CF0),
                              backgroundColor: chipBgColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (val) {
                                if (val) setState(() => _selectedFilterChip = chip);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // ORDERS LIST
                if (filteredOrders.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No orders found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: subtitleColor, fontFamily: 'Outfit')),
                          const SizedBox(height: 4),
                          Text('Tap + Create Order to add a new deal', style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == filteredOrders.length) {
                            return _isLoadingMore
                                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                                : const SizedBox.shrink();
                          }

                          final order = filteredOrders[index];
                          final initials = order.customerName.isNotEmpty
                              ? order.customerName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
                              : 'O';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(color: isDark ? Colors.black26 : const Color(0x05000000), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/order-detail/${order.orderId}', extra: order),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Order ID Badge & Status
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: chipBgColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(order.orderId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontFamily: 'Outfit')),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            order.status,
                                            style: TextStyle(color: _getStatusColor(order.status), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Customer & Project Info
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                                          child: Text(initials, style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(order.projectName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit')),
                                              Text(order.customerName, style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Outfit')),
                                            ],
                                          ),
                                        ),
                                        Text(_formatCurrency(order.amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontFamily: 'Outfit')),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: borderColor),
                                    const SizedBox(height: 10),

                                    // Engineer & Completion Date
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.engineering_outlined, size: 16, color: subtitleColor),
                                            const SizedBox(width: 4),
                                            Text(order.assignedEngineer, style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit')),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_month_outlined, size: 14, color: subtitleColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Due ${DateFormat('dd MMM yyyy').format(order.expectedCompletion)}',
                                              style: TextStyle(fontSize: 12, color: subtitleColor, fontFamily: 'Outfit'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filteredOrders.length + 1,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 135,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : const Color(0x04000000), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: accentColor),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor, fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}
