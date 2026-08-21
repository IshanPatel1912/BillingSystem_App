import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database_helper.dart';
import '../../providers/portfolio_provider.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _refresh() {
    Provider.of<PortfolioProvider>(context, listen: false).calculatePortfolio(startDate, endDate);
  }

  // --- PDF REPORT GENERATORS (Matching Desktop Layouts) ---

  Future<void> _generateReport(String type) async {
    // 1. Ask for Date Range on Click (Replicating DateRangeDialog)
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2AA2B8),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return; // User cancelled

    final db = await DatabaseHelper.instance.database;
    final pdf = pw.Document();
    final sStr = DateFormat('yyyy-MM-dd').format(picked.start);
    final eStr = DateFormat('yyyy-MM-dd').format(picked.end);
    final periodText = "${DateFormat('dd-MM-yyyy').format(picked.start)} to ${DateFormat('dd-MM-yyyy').format(picked.end)}";

    if (type == 'credit') {
      // CREDIT REPORT
      final data = await db.rawQuery("SELECT bill_id, customer_name, date_time, net_total FROM sales WHERE paid_status = 1 AND (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ? ORDER BY date_time ASC", [sStr, eStr]);
      
      double grandTotal = 0.0;
      List<List<String>> tableData = [];
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        DateTime dt = DateTime.parse(row['date_time'].toString());
        String cust = row['customer_name'].toString().isEmpty ? "Cash" : row['customer_name'].toString();
        double amt = (row['net_total'] as num).toDouble();
        grandTotal += amt;
        
        tableData.add([
          (i + 1).toString(),
          DateFormat('dd-MM-yyyy').format(dt),
          DateFormat('HH:mm').format(dt),
          "${row['bill_id']} ($cust)",
          amt.toStringAsFixed(2)
        ]);
      }
      tableData.add(['', '', '', 'GRAND TOTAL', grandTotal.toStringAsFixed(2)]);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text("Credit Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2E8B57))),
          pw.Text("Period: $periodText"),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headers: ['Sr No.', 'Date', 'Time', 'Bill ID & Customer', 'Amount (Rs)'],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E8B57)),
            cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerLeft, 4: pw.Alignment.centerRight},
            data: tableData,
          ),
        ],
      ));
    } 
    else if (type == 'purchase') {
      // PURCHASE REPORT
      final data = await db.rawQuery('''
        SELECT p.date_time, p.total_amount, p.category, pi.item_name, pi.quantity, pi.rate, pi.amount, pi.track_item 
        FROM purchases p 
        LEFT JOIN purchase_items pi ON p.id = pi.purchase_id 
        WHERE (p.is_deleted = 0 OR p.is_deleted IS NULL) AND date(p.date_time) BETWEEN ? AND ? 
        ORDER BY p.date_time ASC
      ''', [sStr, eStr]);

      double grandTotal = 0.0;
      List<List<String>> tableData = [];
      int srNo = 1;
      
      for (var row in data) {
        DateTime dt = DateTime.parse(row['date_time'].toString());
        double amt = (row['amount'] != null ? row['amount'] as num : row['total_amount'] as num).toDouble();
        grandTotal += amt;
        String target = row['track_item'] == 1 ? "Inventory" : "General";
        
        tableData.add([
          srNo.toString(),
          DateFormat('dd-MM-yy').format(dt),
          DateFormat('HH:mm').format(dt),
          row['item_name']?.toString() ?? "Purchase Entry (No Items)",
          row['quantity']?.toString() ?? "-",
          row['rate']?.toString() ?? "-",
          amt.toStringAsFixed(2),
          target
        ]);
        srNo++;
      }
      tableData.add(['', '', '', 'GRAND TOTAL', '', '', grandTotal.toStringAsFixed(2), '']);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text("Detailed Purchase Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF005A9E))),
          pw.Text("Period: $periodText"),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headers: ['Sr\nNo.', 'Date', 'Time', 'Item Name', 'Qty', 'Rate\n(Rs)', 'Amount\n(Rs)', 'Saved Into'],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF005A9E)),
            cellAlignments: {0: pw.Alignment.center, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight, 6: pw.Alignment.centerRight},
            data: tableData,
          ),
        ],
      ));
    } 
    else if (type == 'expense') {
      // EXPENDITURE REPORT
      final data = await db.rawQuery("SELECT date_time, description, amount FROM expenditures WHERE (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ? ORDER BY date_time ASC", [sStr, eStr]);
      
      double grandTotal = 0.0;
      List<List<String>> tableData = [];
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        DateTime dt = DateTime.parse(row['date_time'].toString());
        double amt = (row['amount'] as num).toDouble();
        grandTotal += amt;
        
        tableData.add([
          (i + 1).toString(),
          DateFormat('dd-MM-yyyy').format(dt),
          DateFormat('HH:mm').format(dt),
          row['description'].toString(),
          amt.toStringAsFixed(2)
        ]);
      }
      tableData.add(['', '', '', 'GRAND TOTAL', grandTotal.toStringAsFixed(2)]);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text("Expenditure Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF5C2D91))),
          pw.Text("Period: $periodText"),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headers: ['Sr No.', 'Date', 'Time', 'Expenditure Detail', 'Amount (Rs)'],
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF5C2D91)),
            cellAlignments: {0: pw.Alignment.center, 4: pw.Alignment.centerRight},
            data: tableData,
          ),
        ],
      ));
    } 
    else if (type == 'detailed') {
      // DETAILED TRANSACTION REPORT
      final salesData = await db.rawQuery("SELECT date_time, customer_name, net_total as amt FROM sales WHERE paid_status = 1 AND (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ? ORDER BY date_time ASC", [sStr, eStr]);
      
      final purchData = await db.rawQuery('''
        SELECT p.date_time, 
               COALESCE(GROUP_CONCAT(pi.item_name || ' x ' || pi.quantity, ', '), 'Purchase Entry (No Items)') as desc, 
               p.total_amount as amt 
        FROM purchases p 
        LEFT JOIN purchase_items pi ON p.id = pi.purchase_id 
        WHERE (p.is_deleted = 0 OR p.is_deleted IS NULL) AND date(p.date_time) BETWEEN ? AND ? 
        GROUP BY p.id, p.date_time, p.total_amount
        ORDER BY p.date_time ASC
      ''', [sStr, eStr]);
      
      final expData = await db.rawQuery("SELECT date_time, description as desc, amount as amt FROM expenditures WHERE (is_deleted = 0 OR is_deleted IS NULL) AND date(date_time) BETWEEN ? AND ? ORDER BY date_time ASC", [sStr, eStr]);

      List<Map<String, dynamic>> allTransactions = [];
      
      for (var s in salesData) { allTransactions.add({'type': 'Credit', 'dt': DateTime.parse(s['date_time'].toString()), 'desc': "Bill: ${s['customer_name'].toString().isEmpty ? "Cash Sale" : s['customer_name']}", 'amt': (s['amt'] as num).toDouble()}); }
      for (var p in purchData) { allTransactions.add({'type': 'Purchase', 'dt': DateTime.parse(p['date_time'].toString()), 'desc': p['desc'].toString().replaceAll('.0', ''), 'amt': (p['amt'] as num).toDouble()}); }
      for (var e in expData) { allTransactions.add({'type': 'Expense', 'dt': DateTime.parse(e['date_time'].toString()), 'desc': e['desc'], 'amt': (e['amt'] as num).toDouble()}); }
      
      allTransactions.sort((a, b) => (a['dt'] as DateTime).compareTo(b['dt'] as DateTime));

      // 1. Group by Date
      Map<String, List<Map<String, dynamic>>> groupedByDate = {};
      for (var t in allTransactions) {
        String dateKey = DateFormat('dd-MM-yyyy').format(t['dt'] as DateTime);
        if (!groupedByDate.containsKey(dateKey)) {
          groupedByDate[dateKey] = [];
        }
        groupedByDate[dateKey]!.add(t);
      }

      List<pw.Widget> elements = [];
      elements.add(pw.Text("Detailed Transaction Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0078D4))));
      elements.add(pw.Text("Period: $periodText"));
      elements.add(pw.SizedBox(height: 20));

      double grandCredit = 0;
      double grandPurch = 0;
      double grandExp = 0;

      // 2. Iterate and Build Daily Tables
      for (String dateKey in groupedByDate.keys) {
        elements.add(pw.Text("Date: $dateKey", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
        elements.add(pw.SizedBox(height: 5));

        List<List<String>> dayTableData = [];
        double dayCredit = 0.0;
        double dayDebit = 0.0;

        for (var t in groupedByDate[dateKey]!) {
          double amt = t['amt'] as double;
          if (t['type'] == 'Credit') { dayCredit += amt; grandCredit += amt; }
          else if (t['type'] == 'Purchase') { dayDebit += amt; grandPurch += amt; }
          else if (t['type'] == 'Expense') { dayDebit += amt; grandExp += amt; }

          dayTableData.add([
            t['type'].toString(),
            DateFormat('HH:mm').format(t['dt'] as DateTime),
            t['desc'].toString(),
            amt.toStringAsFixed(2)
          ]);
        }

        elements.add(pw.TableHelper.fromTextArray(
          headers: ['Type', 'Time', 'Details', 'Amount (Rs)'],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0078D4)),
          cellAlignments: {3: pw.Alignment.centerRight},
          data: dayTableData,
        ));

        // 3. Daily Summary Line
        double dayNet = dayCredit - dayDebit;
        elements.add(pw.SizedBox(height: 5));
        elements.add(pw.Text(
          "Credit: ${dayCredit.toStringAsFixed(2)} | Debit: ${dayDebit.toStringAsFixed(2)} | Net Profit: ${dayNet.toStringAsFixed(2)}",
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: dayNet >= 0 ? PdfColors.green800 : PdfColors.red800)
        ));
        elements.add(pw.SizedBox(height: 15));
      }

      // 4. Grand Totals Table
      double grandDebit = grandPurch + grandExp;
      double grandNet = grandCredit - grandDebit;

      elements.add(pw.SizedBox(height: 10));
      elements.add(pw.Text("Grand Totals for Selected Period", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)));
      elements.add(pw.SizedBox(height: 5));
      elements.add(pw.TableHelper.fromTextArray(
        headers: ['Metric', 'Amount (Rs)'],
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
        cellAlignments: {1: pw.Alignment.centerRight},
        data: [
          ['Total Purchases', grandPurch.toStringAsFixed(2)],
          ['Total Expenses', grandExp.toStringAsFixed(2)],
          ['Total Debit', grandDebit.toStringAsFixed(2)],
          ['Total Credit', grandCredit.toStringAsFixed(2)],
          ['Net Profit', grandNet.toStringAsFixed(2)],
        ]
      ));

      // Inject all built elements into a MultiPage
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => elements,
      ));
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PortfolioProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Portfolio Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ON-SCREEN DASHBOARD STATS (Controlled by Quick Filters) ---
            const Text("Quick Summary", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, 
              children: [
                ElevatedButton(onPressed: () { setState(() { startDate = DateTime.now(); endDate = DateTime.now(); }); _refresh(); }, child: const Text("Today")),
                ElevatedButton(onPressed: () { setState(() { startDate = DateTime(DateTime.now().year, DateTime.now().month, 1); endDate = DateTime.now(); }); _refresh(); }, child: const Text("Month")),
                ElevatedButton(onPressed: () { setState(() { startDate = DateTime(DateTime.now().year, 1, 1); endDate = DateTime.now(); }); _refresh(); }, child: const Text("Year")),
                ElevatedButton(onPressed: () { setState(() { startDate = DateTime(2000); endDate = DateTime.now(); }); _refresh(); }, child: const Text("All Time")),
              ]
            ),
            const SizedBox(height: 20),
            
            _buildStatCard("Total Paid Sales", state.totalSales, Colors.greenAccent),
            _buildStatCard("Total Purchases", state.totalPurchases, Colors.orangeAccent),
            _buildStatCard("Total Expenses", state.totalExpenses, Colors.purpleAccent),
            _buildStatCard("Net Profit", state.netProfit, state.netProfit >= 0 ? Colors.green : Colors.red, isBold: true),
            
            const SizedBox(height: 30),
            
            // --- REPORT BUTTONS (Trigger Date Pickers) ---
            const Text("Export Reports (Select Date Range)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.grey),
            
            _buildReportButton("Detailed Date-by-Date Report", const Color(0xFFD83B01), Icons.analytics, () => _generateReport('detailed')),
            _buildReportButton("Credit Report (PDF)", const Color(0xFF2E8B57), Icons.account_balance_wallet, () => _generateReport('credit')),
            _buildReportButton("Purchase Report (PDF)", const Color(0xFF005A9E), Icons.shopping_bag, () => _generateReport('purchase')),
            _buildReportButton("Expenditure Report (PDF)", const Color(0xFF5C2D91), Icons.receipt, () => _generateReport('expense')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, double val, Color col, {bool isBold = false}) => Card(
    child: ListTile(
      title: Text(label), 
      trailing: Text("₹${val.toStringAsFixed(2)}", style: TextStyle(color: col, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 18))
    )
  );

  Widget _buildReportButton(String label, Color col, IconData icon, VoidCallback tap) => Container(
    width: double.infinity, margin: const EdgeInsets.only(top: 10),
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: col, padding: const EdgeInsets.all(15)), 
      onPressed: tap, 
      icon: Icon(icon, color: Colors.white), 
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
    )
  );
}