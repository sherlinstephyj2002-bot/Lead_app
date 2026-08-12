import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../models/task_model.dart';
import '../models/lead_model.dart';
import '../models/attendance_model.dart';
import '../models/followup_model.dart';

class PdfService {
  static final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);
  static final formatDate = DateFormat('dd MMM yyyy');

  /// Generates a PDF byte array for an Order Invoice
  static Future<Uint8List> generateInvoicePdf({
    required OrderModel order,
    required List<ExpenseModel> expenses,
    required List<TaskModel> tasks,
  }) async {
    final pdf = pw.Document(
      title: 'Invoice_${order.orderId}',
      author: 'WorkTrack SaaS',
    );

    // Create pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'WorkTrack Project Service',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      order.orderId,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Text(
                      'Date: ${formatDate.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Due Date: ${formatDate.format(order.expectedCompletion)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Billing details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILLED TO:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.customerName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                    pw.Text(
                      'Project: ${order.projectName}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PROJECT ENGINEER:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      order.assignedEngineer,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                    pw.Text(
                      'Status: ${order.status}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 32),

            // Table of items
            pw.TableHelper.fromTextArray(
              border: null,
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellHeight: 30,
              cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
              headers: ['Description', 'Qty', 'Amount'],
              data: [
                [
                  'Project implementation services for: ${order.projectName}',
                  '1',
                  formatCurrency.format(order.amount),
                ],
              ],
            ),

            pw.SizedBox(height: 20),

            // Calculation Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Subtotal:  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(formatCurrency.format(order.amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text('Tax (0%):  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(formatCurrency.format(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(height: 1, width: 150, color: PdfColors.grey300),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Total Amount:  ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.indigo900),
                        ),
                        pw.Text(
                          formatCurrency.format(order.amount),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.indigo900),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'WorkTrack — Multi-tenant CRM & ERP Solutions',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a PDF byte array for the Order Summary / Project Overview
  static Future<Uint8List> generateOrderSummaryPdf({
    required OrderModel order,
    required List<ExpenseModel> expenses,
    required List<TaskModel> tasks,
  }) async {
    final pdf = pw.Document(
      title: 'Order_Summary_${order.orderId}',
      author: 'WorkTrack SaaS',
    );

    final totalExpenses = expenses.fold(0.0, (prev, e) => prev + e.amount);
    final remainingBudget = order.amount - totalExpenses;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PROJECT OVERVIEW',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Text(
                      'WorkTrack Management Portal',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      order.orderId,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                    ),
                    pw.Text(
                      'Export Date: ${formatDate.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Core Metrics Grid
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Order Value', formatCurrency.format(order.amount), PdfColors.indigo900),
                _buildSummaryBox('Total Expenses', formatCurrency.format(totalExpenses), PdfColors.red900),
                _buildSummaryBox('Net Margin', formatCurrency.format(remainingBudget), remainingBudget >= 0 ? PdfColors.green900 : PdfColors.red900),
              ],
            ),

            pw.SizedBox(height: 24),

            // Order Details Section
            pw.Text('1. Order Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                children: [
                  _buildDetailTextRow('Client Name', order.customerName),
                  _buildDetailTextRow('Project / Requirement', order.projectName),
                  _buildDetailTextRow('Lead Associated', order.leadId ?? 'None'),
                  _buildDetailTextRow('Assigned Engineer', order.assignedEngineer),
                  _buildDetailTextRow('Current Status', order.status),
                  _buildDetailTextRow('Expected Target Date', formatDate.format(order.expectedCompletion)),
                  if (order.completedOn != null)
                    _buildDetailTextRow('Completed On', formatDate.format(order.completedOn!)),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Tasks List Section
            pw.Text('2. Project Tasks (${tasks.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            if (tasks.isEmpty)
              pw.Text('No tasks added to this project.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                border: null,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellHeight: 24,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Task Title', 'Assigned To', 'Due Date', 'Status'],
                data: tasks.map((t) => [
                  t.title.replaceFirst('[${order.orderId}] ', ''),
                  t.assignedTo,
                  formatDate.format(t.dueDate),
                  t.status,
                ]).toList(),
              ),

            pw.SizedBox(height: 24),

            // Expenses List Section
            pw.Text('3. Logged Expenses (${expenses.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            if (expenses.isEmpty)
              pw.Text('No expenses recorded for this project.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                border: null,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellHeight: 24,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Description', 'Logged By', 'Category', 'Status', 'Amount'],
                data: expenses.map((e) => [
                  e.description.replaceFirst('[${order.orderId}] ', ''),
                  e.employeeName,
                  e.category,
                  e.status,
                  formatCurrency.format(e.amount),
                ]).toList(),
              ),

            pw.Spacer(),

            // Footer info
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'WorkTrack Project Report (Internal Copy Only)',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helpers for summary items
  static pw.Widget _buildSummaryBox(String label, String value, PdfColor textColor) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailTextRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  static Future<Uint8List> generateLeadsReportPdf(List<LeadModel> leads) async {
    final pdf = pw.Document(
      title: 'Leads_Report_${formatDate.format(DateTime.now())}',
      author: 'WorkTrack SaaS',
    );

    final statusCounts = <String, int>{};
    for (final l in leads) {
      statusCounts[l.status] = (statusCounts[l.status] ?? 0) + 1;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LEADS SUMMARY REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text('WorkTrack Workforce Management', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(formatDate.format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Total Leads', leads.length.toString(), PdfColors.indigo900),
                _buildSummaryBox('Converted Leads', (statusCounts['Converted'] ?? 0).toString(), PdfColors.green900),
                _buildSummaryBox('Follow Ups', (statusCounts['Follow Up'] ?? 0).toString(), PdfColors.orange900),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Lead Entries', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: null,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Customer Name', 'Requirement', 'Source', 'Assigned To', 'Status', 'Date'],
              data: leads.map((l) => [
                l.customerName,
                l.requirement,
                l.leadSource,
                l.assignedTo,
                l.status,
                formatDate.format(l.createdAt),
              ]).toList(),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateOrdersReportPdf(List<OrderModel> orders) async {
    final pdf = pw.Document(
      title: 'Orders_Report_${formatDate.format(DateTime.now())}',
      author: 'WorkTrack SaaS',
    );

    final totalRevenue = orders.where((o) => o.status != 'Cancelled').fold(0.0, (prev, o) => prev + o.amount);
    final activeOrders = orders.where((o) => o.status != 'Completed' && o.status != 'Closed' && o.status != 'Cancelled').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORDERS & REVENUE REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text('WorkTrack Workforce Management', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(formatDate.format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Total Orders', orders.length.toString(), PdfColors.indigo900),
                _buildSummaryBox('Active Orders', activeOrders.toString(), PdfColors.orange900),
                _buildSummaryBox('Project Revenue', formatCurrency.format(totalRevenue), PdfColors.green900),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Order Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: null,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Project Name', 'Client Name', 'Amount', 'Engineer', 'Target Date', 'Status'],
              data: orders.map((o) => [
                o.projectName,
                o.customerName,
                formatCurrency.format(o.amount),
                o.assignedEngineer,
                formatDate.format(o.expectedCompletion),
                o.status,
              ]).toList(),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateAttendanceReportPdf(
    List<AttendanceModel> logs, {
    String? companyName,
    Map<String, String>? filters,
  }) async {
    final pdf = pw.Document(
      title: 'Attendance_Report_${formatDate.format(DateTime.now())}',
      author: 'WorkTrack SaaS',
    );

    final presentCount = logs.where((l) => l.status == 'Present' || l.status == 'Late').length;
    final lateCount = logs.where((l) => l.status == 'Late').length;
    final totalHours = logs.fold(0.0, (prev, l) => prev + (l.workHours ?? 0.0));
    final avgHours = logs.isNotEmpty ? totalHours / logs.length : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Container();
          }
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'ATTENDANCE SYSTEM REPORT${companyName != null ? " - $companyName" : ""}',
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  companyName ?? 'WorkTrack Workforce Management',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ATTENDANCE REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    if (companyName != null)
                      pw.Text(companyName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))
                    else
                      pw.Text('WorkTrack Workforce Management', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            // Applied filters Display
            if (filters != null && filters.isNotEmpty) ...[
              pw.Text('Applied Filters:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Wrap(
                spacing: 12,
                runSpacing: 4,
                children: filters.entries.map((e) => pw.Text('${e.key}: ${e.value}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))).toList(),
              ),
              pw.SizedBox(height: 12),
            ],

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Total Records', logs.length.toString(), PdfColors.indigo900),
                _buildSummaryBox('On Time / Present', presentCount.toString(), PdfColors.green900),
                _buildSummaryBox('Late Check-ins', lateCount.toString(), PdfColors.orange900),
                _buildSummaryBox('Avg Work Hours', '${avgHours.toStringAsFixed(1)} hrs', PdfColors.purple900),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Attendance Details', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: null,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellHeight: 20,
              cellStyle: const pw.TextStyle(fontSize: 7),
              headers: ['Employee ID', 'Employee Name', 'Date', 'Check In', 'Check Out', 'Working Hours', 'Status'],
              data: logs.map((l) {
                // Calculate hours
                String hrs = '--';
                if (l.checkOutTime != null) {
                  final diff = l.checkOutTime!.difference(l.checkInTime);
                  final h = diff.inHours;
                  final m = diff.inMinutes % 60;
                  hrs = '${h}h ${m}m';
                } else {
                  hrs = 'Working...';
                }
                return [
                  l.employeeId,
                  l.employeeName,
                  DateFormat('dd/MM/yyyy').format(l.checkInTime),
                  DateFormat('hh:mm a').format(l.checkInTime),
                  l.checkOutTime != null ? DateFormat('hh:mm a').format(l.checkOutTime!) : 'Still Working',
                  hrs,
                  l.status,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateFollowupReportPdf(List<FollowupModel> followups, List<LeadModel> leads, {String? companyName}) async {
    final pdf = pw.Document(
      title: 'Followup_Report_${formatDate.format(DateTime.now())}',
      author: 'WorkTrack SaaS',
    );

    final sortedFollowups = List<FollowupModel>.from(followups);
    sortedFollowups.sort((a, b) => a.followUpDate.compareTo(b.followUpDate));

    final grouped = <String, List<FollowupModel>>{};
    for (final f in sortedFollowups) {
      final dateStr = DateFormat('dd MMMM yyyy').format(f.followUpDate);
      grouped.putIfAbsent(dateStr, () => []).add(f);
    }

    final leadMap = {for (final l in leads) l.leadId: l};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Container();
          }
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'FOLLOW-UP REPORT${companyName != null ? " - $companyName" : ""}',
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  companyName ?? 'WorkTrack Workforce Management',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final content = <pw.Widget>[];

          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FOLLOW-UP REPORT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    if (companyName != null)
                      pw.Text(companyName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))
                    else
                      pw.Text('WorkTrack Workforce Management', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(formatDate.format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          );
          content.add(pw.SizedBox(height: 16));
          content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
          content.add(pw.SizedBox(height: 16));

          if (sortedFollowups.isEmpty) {
            content.add(pw.Center(child: pw.Text('No follow-up records found matching the filters.')));
          } else {
            grouped.forEach((dateStr, list) {
              content.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.indigo50,
                  ),
                  child: pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.indigo900)),
                ),
              );
              content.add(pw.SizedBox(height: 8));

              for (final f in list) {
                final lead = leadMap[f.leadId];
                final leadName = lead?.requirement ?? 'Unknown Lead';
                final customerName = lead?.customerName ?? 'Unknown Customer';
                final timeStr = DateFormat('hh:mm a').format(f.followUpDate);
                final createdDateStr = DateFormat('dd MMM yyyy').format(f.createdAt);
                
                final status = f.status;
                final statusColor = status.toLowerCase() == 'completed'
                    ? PdfColors.green900
                    : (status.toLowerCase() == 'missed' ? PdfColors.red900 : PdfColors.orange900);

                content.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(leadName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
                          pw.Text(timeStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                          pw.Text('Status: $status', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: statusColor)),
                        ],
                      ),
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Assigned To: ${f.assignedUser}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Created: $createdDateStr', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Notes: ${f.remarks.isNotEmpty ? f.remarks : 'None'}', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey900)),
                      pw.SizedBox(height: 4),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                      pw.SizedBox(height: 8),
                    ],
                  ),
                );
              }
              content.add(pw.SizedBox(height: 12));
            });
          }

          return content;
        },
      ),
    );
    return pdf.save();
  }

  /// Triggers a share dialog for the PDF
  static Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  /// Triggers printing or a preview layout
  static Future<void> printPdf(Uint8List pdfBytes, String name) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: name,
    );
  }
}
