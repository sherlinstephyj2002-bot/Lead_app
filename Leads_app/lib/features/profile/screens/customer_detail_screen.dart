import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/customer_model.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/providers/providers.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchCustomerDocuments(
    WidgetRef ref,
    String companyId,
    List<String> leadIds,
    List<String> orderIds,
  ) async {
    final firestore = ref.read(firestoreProvider);
    final List<Map<String, dynamic>> docs = [];

    if (leadIds.isNotEmpty) {
      final chunks = _chunkList(leadIds, 10);
      for (final chunk in chunks) {
        final leadSnaps = await firestore
            .collection('leadAttachments')
            .where('companyId', isEqualTo: companyId)
            .where('leadId', whereIn: chunk)
            .get();
        for (final doc in leadSnaps.docs) {
          docs.add({
            'id': doc.id,
            'name': doc.data()['fileName'] ?? 'Document',
            'url': doc.data()['fileUrl'] ?? '',
            'uploadedAt': (doc.data()['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'type': 'Lead',
            'refId': doc.data()['leadId'] ?? '',
          });
        }
      }
    }

    if (orderIds.isNotEmpty) {
      final chunks = _chunkList(orderIds, 10);
      for (final chunk in chunks) {
        final orderSnaps = await firestore
            .collection('orderAttachments')
            .where('companyId', isEqualTo: companyId)
            .where('orderId', whereIn: chunk)
            .get();
        for (final doc in orderSnaps.docs) {
          docs.add({
            'id': doc.id,
            'name': doc.data()['fileName'] ?? 'Document',
            'url': doc.data()['fileUrl'] ?? '',
            'uploadedAt': (doc.data()['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'type': 'Order',
            'refId': doc.data()['orderId'] ?? '',
          });
        }
      }
    }

    docs.sort((a, b) => (b['uploadedAt'] as DateTime).compareTo(a['uploadedAt'] as DateTime));
    return docs;
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final user = ref.watch(authProvider).user;

    final customer = widget.customer;
    final isActive = customer.status == 'Active';
    final initials = customer.name.isNotEmpty
        ? customer.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'C';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Profile Details
          Container(
            color: cardBg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  customer.status,
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFF047857) : const Color(0xFF475569),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.business_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'Joined ${DateFormat('MMM yyyy').format(customer.createdAt)}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                // Contact Details
                if (customer.email.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _sendEmail(customer.email),
                        child: Text(
                          customer.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _makeCall(customer.phone),
                      child: Text(
                        customer.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                if (customer.address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customer.address,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Tab bar selector
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Leads'),
                Tab(text: 'Orders'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Leads Tab
                leadsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (leads) {
                    final customerLeads = leads
                        .where((l) =>
                            (l.email?.toLowerCase() ?? '') == customer.email.toLowerCase() ||
                            l.mobileNumber.replaceAll(' ', '') == customer.phone.replaceAll(' ', ''))
                        .toList();

                    if (customerLeads.isEmpty) {
                      return _buildEmptyTab(Icons.person_search_rounded, 'No leads linked to this customer.');
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: customerLeads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final lead = customerLeads[index];
                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              lead.requirement.isNotEmpty ? lead.requirement : 'No Requirement Listed',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Added on ${DateFormat('dd MMM yyyy').format(lead.createdAt)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                if (lead.remarks != null && lead.remarks!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    lead.remarks!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ]
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getLeadStatusColor(lead.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lead.status,
                                style: TextStyle(
                                  color: _getLeadStatusColor(lead.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () => context.push('/lead-detail/${lead.leadId}', extra: lead),
                          ),
                        );
                      },
                    );
                  },
                ),
                // Orders Tab
                ordersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (orders) {
                    final customerOrders = orders
                        .where((o) =>
                            o.customerName.toLowerCase() == customer.name.toLowerCase())
                        .toList();

                    if (customerOrders.isEmpty) {
                      return _buildEmptyTab(Icons.receipt_long_rounded, 'No orders placed by this customer.');
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: customerOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final order = customerOrders[index];
                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              order.projectName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Amount: ${NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(order.amount)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Delivery Expected: ${DateFormat('dd MMM yyyy').format(order.expectedCompletion)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getOrderStatusColor(order.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(
                                  color: _getOrderStatusColor(order.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () => context.push('/order-detail/${order.orderId}', extra: order),
                          ),
                        );
                      },
                    );
                  },
                ),
                // Documents Tab
                leadsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (leads) {
                    final customerLeads = leads
                        .where((l) =>
                            (l.email?.toLowerCase() ?? '') == customer.email.toLowerCase() ||
                            l.mobileNumber.replaceAll(' ', '') == customer.phone.replaceAll(' ', ''))
                        .toList();
                    final leadIds = customerLeads.map((l) => l.leadId).toList();

                    return ordersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (orders) {
                        final customerOrders = orders
                            .where((o) =>
                                o.customerName.toLowerCase() == customer.name.toLowerCase())
                            .toList();
                        final orderIds = customerOrders.map((o) => o.orderId).toList();

                        if (leadIds.isEmpty && orderIds.isEmpty) {
                          return _buildEmptyTab(Icons.folder_open_rounded, 'No files found.');
                        }

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchCustomerDocuments(ref, user?.companyId ?? '', leadIds, orderIds),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text('Error loading documents: ${snapshot.error}'));
                            }

                            final docs = snapshot.data ?? [];
                            if (docs.isEmpty) {
                              return _buildEmptyTab(Icons.folder_open_rounded, 'No documents uploaded for this client.');
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                return Card(
                                  elevation: 0,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFEEF2F6),
                                      child: Icon(
                                        doc['name'].toString().toLowerCase().endsWith('.pdf')
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.image_rounded,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    title: Text(
                                      doc['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Linked to ${doc['type']}: ${doc['refId']}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                      onPressed: () async {
                                        final url = doc['url'];
                                        if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url));
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getLeadStatusColor(String status) {
    switch (status) {
      case 'New':
        return const Color(0xFF3B82F6);
      case 'Follow Up':
        return const Color(0xFFF59E0B);
      case 'Quotation Sent':
        return const Color(0xFF8B5CF6);
      case 'Converted':
        return const Color(0xFF10B981);
      case 'Closed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return const Color(0xFF3B82F6);
      case 'Material Ordered':
        return const Color(0xFFF59E0B);
      case 'Installation':
        return const Color(0xFF8B5CF6);
      case 'Completed':
        return const Color(0xFF10B981);
      case 'Closed':
        return const Color(0xFF64748B);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildEmptyTab(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
