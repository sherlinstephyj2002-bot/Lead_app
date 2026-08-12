import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/lead_model.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsState = ref.watch(leadsProvider);
    final ordersState = ref.watch(ordersProvider);
    final tasksState = ref.watch(tasksProvider);
    final expensesState = ref.watch(expensesProvider);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats row
            const Text(
              'Performance Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            _buildKpiGrid(ref),

            const SizedBox(height: 28),

            // Revenue Bar Chart
            ordersState.when(
              data: (orders) {
                if (orders.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue by Project Status',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    _buildRevenueBarChart(orders, theme),
                    const SizedBox(height: 28),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),

            // Lead Conversion Pie Chart
            leadsState.when(
              data: (leads) {
                if (leads.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lead Conversion Share',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    _buildLeadsPieChart(leads, theme),
                    const SizedBox(height: 28),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(WidgetRef ref) {
    int totalTasks = 0;
    int completedTasks = 0;
    ref.watch(tasksProvider).whenData((list) {
      totalTasks = list.length;
      completedTasks = list.where((t) => t.status == 'Completed').length;
    });

    double totalExpensesAmount = 0.0;
    ref.watch(expensesProvider).whenData((list) {
      totalExpensesAmount = list.where((e) => e.status == 'Approved').fold(0.0, (sum, item) => sum + item.amount);
    });

    final taskRate = totalTasks > 0 ? ((completedTasks / totalTasks) * 100).toStringAsFixed(0) : '0';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKpiCard('Task Success', '$taskRate%', 'Completed: $completedTasks/$totalTasks', Colors.green),
        _buildKpiCard('Paid Expenses', '₹${totalExpensesAmount.toStringAsFixed(0)}', 'Approved claims', Colors.red),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, Color color) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsPieChart(List<LeadModel> leads, ThemeData theme) {
    final newLeads = leads.where((l) => l.status == 'New').length;
    final contacted = leads.where((l) => l.status == 'Contacted' || l.status == 'Follow Up').length;
    final converted = leads.where((l) => l.status == 'Converted').length;
    final total = leads.length;

    if (total == 0) return const SizedBox();

    final newPct = (newLeads / total) * 100;
    final contactedPct = (contacted / total) * 100;
    final convertedPct = (converted / total) * 100;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(value: newPct, color: Colors.blue.shade500, title: '${newPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(value: contactedPct, color: Colors.orange.shade500, title: '${contactedPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(value: convertedPct, color: Colors.green.shade500, title: '${convertedPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendRow('New Leads ($newLeads)', Colors.blue.shade500),
                  const SizedBox(height: 8),
                  _buildLegendRow('Contacted / Follow Up ($contacted)', Colors.orange.shade500),
                  const SizedBox(height: 8),
                  _buildLegendRow('Converted Leads ($converted)', Colors.green.shade500),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBarChart(List<OrderModel> orders, ThemeData theme) {
    final confirmedAmt = orders.where((o) => o.status == 'Confirmed').fold(0.0, (sum, o) => sum + o.amount);
    final progressAmt = orders.where((o) => o.status == 'In Progress' || o.status == 'Material Ordered' || o.status == 'Installation').fold(0.0, (sum, o) => sum + o.amount);
    final completedAmt = orders.where((o) => o.status == 'Completed' || o.status == 'Closed').fold(0.0, (sum, o) => sum + o.amount);

    final maxVal = [confirmedAmt, progressAmt, completedAmt].fold(10000.0, (max, val) => val > max ? val : max);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0, bottom: 16.0),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.1,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      switch (val.toInt()) {
                        case 0:
                          return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Confirmed', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))));
                        case 1:
                          return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Active', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))));
                        case 2:
                          return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Completed', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))));
                        default:
                          return const SizedBox();
                      }
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [BarChartRodData(toY: confirmedAmt, color: Colors.purple.shade500, width: 22, borderRadius: BorderRadius.circular(4))],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [BarChartRodData(toY: progressAmt, color: Colors.blue.shade500, width: 22, borderRadius: BorderRadius.circular(4))],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [BarChartRodData(toY: completedAmt, color: Colors.green.shade500, width: 22, borderRadius: BorderRadius.circular(4))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendRow(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }
}
