import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/company_model.dart';
import '../../../shared/models/payment_history_model.dart';
import '../../../shared/services/subscription_service.dart';
import '../../../constants/user_roles.dart';

// Live stream of payment history for a company
final paymentHistoryProvider = StreamProvider.autoDispose.family<List<PaymentHistoryModel>, String>((ref, companyId) {
  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('payments')
      .orderBy('paidDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => PaymentHistoryModel.fromMap(doc.data())).toList());
});

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isProcessing = false;

  void _upgradePlan(BuildContext context, CompanyModel company, String targetPlanName) async {
    final isPaidTarget = targetPlanName.toLowerCase() == 'paid';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Switch Plan to $targetPlanName'),
        content: Text(
          isPaidTarget
              ? 'Upgrade to the Paid Plan? You will be charged USD 0.50 per active employee each month, allowing you to add more than 5 active employees and removing Google Ads.'
              : 'Switch to the Free Plan? Up to 5 active employees are allowed, and Google Ads will be enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isProcessing = true);
              try {
                await SubscriptionService.updatePlan(company.companyId, targetPlanName);
                await ref.read(companyProvider.notifier).loadCompany();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully switched to the $targetPlanName Plan.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating plan: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                setState(() => _isProcessing = false);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _simulatePayNow(BuildContext context, CompanyModel company) {
    if (company.monthlyBill <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outstanding balance to pay for this billing month.'), backgroundColor: Colors.blue),
      );
      return;
    }

    final billingMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isPaying = false;
        return StatefulBuilder(
          builder: (stCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B4CF0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.payment_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Secure Payment Simulation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('Billing Month: $billingMonth', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Total Amount: \$${company.monthlyBill.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  const Text('Card Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: '4242 4242 4242 4242',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '12/29',
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Expiry'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: '***',
                          readOnly: true,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'CVC'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This is a secure billing sandbox simulation. No actual funds will be transferred.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isPaying ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
                  onPressed: isPaying ? null : () async {
                    setModalState(() => isPaying = true);
                    
                    await Future.delayed(const Duration(seconds: 2));

                    try {
                      await SubscriptionService.simulatePayment(
                        companyId: company.companyId,
                        amount: company.monthlyBill,
                        billingMonth: billingMonth,
                      );
                      await ref.read(companyProvider.notifier).loadCompany();
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment Successful! Thank you.'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isPaying
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Pay \$${company.monthlyBill.toStringAsFixed(2)} Now'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(companyProvider);
    final currentUser = ref.watch(authProvider).user;
    final isAdmin = currentUser?.role == UserRoles.companyAdmin;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final formatCurrency = NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 2);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Subscription & Billing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0))),
        backgroundColor: cardBg,
        foregroundColor: titleColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: Stack(
        children: [
          companyState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading billing: $err')),
            data: (company) {
              if (company == null) {
                return const Center(child: Text('No active subscription found.', style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B))));
              }

              final paymentsAsync = ref.watch(paymentHistoryProvider(company.companyId));
              final isPaid = company.isPaidPlan;
              final capacityPercentage = isPaid ? 1.0 : (company.activeEmployees / 5).clamp(0.0, 1.0);
              final adsText = company.showAds ? 'ENABLED' : 'DISABLED (AD-FREE)';

              final mainContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overview Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 1 ? 4 : 2.4,
                        children: [
                          _buildOverviewCard('Current Plan', isPaid ? 'PAID PLAN' : 'FREE PLAN', Icons.verified_rounded, const Color(0xFF5B4CF0)),
                          _buildOverviewCard(
                            'Active Employees',
                            isPaid ? '${company.activeEmployees} Active' : '${company.activeEmployees} / 5 Active',
                            Icons.people_outline_rounded,
                            const Color(0xFF007834),
                          ),
                          _buildOverviewCard('Monthly Cost', '\$${company.monthlyBill.toStringAsFixed(2)} USD', Icons.attach_money_rounded, const Color(0xFF5B4CF0)),
                          _buildOverviewCard('Google Ads', adsText, Icons.ads_click_rounded, isPaid ? const Color(0xFF64748B) : const Color(0xFFEAB308), useBadge: true),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCurrentPlanDetailsCard(company, formatCurrency, isAdmin),
                              const SizedBox(height: 24),
                              _buildBillingHistoryCard(paymentsAsync, formatCurrency),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildUsageAnalyticsCard(company, capacityPercentage),
                              const SizedBox(height: 24),
                              _buildPaymentMethodsCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCurrentPlanDetailsCard(company, formatCurrency, isAdmin),
                        const SizedBox(height: 24),
                        _buildUsageAnalyticsCard(company, capacityPercentage),
                        const SizedBox(height: 24),
                        _buildPaymentMethodsCard(),
                        const SizedBox(height: 24),
                        _buildBillingHistoryCard(paymentsAsync, formatCurrency),
                      ],
                    ),
                  const SizedBox(height: 32),

                  // Available Subscription Plans Header
                  Text(
                    'Available Subscription Plans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a subscription plan according to your team size.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Plans pricing comparison: Free vs Paid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final planCols = constraints.maxWidth > 700 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: planCols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: planCols == 1 ? 1.6 : 1.1,
                        children: [
                          _buildPlanTierCard(
                            title: 'Free Plan',
                            employeesText: 'Up to 5 Active Employees',
                            priceText: '\$0.00 / month',
                            description: 'Includes up to 5 active employees with Google Ads enabled. Maximum limit enforced.',
                            isActive: !isPaid,
                            isAdmin: isAdmin,
                            buttonLabel: !isPaid ? 'Current Plan' : 'Downgrade to Free',
                            onSelect: () => _upgradePlan(context, company, 'Free'),
                          ),
                          _buildPlanTierCard(
                            title: 'Paid Plan',
                            employeesText: 'More than 5 Active Employees',
                            priceText: '\$0.50 per active employee / month',
                            description: 'Allows unlimited active employees at USD 0.50 / active employee. Completely ad-free experience.',
                            isActive: isPaid,
                            isAdmin: isAdmin,
                            buttonLabel: isPaid ? 'Current Plan' : 'Upgrade to Paid Plan',
                            onSelect: () => _upgradePlan(context, company, 'Paid'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                ],
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: mainContent,
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF5B4CF0))),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String label, String value, IconData icon, Color color, {bool useBadge = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (useBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanDetailsCard(CompanyModel company, NumberFormat formatCurrency, bool isAdmin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final isPaid = company.isPaidPlan;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT PLAN DETAILS', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    isPaid ? 'PAID PLAN' : 'FREE PLAN',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor),
                  ),
                ],
              ),
              if (isAdmin && isPaid && company.monthlyBill > 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text('Pay Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _simulatePayNow(context, company),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: dividerCol),
          const SizedBox(height: 16),
          _buildMetricRow('Active Employees', '${company.activeEmployees} active'),
          _buildMetricRow('Pricing Unit', isPaid ? '\$0.50 / active employee / month' : '\$0.00 (Free)'),
          _buildMetricRow('Free Employee Limit', isPaid ? 'Unlimited (Paid)' : '5 Active Employees'),
          _buildMetricRow('Google Ads Integration', company.showAds ? 'Enabled' : 'Disabled (Ad-Free)'),
          const SizedBox(height: 12),
          Divider(color: dividerCol),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESTIMATED MONTHLY COST', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                formatCurrency.format(company.monthlyBill),
                style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subtitleColor, fontSize: 13)),
          Text(value, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildUsageAnalyticsCard(CompanyModel company, double capacityPercentage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final isPaid = company.isPaidPlan;

    final subtitle = isPaid
        ? '${company.activeEmployees} active employees (Unlimited)'
        : '${(capacityPercentage * 100).toStringAsFixed(0)}% used (${company.activeEmployees} active / 5 limit)';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('USAGE ANALYTICS', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildUsageIndicator('Active Employees Capacity', capacityPercentage, subtitle),
        ],
      ),
    );
  }

  Widget _buildUsageIndicator(String label, double value, String suffix) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgCol = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(suffix, style: TextStyle(color: subtitleColor, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: bgCol,
            valueColor: AlwaysStoppedAnimation<Color>(value >= 1.0 ? const Color(0xFFBA1A1A) : const Color(0xFF5B4CF0)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final innerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SAVED PAYMENT METHODS', style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_off_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No payment methods saved.',
                    style: TextStyle(fontSize: 13, color: subtitleColor, fontFamily: 'Inter'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingHistoryCard(AsyncValue<List<PaymentHistoryModel>> paymentsAsync, NumberFormat formatCurrency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'BILLING HISTORY LOG',
              style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(color: dividerCol, height: 1),
          paymentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error loading history: $err'),
            ),
            data: (payments) {
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.history_rounded, size: 40, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text('No payment records found.', style: TextStyle(color: subtitleColor, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (_, __) => Divider(color: dividerCol, height: 1),
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(p.paidDate);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF007834), size: 18),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('\$${p.amount.toStringAsFixed(2)} USD — ${p.billingMonth}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                        Text('Paid', style: TextStyle(color: isDark ? const Color(0xFF34D399) : const Color(0xFF007834), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Transaction Date: $formattedDate', style: TextStyle(fontSize: 11, color: subtitleColor)),
                        const SizedBox(height: 2),
                        Text('Reference: ${p.transactionReference}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTierCard({
    required String title,
    required String employeesText,
    required String priceText,
    required String description,
    required bool isActive,
    required bool isAdmin,
    required String buttonLabel,
    required VoidCallback onSelect,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isActive
        ? const Color(0xFF5B4CF0)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderCol,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor)),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CURRENT PLAN', style: TextStyle(color: Color(0xFF5B4CF0), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(employeesText, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontSize: 13)),
          const SizedBox(height: 4),
          Text(priceText, style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4),
          ),
          const Spacer(),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: isActive ? null : onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? const Color(0xFFE2E8F0) : const Color(0xFF5B4CF0),
                  foregroundColor: isActive ? const Color(0xFF64748B) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
