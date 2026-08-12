import 'package:flutter/material.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/salary_payslip_model.dart';

/// Generates and handles PDF operations for a salary payslip.
class SalaryPayslipPdf {
  static final _currFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  // ── Public API ──────────────────────────────────────

  /// Builds and returns the pdf.Document for a payslip.
  static Future<pw.Document> generate(
      SalaryPayslipModel p, String companyName) async {
    final doc = pw.Document(
      title: 'Payslip – ${p.employeeName} – ${p.payrollPeriod}',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(p, companyName),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _employeeTable(p),
          pw.SizedBox(height: 16),
          _attendanceRow(p),
          pw.SizedBox(height: 16),
          _earningsDeductionsTable(p),
          pw.SizedBox(height: 16),
          _netSalaryBox(p),
          pw.SizedBox(height: 32),
          _signatureSection(),
          pw.SizedBox(height: 16),
          _footer(p),
        ],
      ),
    );
    return doc;
  }

  /// Opens the system print dialog.
  static Future<void> print(
      SalaryPayslipModel p, String companyName) async {
    try {
      final doc = await generate(p, companyName);
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Payslip_${p.employeeName}_${p.payrollPeriod}',
      );
    } catch (e) {
      debugPrint('PDF print error: $e');
      rethrow;
    }
  }

  /// Downloads the PDF (web) or shares it (mobile).
  static Future<void> download(
      SalaryPayslipModel p, String companyName) async {
    try {
      final doc = await generate(p, companyName);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Payslip_${p.employeeName}_${p.payrollPeriod}.pdf',
      );
    } catch (e) {
      debugPrint('PDF download error: $e');
      rethrow;
    }
  }

  // ── Private builders ────────────────────────────────

  static pw.Widget _buildHeader(SalaryPayslipModel p, String companyName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1E293B),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Salary Payslip',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: const PdfColor.fromInt(0xFF64748B),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                p.payrollPeriod,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF4F46E5),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy').format(p.generatedDate)}',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: const PdfColor.fromInt(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _employeeTable(SalaryPayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
      ),
      child: pw.Row(
        children: [
          _empCell('Employee Name', p.employeeName),
          _empCell('Employee Code', p.employeeCode ?? '—'),
          _empCell('Department', p.department ?? '—'),
          _empCell('Designation', p.designation ?? '—'),
        ],
      ),
    );
  }

  static pw.Widget _empCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: const PdfColor.fromInt(0xFF64748B))),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _attendanceRow(SalaryPayslipModel p) {
    return pw.Row(
      children: [
        _attendanceCell('Present Days', '${p.presentDays}'),
        _attendanceCell('Absent Days', '${p.absentDays}'),
        _attendanceCell('Leave Days', '${p.leaveDays}'),
        _attendanceCell('Salary Structure', p.salaryStructureName ?? '—'),
      ],
    );
  }

  static pw.Widget _attendanceCell(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8,
                    color: const PdfColor.fromInt(0xFF64748B))),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _earningsDeductionsTable(SalaryPayslipModel p) {
    final earningRows = <List<String>>[
      ['Basic Salary', _currFmt.format(p.basicSalary)],
      ...p.earnings.entries.map((e) => [e.key, _currFmt.format(e.value)]),
      if (p.bonus > 0) ['Bonus', _currFmt.format(p.bonus)],
      if (p.overtime > 0) ['Overtime', _currFmt.format(p.overtime)],
      if (p.incentive > 0) ['Incentive', _currFmt.format(p.incentive)],
    ];

    final deductionRows = <List<String>>[
      ...p.deductions.entries.map((e) => [e.key, _currFmt.format(e.value)]),
      if (p.otherDeduction > 0)
        ['Other Deductions', _currFmt.format(p.otherDeduction)],
    ];

    final maxRows =
        earningRows.length > deductionRows.length
            ? earningRows.length
            : deductionRows.length;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Earnings
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _tableHeader('Earnings', const PdfColor.fromInt(0xFF4F46E5)),
              ...List.generate(maxRows, (i) {
                if (i >= earningRows.length) return _tableRow('', '', i);
                return _tableRow(
                    earningRows[i][0], earningRows[i][1], i);
              }),
              _tableTotalRow(
                  'Total Earnings', _currFmt.format(p.totalEarnings)),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Deductions
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _tableHeader('Deductions', const PdfColor.fromInt(0xFFEF4444)),
              ...List.generate(maxRows, (i) {
                if (i >= deductionRows.length) return _tableRow('', '', i);
                return _tableRow(
                    deductionRows[i][0], deductionRows[i][1], i);
              }),
              _tableTotalRow(
                  'Total Deductions', _currFmt.format(p.totalDeductions)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _tableHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: color,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableRow(String label, String value, int index) {
    final bg = index.isEven
        ? const PdfColor.fromInt(0xFFFFFFFF)
        : const PdfColor.fromInt(0xFFF8FAFC);
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _tableTotalRow(String label, String value) {
    return pw.Container(
      color: const PdfColor.fromInt(0xFFF1F5F9),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _netSalaryBox(SalaryPayslipModel p) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [
            PdfColor.fromInt(0xFF4F46E5),
            PdfColor.fromInt(0xFF7C3AED),
          ],
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Net Salary',
                  style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xB3FFFFFF),
                      fontSize: 11)),
              pw.Text(
                _currFmt.format(p.netSalary),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Gross Salary',
                  style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xB3FFFFFF), fontSize: 9)),
              pw.Text(_currFmt.format(p.grossSalary),
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text('Total Deductions',
                  style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xB3FFFFFF), fontSize: 9)),
              pw.Text(_currFmt.format(p.totalDeductions),
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _sigBlock('Employee Signature'),
        _sigBlock('HR Manager'),
        _sigBlock('Authorized Signatory'),
      ],
    );
  }

  static pw.Widget _sigBlock(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          height: 40,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF94A3B8))),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _footer(SalaryPayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0))),
      ),
      child: pw.Text(
        'This is a computer generated payslip. Generated by ${p.generatedBy} on '
        '${DateFormat('dd MMM yyyy, hh:mm a').format(p.generatedDate)}.',
        style: pw.TextStyle(
            fontSize: 8,
            color: const PdfColor.fromInt(0xFF94A3B8)),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}

