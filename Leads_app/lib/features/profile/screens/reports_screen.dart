import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/pdf_service.dart';
import '../../../shared/services/file_download_service.dart';
import '../../../shared/utils/csv_export_helper.dart';
import '../../../shared/utils/app_formatter.dart';
import '../../../shared/theme/app_responsive.dart';
import '../../../constants/user_roles.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ReportsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final company = ref.watch(companyProvider).value;
    final isLeadEnabled = company?.isLeadManagementEnabled ?? true;
    final showLeads = isLeadEnabled && UserRoles.canAccessLeads(user?.role);

    final tabs = [
      if (showLeads) const Tab(icon: Icon(Icons.people_outline_rounded, size: 18), text: 'Leads'),
      const Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Orders'),
      const Tab(icon: Icon(Icons.fingerprint_rounded, size: 18), text: 'Attendance'),
      const Tab(icon: Icon(Icons.ring_volume_rounded, size: 18), text: 'Follow-ups'),
    ];

    final children = [
      if (showLeads) const _LeadsReportTab(),
      const _OrdersReportTab(),
      const _AttendanceReportTab(),
      const _FollowupsReportTab(),
    ];

    int initialIndex = widget.initialTab;
    if (!showLeads) {
      if (initialIndex == 0) initialIndex = 0; // Orders
      else if (initialIndex > 0) initialIndex = (initialIndex - 1).clamp(0, children.length - 1);
    } else {
      initialIndex = initialIndex.clamp(0, children.length - 1);
    }

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF5B4CF0),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white, fontFamily: 'Outfit')),
              SizedBox(height: 2),
              Text('Comprehensive business & workforce analytics', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: children,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LEADS REPORT TAB
// ─────────────────────────────────────────────
class _LeadsReportTab extends ConsumerWidget {
  const _LeadsReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leadsAsync = ref.watch(leadsProvider);

    return leadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading leads: $e')),
      data: (leads) {
        if (leads.isEmpty) {
          return _EmptyState(
            icon: Icons.person_search_rounded,
            label: 'No leads data yet.',
            subtitle: 'Your lead pipeline is currently empty. Add leads or import customer contacts to generate Zoho-style CRM analytics.',
            actionLabel: 'Add First Lead',
            onAction: () {},
          );
        }

        final totalLeads = leads.length;
        final statusCounts = <String, int>{};
        for (final l in leads) {
          statusCounts[l.status] = (statusCounts[l.status] ?? 0) + 1;
        }

        final followUpCount = statusCounts['Follow Up'] ?? statusCounts['Follow-Up'] ?? 0;
        final newCount = statusCounts['New'] ?? 0;
        final wonCount = statusCounts['Won'] ?? statusCounts['Converted'] ?? 0;
        final activePipeline = totalLeads - wonCount;
        final conversionRate = totalLeads > 0 ? (wonCount / totalLeads * 100) : 50.0;

        // Leads per month (last 6 months)
        final now = DateTime.now();
        final monthData = List.generate(6, (i) {
          final month = DateTime(now.year, now.month - (5 - i));
          final count = leads
              .where((l) => l.createdAt.year == month.year && l.createdAt.month == month.month)
              .length;
          return _MonthCount(DateFormat('MMM').format(month), count.toDouble());
        });

        final maxVal = monthData.map((m) => m.count).reduce((a, b) => a > b ? a : b);
        final chartMaxY = (maxVal == 0 ? 5 : maxVal * 1.3).toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 600;

                  final titleColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lead Analytics & Funnel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit')),
                      const SizedBox(height: 4),
                      Text('Real-time pipeline performance, conversion rates & channel breakdown', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  );

                  final actionButtons = Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _exportLeadsCsv(context, leads),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final bytes = await PdfService.generateLeadsReportPdf(leads);
                            await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Leads_Report.pdf');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Leads_Report.pdf downloaded to your Downloads folder.'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4CF0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleColumn,
                        const SizedBox(height: 14),
                        actionButtons,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleColumn),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _exportLeadsCsv(context, leads),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final bytes = await PdfService.generateLeadsReportPdf(leads);
                              await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Leads_Report.pdf');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Leads_Report.pdf downloaded to your Downloads folder.'),
                                  backgroundColor: Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: const Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B4CF0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // 4 Zoho Style KPI Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final isMedium = constraints.maxWidth > 600;
                  final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (isMedium ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildZohoKpiCard(context, 'TOTAL LEADS', totalLeads.toString(), '+12.5% vs last month', Icons.groups_rounded, const Color(0xFF5B4CF0), cardWidth),
                      _buildZohoKpiCard(context, 'ACTIVE PIPELINE', activePipeline.toString(), '$followUpCount in follow-up', Icons.filter_alt_rounded, const Color(0xFF0EA5E9), cardWidth),
                      _buildZohoKpiCard(context, 'CONVERSION RATE', '${conversionRate.toStringAsFixed(1)}%', 'Target: >45%', Icons.trending_up_rounded, const Color(0xFF10B981), cardWidth),
                      _buildZohoKpiCard(context, 'NEW INQUIRIES', newCount.toString(), 'Captured this month', Icons.fiber_new_rounded, const Color(0xFFF59E0B), cardWidth),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Zoho Lead Conversion Stage Funnel Container
              _buildZohoPipelineFunnelCard(context, totalLeads, newCount, followUpCount, wonCount),
              const SizedBox(height: 28),

              // Responsive Dual Charts Grid (Monthly Trend & Donut Breakdown)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildAcquisitionTrendChart(context, monthData, chartMaxY)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildZohoStatusDonutChart(context, statusCounts, totalLeads)),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _buildAcquisitionTrendChart(context, monthData, chartMaxY),
                      const SizedBox(height: 20),
                      _buildZohoStatusDonutChart(context, statusCounts, totalLeads),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Lead Pipeline Stream & Table Container
              _buildZohoLeadStreamTable(context, leads),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZohoKpiCard(BuildContext context, String label, String value, String subtext, IconData icon, Color color, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: AppResponsive.fontSize(context, 24, mobileSize: 18),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildZohoPipelineFunnelCard(BuildContext context, int total, int newLeads, int followUp, int won) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newPct = total > 0 ? (newLeads / total) : 0.5;
    final followPct = total > 0 ? (followUp / total) : 0.5;
    final wonPct = total > 0 ? (won / total) : 0.2;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_rounded, color: Color(0xFF5B4CF0), size: 20),
              const SizedBox(width: 10),
              Text('Stage Conversion Funnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 6),
          Text('Track customer journey progression from initial inquiry to closed deals.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 20),
          _buildFunnelStageBar(context, '1. New Inquiries', newLeads, newPct, const Color(0xFF3B82F6)),
          const SizedBox(height: 14),
          _buildFunnelStageBar(context, '2. In Discussion / Follow Up', followUp, followPct, const Color(0xFF5B4CF0)),
          const SizedBox(height: 14),
          _buildFunnelStageBar(context, '3. Closed - Converted Deals', won, wonPct, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildFunnelStageBar(BuildContext context, String stageName, int count, double percentage, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(stageName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF334155))),
            Text('$count leads (${(percentage * 100).toStringAsFixed(0)}%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage == 0 ? 0.05 : percentage,
            minHeight: 10,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAcquisitionTrendChart(BuildContext context, List<_MonthCount> monthData, double maxY) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lead Acquisition Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Monthly lead volume across the last 6 months', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (val != idx.toDouble()) return const SizedBox.shrink();
                        if (idx < 0 || idx >= monthData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(monthData[idx].month, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: monthData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.count,
                        color: const Color(0xFF5B4CF0),
                        width: 22,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZohoStatusDonutChart(BuildContext context, Map<String, int> statusCounts, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lead Status Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Percentage distribution across active lead categories', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: _buildPieSections(statusCounts, total),
                          sectionsSpace: 3,
                          centerSpaceRadius: 46,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(total.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit')),
                          Text('Total', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildPieLegend(statusCounts),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZohoLeadStreamTable(BuildContext context, List<LeadModel> leads) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Lead Stream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              Text('Showing active CRM leads', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: leads.take(5).map((l) {
              Color statusColor = const Color(0xFF5B4CF0);
              if (l.status == 'New') statusColor = const Color(0xFF10B981);
              if (l.status == 'Contacted') statusColor = const Color(0xFF0EA5E9);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Text(l.customerName.isNotEmpty ? l.customerName[0].toUpperCase() : 'L', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          Text('${l.companyName} • ${l.leadSource}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l.status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> counts, int total) {
    final colors = [
      const Color(0xFF5B4CF0),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    final entries = counts.entries.toList();
    return entries.asMap().entries.map((e) {
      final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
      return PieChartSectionData(
        color: colors[e.key % colors.length],
        value: e.value.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<Widget> _buildPieLegend(Map<String, int> counts) {
    final colors = [
      const Color(0xFF5B4CF0),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return counts.entries.toList().asMap().entries.map((e) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${e.value.key} (${e.value.value})', style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _exportLeadsCsv(BuildContext context, List<LeadModel> leads) async {
    final rows = <List<dynamic>>[
      ['Lead ID', 'Customer', 'Company', 'Mobile', 'Email', 'Location', 'Status', 'Source', 'Assigned To', 'Created At'],
      ...leads.map((l) => [
            CsvExportHelper.formatId(l.leadId),
            CsvExportHelper.sanitizeText(l.customerName),
            CsvExportHelper.sanitizeText(l.companyName),
            CsvExportHelper.formatPhone(l.mobileNumber),
            l.email ?? '',
            CsvExportHelper.sanitizeText(l.location),
            CsvExportHelper.sanitizeText(l.status),
            CsvExportHelper.sanitizeText(l.leadSource),
            CsvExportHelper.sanitizeText(l.assignedTo),
            CsvExportHelper.formatDateTime(l.createdAt),
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileDownloadService.downloadCsv(csvContent: csv, fileName: 'Leads_Report.csv');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leads_Report.csv downloaded to your Downloads folder.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ORDERS REPORT TAB
// ─────────────────────────────────────────────
class _OrdersReportTab extends ConsumerWidget {
  const _OrdersReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final fmt = NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return _EmptyState(
            icon: Icons.receipt_long_rounded,
            label: 'No orders data yet.',
            subtitle: 'Your enterprise orders registry is currently empty. Once transactions begin flowing through the system, detailed analytics will appear here.',
            actionLabel: 'Create Order',
            onAction: () => context.push('/order-form'),
          );
        }

        final totalRevenue = orders.where((o) => o.status != 'Cancelled').fold(0.0, (s, o) => s + o.amount);
        final statusCounts = <String, int>{};
        for (final o in orders) {
          statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
        }

        // Revenue per month (last 6 months)
        final now = DateTime.now();
        final monthRevenue = List.generate(6, (i) {
          final month = DateTime(now.year, now.month - (5 - i));
          final rev = orders
              .where((o) => o.createdAt.year == month.year && o.createdAt.month == month.month && o.status != 'Cancelled')
              .fold(0.0, (s, o) => s + o.amount);
          return _MonthCount(DateFormat('MMM').format(month), rev);
        });

        final maxY = monthRevenue.map((m) => m.count).reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Revenue', fmt.format(totalRevenue), 'Total Revenue'),
              const SizedBox(height: 16),
              _StatusBadgeRow(statusCounts),
              const SizedBox(height: 28),

              _ChartCard(
                title: 'Revenue Trend — Last 6 Months',
                child: SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (val != idx.toDouble()) return const SizedBox.shrink();
                              if (idx < 0 || idx >= monthRevenue.length) return const SizedBox.shrink();
                              return Text(monthRevenue[idx].month, style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      minX: 0,
                      maxX: 5,
                      minY: 0,
                      maxY: maxY == 0 ? 1 : maxY * 1.2,
                      lineBarsData: [
                        LineChartBarData(
                          spots: monthRevenue.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.count)).toList(),
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Orders table
              _ChartCard(
                title: 'Recent Orders',
                child: Column(
                  children: orders.take(10).map((o) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(o.customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      subtitle: Text('${o.orderId} • ${o.status}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      trailing: Text(fmt.format(o.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Export Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportOrdersCsv(context, orders),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await PdfService.generateOrdersReportPdf(orders);
                        await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Orders_Report.pdf');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Orders_Report.pdf downloaded to your Downloads folder.'),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Export PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportOrdersCsv(BuildContext context, List<OrderModel> orders) async {
    final rows = <List<dynamic>>[
      ['Order ID', 'Lead ID', 'Customer Name', 'Project Name', 'Amount', 'Status', 'Expected Completion', 'Assigned Engineer', 'Created At'],
      ...orders.map((o) => [
            CsvExportHelper.formatId(o.orderId),
            CsvExportHelper.formatId(o.leadId ?? ''),
            CsvExportHelper.sanitizeText(o.customerName),
            CsvExportHelper.sanitizeText(o.projectName),
            o.amount,
            CsvExportHelper.sanitizeText(o.status),
            CsvExportHelper.formatDateOnly(o.expectedCompletion),
            CsvExportHelper.sanitizeText(o.assignedEngineer),
            CsvExportHelper.formatDateTime(o.createdAt),
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileDownloadService.downloadCsv(csvContent: csv, fileName: 'Orders_Report.csv');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Orders_Report.csv downloaded to your Downloads folder.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ATTENDANCE REPORT TAB
// ─────────────────────────────────────────────
class _AttendanceReportTab extends ConsumerStatefulWidget {
  const _AttendanceReportTab();

  @override
  ConsumerState<_AttendanceReportTab> createState() => _AttendanceReportTabState();
}

class _AttendanceReportTabState extends ConsumerState<_AttendanceReportTab> {
  String _searchQuery = '';
  String? _selectedEmployeeId;
  String? _selectedDepartment;
  String _selectedStatus = 'All';
  DateTimeRange? _selectedDateRange;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _calculateStatus(AttendanceModel log) {
    if (log.status.toLowerCase() == 'absent') {
      return 'Absent';
    }
    if (log.checkOutTime == null) {
      return 'Working';
    }
    final checkIn = log.checkInTime;
    final checkOut = log.checkOutTime!;
    final duration = checkOut.difference(checkIn);
    final hours = duration.inMinutes / 60.0;
    if (hours >= 8.0) {
      return 'Full Day';
    } else if (hours >= 4.0) {
      return 'Half Day';
    } else {
      return 'Short Hours';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Full Day':
        return const Color(0xFF10B981);
      case 'Half Day':
        return const Color(0xFFF59E0B);
      case 'Short Hours':
        return const Color(0xFFEF4444);
      case 'Working':
        return const Color(0xFF3B82F6);
      case 'Absent':
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getEmployeeDepartment(String employeeId, List<UserModel> employees) {
    final emp = employees.firstWhere(
      (e) => e.employeeId == employeeId || e.uid == employeeId,
      orElse: () => UserModel(uid: '', email: '', name: '', role: '', companyId: '', companyName: '', createdAt: DateTime.now()),
    );
    return emp.department ?? 'N/A';
  }

  String _getEmployeeIdDisplay(String employeeId, List<UserModel> employees) {
    if (employees.isEmpty) return 'Employee ID unavailable';
    final empMatches = employees.where((e) => e.employeeId == employeeId || e.uid == employeeId);
    if (empMatches.isNotEmpty) {
      return empMatches.first.displayEmployeeId;
    }
    return employeeId.isNotEmpty ? employeeId : 'Employee ID unavailable';
  }

  String _formatWorkingHours(AttendanceModel log) {
    if (log.checkOutTime == null) {
      final elapsed = DateTime.now().difference(log.checkInTime);
      final hrs = elapsed.inHours;
      final mins = elapsed.inMinutes % 60;
      return 'Working... (${hrs}h ${mins}m)';
    } else {
      final duration = log.checkOutTime!.difference(log.checkInTime);
      final hrs = duration.inHours;
      final mins = duration.inMinutes % 60;
      return '${hrs}h ${mins}m';
    }
  }

  String _formatOvertime(AttendanceModel log) {
    if (log.checkOutTime == null) return '--';
    final duration = log.checkOutTime!.difference(log.checkInTime);
    final hours = duration.inMinutes / 60.0;
    if (hours > 8.0) {
      final ot = hours - 8.0;
      final otHrs = ot.toInt();
      final otMins = ((ot - otHrs) * 60).round();
      return '${otHrs}h ${otMins}m';
    }
    return '0h 0m';
  }

  void _showAttendanceDetails(BuildContext context, AttendanceModel log, List<UserModel> employees) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dept = _getEmployeeDepartment(log.employeeId, employees);
    final empId = _getEmployeeIdDisplay(log.employeeId, employees);
    final status = _calculateStatus(log);
    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.employeeName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text('ID: $empId  •  $dept', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Text('Attendance Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 20),
            
            _buildTimelineItem(
              context: context,
              title: 'Check In',
              time: DateFormat('hh:mm a').format(log.checkInTime),
              subtitle: log.address ?? 'No GPS Verification Address available',
              icon: Icons.login_rounded,
              color: const Color(0xFF3B82F6),
              isGPSVerified: log.latitude != null,
              lat: log.latitude,
              lng: log.longitude,
            ),
            _buildTimelineItem(
              context: context,
              title: 'Break Out (Lunch)',
              time: '12:30 PM',
              subtitle: 'Scheduled Break (Standard Policy)',
              icon: Icons.restaurant_rounded,
              color: Colors.orange,
              isGPSVerified: false,
            ),
            _buildTimelineItem(
              context: context,
              title: 'Break In (Back)',
              time: '01:30 PM',
              subtitle: 'Scheduled Return (Standard Policy)',
              icon: Icons.work_outline_rounded,
              color: Colors.teal,
              isGPSVerified: false,
            ),
            _buildTimelineItem(
              context: context,
              title: 'Check Out',
              time: log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : 'Still working',
              subtitle: log.checkoutAddress ?? (log.checkOutTime == null ? 'Active session' : 'No GPS Verification Address available'),
              icon: Icons.logout_rounded,
              color: log.checkOutTime != null ? const Color(0xFF10B981) : Colors.grey,
              isGPSVerified: log.checkoutLatitude != null,
              lat: log.checkoutLatitude,
              lng: log.checkoutLongitude,
              isLast: true,
            ),
            const SizedBox(height: 24),
            Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Working Hours', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(_formatWorkingHours(log), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Calculated Overtime', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(_formatOvertime(log), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required String title,
    required String time,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isGPSVerified,
    double? lat,
    double? lng,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 45,
                color: isDark ? const Color(0xFF334155) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  Text(time, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              if (isGPSVerified && lat != null && lng != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    const Text('GPS Verified', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('($lat, $lng)', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildAttendanceKpiCard(BuildContext context, String title, String value, String subtitle, IconData icon, Color color, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceListOrTable(List<AttendanceModel> filteredLogs, List<UserModel> employees, bool isLargeScreen) {
    if (isLargeScreen) {
      return _buildAttendanceTable(filteredLogs, employees);
    } else {
      return _buildAttendanceCardList(filteredLogs, employees);
    }
  }

  Widget _buildAttendanceTable(List<AttendanceModel> filteredLogs, List<UserModel> employees) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFC)),
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
                columns: const [
                  DataColumn(label: Text('EMPLOYEE NAME')),
                  DataColumn(label: Text('EMPLOYEE ID')),
                  DataColumn(label: Text('DEPARTMENT')),
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('CHECK IN')),
                  DataColumn(label: Text('CHECK OUT')),
                  DataColumn(label: Text('WORKING HOURS')),
                  DataColumn(label: Text('OVERTIME')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: filteredLogs.map((log) {
                  final status = _calculateStatus(log);
                  Color statusColor = const Color(0xFF64748B);
                  Color statusBg = isDark ? const Color(0x2664748B) : const Color(0xFFF1F5F9);

                  if (status == 'Working' || status == 'Full Day') {
                    statusColor = const Color(0xFF0284C7);
                    statusBg = isDark ? const Color(0x260284C7) : const Color(0xFFE0F2FE);
                  } else if (status == 'Present') {
                    statusColor = const Color(0xFF10B981);
                    statusBg = isDark ? const Color(0x2610B981) : const Color(0xFFD1FAE5);
                  } else if (status == 'Late') {
                    statusColor = const Color(0xFFD97706);
                    statusBg = isDark ? const Color(0x26D97706) : const Color(0xFFFEF3C7);
                  } else if (status == 'Absent') {
                    statusColor = const Color(0xFF64748B);
                    statusBg = isDark ? const Color(0x2664748B) : const Color(0xFFF1F5F9);
                  }

                  final dept = _getEmployeeDepartment(log.employeeId, employees);
                  final empId = _getEmployeeIdDisplay(log.employeeId, employees);
                  final workingHoursStr = _formatWorkingHours(log);
                  final isWorking = log.checkOutTime == null;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                              child: Text(
                                log.employeeName.isNotEmpty ? log.employeeName[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(log.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      DataCell(Text(empId, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataCell(Text(dept, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd').format(log.checkInTime), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                            Text(DateFormat('MMM yyyy').format(log.checkInTime), style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      DataCell(Text(DateFormat('hh:mm a').format(log.checkInTime), style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B)))),
                      DataCell(Text(log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : '--', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                      DataCell(
                        Row(
                          children: [
                            if (isWorking)
                              Container(
                                width: 4,
                                height: 16,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)),
                              ),
                            Text(
                              workingHoursStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isWorking ? FontWeight.bold : FontWeight.normal,
                                color: isWorking ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(_formatOvertime(log), style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => _showAttendanceDetails(context, log, employees),
                          child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          // Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing 1 - ${filteredLogs.length} of ${filteredLogs.length} entries',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCardList(List<AttendanceModel> filteredLogs, List<UserModel> employees) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        final status = _calculateStatus(log);
        Color statusColor = const Color(0xFF64748B);
        Color statusBg = isDark ? const Color(0x2664748B) : const Color(0xFFF1F5F9);

        if (status == 'Working' || status == 'Full Day') {
          statusColor = const Color(0xFF0284C7);
          statusBg = isDark ? const Color(0x260284C7) : const Color(0xFFE0F2FE);
        } else if (status == 'Present') {
          statusColor = const Color(0xFF10B981);
          statusBg = isDark ? const Color(0x2610B981) : const Color(0xFFD1FAE5);
        } else if (status == 'Late') {
          statusColor = const Color(0xFFD97706);
          statusBg = isDark ? const Color(0x26D97706) : const Color(0xFFFEF3C7);
        }

        final dept = _getEmployeeDepartment(log.employeeId, employees);
        final empId = _getEmployeeIdDisplay(log.employeeId, employees);

        return Card(
          elevation: 0,
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                          child: Text(
                            log.employeeName.isNotEmpty ? log.employeeName[0].toUpperCase() : 'E',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(log.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('ID: $empId  •  $dept', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check In', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(DateFormat('hh:mm a').format(log.checkInTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check Out', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : '--', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Working Hours', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(_formatWorkingHours(log), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${DateFormat('dd MMM yyyy').format(log.checkInTime)}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    TextButton(
                      onPressed: () => _showAttendanceDetails(context, log, employees),
                      child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportAttendanceCsv(BuildContext context, List<AttendanceModel> logs, List<UserModel> employees) async {
    final rows = <List<dynamic>>[
      ['Employee Name', 'Employee ID', 'Department', 'Date', 'Check-In Time', 'Check-Out Time', 'Work Hours', 'Overtime', 'Status', 'In Address', 'Out Address'],
      ...logs.map((AttendanceModel log) {
        final dept = _getEmployeeDepartment(log.employeeId, employees);
        final empId = _getEmployeeIdDisplay(log.employeeId, employees);
        final status = _calculateStatus(log);
        final hoursStr = _formatWorkingHours(log);
        final otStr = _formatOvertime(log);
        return [
          CsvExportHelper.sanitizeText(log.employeeName),
          CsvExportHelper.formatId(empId),
          CsvExportHelper.sanitizeText(dept),
          CsvExportHelper.formatDateOnly(log.checkInTime),
          CsvExportHelper.formatTimeOnly(log.checkInTime),
          log.checkOutTime != null ? CsvExportHelper.formatTimeOnly(log.checkOutTime!) : 'Still Working',
          hoursStr,
          otStr,
          CsvExportHelper.sanitizeText(status),
          CsvExportHelper.sanitizeText(log.address ?? ''),
          CsvExportHelper.sanitizeText(log.checkoutAddress ?? ''),
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileDownloadService.downloadCsv(csvContent: csv, fileName: 'Attendance_Report.csv');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attendance_Report.csv downloaded to your Downloads folder.'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceAsync = ref.watch(companyAttendanceTodayProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final departmentsAsync = ref.watch(departmentsProvider);

    return attendanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading attendance: $e')),
      data: (logs) {
        return employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading employees: $e')),
          data: (employees) {
            return departmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading departments: $e')),
              data: (departments) {
                final filteredLogs = logs.where((AttendanceModel log) {
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    final nameMatch = log.employeeName.toLowerCase().contains(query);
                    final idMatch = log.employeeId.toLowerCase().contains(query);
                    if (!nameMatch && !idMatch) return false;
                  }

                  if (_selectedEmployeeId != null && _selectedEmployeeId != 'all') {
                    if (log.employeeId != _selectedEmployeeId) return false;
                  }

                  if (_selectedDepartment != null && _selectedDepartment != 'all') {
                    final empDept = _getEmployeeDepartment(log.employeeId, employees);
                    if (empDept != _selectedDepartment) return false;
                  }

                  if (_selectedStatus != 'All') {
                    final status = _calculateStatus(log);
                    if (status != _selectedStatus) return false;
                  }

                  if (_selectedDateRange != null) {
                    final checkIn = log.checkInTime;
                    if (checkIn.isBefore(_selectedDateRange!.start) || checkIn.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                final todayEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
                final todayLogs = logs.where((l) => l.checkInTime.isAfter(todayStart) && l.checkInTime.isBefore(todayEnd)).toList();

                final totalEmployeesCount = employees.length;
                final presentTodayCount = todayLogs.where((l) => _calculateStatus(l) != 'Absent').map((l) => l.employeeId).toSet().length;
                final absentTodayCount = totalEmployeesCount - presentTodayCount;
                final lateTodayCount = todayLogs.where((l) => l.status.toLowerCase() == 'late').length;

                final completedLogsToday = todayLogs.where((l) => l.checkOutTime != null).toList();
                double avgWorkingHoursToday = 0.0;
                if (completedLogsToday.isNotEmpty) {
                  final totalHours = completedLogsToday.fold(0.0, (sum, l) {
                    final diff = l.checkOutTime!.difference(l.checkInTime);
                    return sum + (diff.inMinutes / 60.0);
                  });
                  avgWorkingHoursToday = totalHours / completedLogsToday.length;
                }

                final totalOvertimeToday = todayLogs.fold(0.0, (sum, l) {
                  double ot = 0.0;
                  if (l.checkOutTime != null) {
                    final diff = l.checkOutTime!.difference(l.checkInTime);
                    final hours = diff.inMinutes / 60.0;
                    if (hours > 8.0) ot = hours - 8.0;
                  }
                  return sum + ot;
                });

                final isLargeScreen = MediaQuery.of(context).size.width > 768;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Executive Attendance Header Title
                      LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final isCompact = headerConstraints.maxWidth < 600;

                          final titleColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attendance & Shift Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit')),
                              const SizedBox(height: 4),
                              Text('Real-time workforce tracking, shift logs, and overtime compliance', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          );

                          final actionButtons = Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _exportAttendanceCsv(context, filteredLogs, employees),
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final company = ref.read(companyProvider).value;
                                    final filtersMap = <String, String>{
                                      'Employee': _selectedEmployeeId != null && _selectedEmployeeId != 'all'
                                          ? employees.firstWhere((e) => e.employeeId == _selectedEmployeeId, orElse: () => UserModel(uid: '', email: '', name: '', role: '', companyId: '', companyName: '', createdAt: DateTime.now())).name
                                          : 'All Employees',
                                      'Department': _selectedDepartment ?? 'All Departments',
                                      'Status': _selectedStatus,
                                    };
                                    final bytes = await PdfService.generateAttendanceReportPdf(
                                      filteredLogs,
                                      companyName: company?.name,
                                      filters: filtersMap,
                                    );
                                    await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Attendance_Report.pdf');
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Attendance_Report.pdf downloaded to your Downloads folder.'),
                                        backgroundColor: Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                  label: const Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B4CF0),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleColumn,
                                const SizedBox(height: 14),
                                actionButtons,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: titleColumn),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _exportAttendanceCsv(context, filteredLogs, employees),
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text('Export CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final company = ref.read(companyProvider).value;
                                      final filtersMap = <String, String>{
                                        'Employee': _selectedEmployeeId != null && _selectedEmployeeId != 'all'
                                            ? employees.firstWhere((e) => e.employeeId == _selectedEmployeeId, orElse: () => UserModel(uid: '', email: '', name: '', role: '', companyId: '', companyName: '', createdAt: DateTime.now())).name
                                            : 'All Employees',
                                        'Department': _selectedDepartment ?? 'All Departments',
                                        'Status': _selectedStatus,
                                      };
                                      final bytes = await PdfService.generateAttendanceReportPdf(
                                        filteredLogs,
                                        companyName: company?.name,
                                        filters: filtersMap,
                                      );
                                      await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Attendance_Report.pdf');
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Attendance_Report.pdf downloaded to your Downloads folder.'),
                                          backgroundColor: Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                    label: const Text('Export PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5B4CF0),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Responsive 4 Bento Stat Cards Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          final isMedium = constraints.maxWidth > 600;
                          final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (isMedium ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 16) / 2);

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildAttendanceKpiCard(context, 'WORKFORCE SIZE', '$totalEmployeesCount', 'Active company staff', Icons.people_outline_rounded, const Color(0xFF5B4CF0), cardWidth),
                              _buildAttendanceKpiCard(context, 'PRESENT TODAY', '$presentTodayCount', '${totalEmployeesCount > 0 ? (presentTodayCount / totalEmployeesCount * 100).toStringAsFixed(0) : 0}% turn-out rate', Icons.fingerprint_rounded, const Color(0xFF10B981), cardWidth),
                              _buildAttendanceKpiCard(context, 'ABSENT TODAY', '$absentTodayCount', '$lateTodayCount late arrivals today', Icons.person_off_outlined, const Color(0xFFEF4444), cardWidth),
                              _buildAttendanceKpiCard(context, 'AVG SHIFT HOURS', '${avgWorkingHoursToday.toStringAsFixed(1)}h', '${totalOvertimeToday.toStringAsFixed(1)}h overtime accumulated', Icons.hourglass_empty_rounded, const Color(0xFF0EA5E9), cardWidth),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Responsive Filter & Search Toolbar Container (100% Overflow Free)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Theme.of(context).cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FILTER & SEARCH RECORDS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  // Search Field
                                  SizedBox(
                                    width: 220,
                                    child: TextField(
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        hintText: 'Search employee name or ID...',
                                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      ),
                                      onChanged: (val) => setState(() => _searchQuery = val),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Employee Dropdown
                                  SizedBox(
                                    width: 170,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        labelText: 'Employee',
                                        labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      ),
                                      value: _selectedEmployeeId ?? 'all',
                                      items: [
                                        const DropdownMenuItem(value: 'all', child: Text('All Employees', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        ...employees.map((e) => DropdownMenuItem(value: e.employeeId, child: Text(e.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                                      ],
                                      onChanged: (val) => setState(() => _selectedEmployeeId = val == 'all' ? null : val),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Department Dropdown
                                  SizedBox(
                                    width: 170,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        labelText: 'Department',
                                        labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      ),
                                      value: _selectedDepartment ?? 'all',
                                      items: [
                                        const DropdownMenuItem(value: 'all', child: Text('All Departments', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        ...departments.map((d) => DropdownMenuItem(value: d.departmentName, child: Text(d.departmentName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                                      ],
                                      onChanged: (val) => setState(() => _selectedDepartment = val == 'all' ? null : val),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Status Dropdown
                                  SizedBox(
                                    width: 150,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        labelText: 'Status',
                                        labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      ),
                                      value: _selectedStatus,
                                      items: const [
                                        DropdownMenuItem(value: 'All', child: Text('All Statuses', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Working', child: Text('Working', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Full Day', child: Text('Full Day', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Half Day', child: Text('Half Day', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Absent', child: Text('Absent', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) => setState(() => _selectedStatus = val ?? 'All'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Date Range Picker Button
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                        lastDate: DateTime.now().add(const Duration(days: 1)),
                                        initialDateRange: _selectedDateRange,
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedDateRange = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.calendar_today_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedDateRange == null
                                                ? 'All Dates'
                                                : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                          ),
                                          if (_selectedDateRange != null) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => setState(() => _selectedDateRange = null),
                                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Attendance Data Table or Mobile Card List
                      if (filteredLogs.isEmpty)
                        const _EmptyState(
                          icon: Icons.fingerprint_rounded,
                          label: 'No attendance logs found.',
                          subtitle: 'No records match the applied employee, department, or date range filters.',
                        )
                      else
                        _buildAttendanceListOrTable(filteredLogs, employees, isLargeScreen),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}



// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────
class _MonthCount {
  final String month;
  final double count;
  const _MonthCount(this.month, this.count);
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.label,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 52, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 380,
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13, height: 1.5),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4CF0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  const _SectionHeader(this.title, this.value, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

class _StatusBadgeRow extends StatelessWidget {
  final Map<String, int> counts;
  const _StatusBadgeRow(this.counts);

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF5B4CF0),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: counts.entries.toList().asMap().entries.map((e) {
        final color = colors[e.key % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${e.value.key}  ${e.value.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FOLLOW-UPS REPORT TAB
// ─────────────────────────────────────────────
class _FollowupsReportTab extends ConsumerStatefulWidget {
  const _FollowupsReportTab();

  @override
  ConsumerState<_FollowupsReportTab> createState() => _FollowupsReportTabState();
}

class _FollowupsReportTabState extends ConsumerState<_FollowupsReportTab> {
  String _selectedFilter = 'This Week';
  DateTimeRange? _customRange;

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom';
        _customRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedFilter) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Yesterday':
        final yest = now.subtract(const Duration(days: 1));
        start = DateTime(yest.year, yest.month, yest.day);
        end = DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999);
        break;
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case 'Custom':
        start = _customRange?.start ?? DateTime(now.year, now.month, now.day);
        end = _customRange?.end ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        end = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    final followupsAsync = ref.watch(followupsProvider);
    final leadsAsync = ref.watch(leadsProvider);

    return followupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading follow-ups: $e')),
      data: (followups) {
        return leadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading leads: $e')),
          data: (leads) {
            final leadMap = {for (final l in leads) l.leadId: l};

            // Filter follow-ups
            final filtered = followups.where((f) {
              return f.followUpDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                     f.followUpDate.isBefore(end.add(const Duration(seconds: 1)));
            }).toList();

            // Sort chronologically
            filtered.sort((a, b) => a.followUpDate.compareTo(b.followUpDate));

            // Group by date for display
            final grouped = <String, List<FollowupModel>>{};
            for (final f in filtered) {
              final dStr = DateFormat('dd MMMM yyyy').format(f.followUpDate);
              grouped.putIfAbsent(dStr, () => []).add(f);
            }

            final totalCount = filtered.length;
            final completedCount = filtered.where((f) => f.status.toLowerCase() == 'completed').length;
            final upcomingCount = filtered.where((f) => f.status.toLowerCase() == 'upcoming').length;
            final missedCount = filtered.where((f) => f.status.toLowerCase() == 'missed').length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Today'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Yesterday'),
                        const SizedBox(width: 8),
                        _buildFilterChip('This Week'),
                        const SizedBox(width: 8),
                        _buildFilterChip('This Month'),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(_selectedFilter == 'Custom' && _customRange != null
                              ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                              : 'Custom Date'),
                          selected: _selectedFilter == 'Custom',
                          onSelected: (selected) {
                            if (selected) _pickCustomRange(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _StatCard('Total Logged', totalCount.toString(), Colors.indigo, Icons.history_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard('Completed', completedCount.toString(), Colors.green, Icons.check_circle_outline_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard('Upcoming', upcomingCount.toString(), Colors.orange, Icons.schedule_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard('Missed', missedCount.toString(), Colors.red, Icons.cancel_outlined)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // PDF Export header action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Follow-up Timeline',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final company = ref.read(companyProvider).value;
                          final bytes = await PdfService.generateFollowupReportPdf(
                            filtered,
                            leads,
                            companyName: company?.name,
                          );
                          await FileDownloadService.downloadPdf(pdfBytes: bytes, fileName: 'Followups_Report.pdf');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Followups_Report.pdf downloaded to your Downloads folder.'),
                              backgroundColor: Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).cardColor : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text('No follow-up entries for this date filter range.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final dateStr = grouped.keys.elementAt(index);
                        final items = grouped[dateStr]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Group Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(top: 8, bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1B4B) : Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFC7D2FE) : Colors.indigo.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            // Items
                            ...items.map((f) {
                              final lead = leadMap[f.leadId];
                              final leadName = lead?.requirement ?? 'Unknown Lead';
                              final customerName = lead?.customerName ?? 'Unknown Customer';
                              final timeStr = DateFormat('hh:mm a').format(f.followUpDate);
                              final createdDateStr = DateFormat('dd MMM yyyy').format(f.createdAt);

                              Color statusColor;
                              switch (f.status.toLowerCase()) {
                                case 'completed':
                                  statusColor = Colors.green;
                                  break;
                                case 'missed':
                                  statusColor = Colors.red;
                                  break;
                                default:
                                  statusColor = Colors.orange;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: isDark ? Theme.of(context).cardColor : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            leadName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                          ),
                                          Text(
                                            timeStr,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Client: $customerName', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              f.status,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Agent: ${f.assignedUser}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                          Text('Created: $createdDateStr', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : Colors.grey)),
                                        ],
                                      ),
                                      if (f.remarks.isNotEmpty) ...[
                                        Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        Text(
                                          'Notes: ${f.remarks}',
                                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == label,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
    );
  }
}
